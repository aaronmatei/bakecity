import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../services/upload_service.dart';
import '../../../services/websocket_service.dart';
import '../../../widgets/app_error_view.dart';
import '../../../widgets/loading_indicator.dart';
import '../../../widgets/media_thumbnail.dart';
import '../../../widgets/primary_button.dart';
import '../../auth/application/auth_controller.dart';
import '../../media/application/media_controller.dart';
import '../../media/domain/order_media.dart';
import '../../orders/application/orders_controller.dart';
import '../application/production_controller.dart';
import 'production_timeline.dart';

/// Production view: the customer watches an animated stage timeline come to life
/// as their cake is made; the baker steps through the fixed stages — tapping the
/// current one to post photos/videos and notes, then marking it done to advance.
class ProductionView extends ConsumerStatefulWidget {
  const ProductionView({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<ProductionView> createState() => _ProductionViewState();
}

class _ProductionViewState extends ConsumerState<ProductionView> {
  StreamSubscription<RealtimeEvent>? _wsSub;

  @override
  void initState() {
    super.initState();
    // Live updates: when a production_update for this order arrives over the
    // websocket, refresh the timeline with a light haptic so the new stage/
    // media reveals smoothly.
    _wsSub = ref.read(webSocketServiceProvider).events.listen((e) {
      if (e.type != 'production_update') return;
      final oid = (e.payload['order_id'] ??
              (e.payload['data'] is Map
                  ? (e.payload['data'] as Map)['order_id']
                  : null))
          ?.toString();
      if (oid != null && oid != widget.orderId) return;
      if (!mounted) return;
      HapticFeedback.lightImpact();
      ref.invalidate(orderProductionProvider(widget.orderId));
      ref.invalidate(orderMediaProvider(widget.orderId));
      ref.invalidate(orderDetailProvider(widget.orderId));
    });
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    super.dispose();
  }

  Future<void> _openStageSheet(BakeStage stage) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _StageComposerSheet(orderId: widget.orderId, stage: stage),
    );
  }

  @override
  Widget build(BuildContext context) {
    final updates = ref.watch(orderProductionProvider(widget.orderId));
    final isBaker =
        ref.watch(authControllerProvider).user?.role == UserRole.baker;
    final status =
        ref.watch(orderDetailProvider(widget.orderId)).valueOrNull?.status;
    final media = ref.watch(orderMediaProvider(widget.orderId)).valueOrNull ??
        const <OrderMedia>[];
    final canPost = isBaker &&
        (status == OrderStatus.depositPaid ||
            status == OrderStatus.inProduction);

    final references =
        media.where((m) => m.kind == MediaKind.reference).toList();
    final productionMedia =
        media.where((m) => m.kind == MediaKind.production).toList();

    return updates.when(
      loading: () => const LoadingIndicator(),
      error: (e, _) => AppErrorView(
        message: e.toString(),
        onRetry: () =>
            ref.invalidate(orderProductionProvider(widget.orderId)),
      ),
      data: (items) {
        final showTimeline = items.isNotEmpty || _productionStarted(status);
        return RefreshIndicator(
          color: context.cs.primary,
          onRefresh: () async {
            ref.invalidate(orderProductionProvider(widget.orderId));
            ref.invalidate(orderMediaProvider(widget.orderId));
            ref.invalidate(orderDetailProvider(widget.orderId));
          },
          child: ListView(
            padding: const EdgeInsets.all(Insets.screenH),
            children: [
              if (references.isNotEmpty) ...[
                _ReferenceStrip(references: references),
                const SizedBox(height: Insets.xl),
              ],
              if (showTimeline)
                ProductionTimeline(
                  updates: items,
                  status: status,
                  productionMedia: productionMedia,
                  editable: canPost,
                  onUpdateStage: _openStageSheet,
                )
              else
                _PreProduction(status: status),
            ],
          ),
        );
      },
    );
  }

  static bool _productionStarted(OrderStatus? s) =>
      s == OrderStatus.depositPaid ||
      s == OrderStatus.inProduction ||
      s == OrderStatus.ready ||
      s == OrderStatus.dispatched ||
      s == OrderStatus.delivered ||
      s == OrderStatus.completed;
}

/// The per-stage composer: attach photos/videos (scoped to the stage), add
/// notes, then mark the stage done — which advances the order to the next stage.
class _StageComposerSheet extends ConsumerStatefulWidget {
  const _StageComposerSheet({required this.orderId, required this.stage});

  final String orderId;
  final BakeStage stage;

  @override
  ConsumerState<_StageComposerSheet> createState() =>
      _StageComposerSheetState();
}

class _StageComposerSheetState extends ConsumerState<_StageComposerSheet> {
  final _notesController = TextEditingController();
  bool _uploading = false;
  bool _submitting = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _add({required bool video}) async {
    setState(() => _uploading = true);
    final messenger = ScaffoldMessenger.of(context);
    final upload = ref.read(uploadServiceProvider);
    try {
      final mediaId = video
          ? await upload.pickAndUploadVideo(
              kind: MediaKind.production,
              orderId: widget.orderId,
              stage: widget.stage.label,
            )
          : await upload.pickAndUpload(
              kind: MediaKind.production,
              orderId: widget.orderId,
              stage: widget.stage.label,
            );
      if (mediaId != null) {
        ref.invalidate(orderMediaProvider(widget.orderId));
        messenger.showSnackBar(
            SnackBar(content: Text(video ? 'Video added.' : 'Photo added.')));
      }
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _markDone() async {
    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref.read(productionControllerProvider).addUpdate(
            orderId: widget.orderId,
            stage: widget.stage.label,
            progressPct: stageDonePct(widget.stage),
            notes: _notesController.text.trim(),
          );
      ref.invalidate(orderMediaProvider(widget.orderId));
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('${widget.stage.label} marked done.')),
      );
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final media = ref.watch(orderMediaProvider(widget.orderId)).valueOrNull ??
        const <OrderMedia>[];
    final stageMedia = media
        .where((m) =>
            m.kind == MediaKind.production &&
            m.stage != null &&
            m.stage!.trim().isNotEmpty &&
            classifyStage(m.stage!, 0) == widget.stage)
        .toList();
    final busy = _uploading || _submitting;
    final isLast = widget.stage == kWorkStages.last;

    return Padding(
      padding: EdgeInsets.only(
        left: Insets.lg,
        right: Insets.lg,
        top: Insets.sm,
        bottom: MediaQuery.of(context).viewInsets.bottom + Insets.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(widget.stage.icon, color: cs.primary),
              const SizedBox(width: Insets.sm),
              Text(widget.stage.label, style: context.tt.titleLarge),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Add photos or a video, jot any notes, then mark this stage done.',
            style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          if (stageMedia.isNotEmpty) ...[
            const SizedBox(height: Insets.lg),
            SizedBox(
              height: 88,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: stageMedia.length,
                separatorBuilder: (_, __) => const SizedBox(width: Insets.sm),
                itemBuilder: (context, i) =>
                    StageMediaTile(media: stageMedia[i], size: 88),
              ),
            ),
          ],
          const SizedBox(height: Insets.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : () => _add(video: false),
                  icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                  label: const Text('Photo'),
                ),
              ),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : () => _add(video: true),
                  icon: const Icon(Icons.videocam_outlined, size: 18),
                  label: const Text('Video'),
                ),
              ),
            ],
          ),
          if (_uploading)
            const Padding(
              padding: EdgeInsets.only(top: Insets.sm),
              child: LinearProgressIndicator(),
            ),
          const SizedBox(height: Insets.md),
          TextField(
            controller: _notesController,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              hintText: 'e.g. Two layers in the oven now',
            ),
          ),
          const SizedBox(height: Insets.lg),
          PrimaryButton(
            label: isLast ? 'Mark done · ready for delivery' : 'Mark stage done',
            icon: Icons.check_circle_outline,
            isLoading: _submitting,
            onPressed: busy ? null : _markDone,
          ),
          if (isLast)
            Padding(
              padding: const EdgeInsets.only(top: Insets.sm),
              child: Text(
                'Completing this stage marks the order ready for delivery.',
                textAlign: TextAlign.center,
                style: context.tt.bodySmall?.copyWith(color: cs.primary),
              ),
            ),
        ],
      ),
    );
  }
}

/// A horizontal strip of the customer's reference photos.
class _ReferenceStrip extends StatelessWidget {
  const _ReferenceStrip({required this.references});

  final List<OrderMedia> references;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Reference photos', style: context.tt.titleSmall),
        const SizedBox(height: Insets.sm),
        SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: references.length,
            separatorBuilder: (_, __) => const SizedBox(width: Insets.sm),
            itemBuilder: (context, i) =>
                MediaThumbnail(url: references[i].displayUrl, size: 72),
          ),
        ),
      ],
    );
  }
}

/// Shown before production can begin (deposit not yet paid).
class _PreProduction extends StatelessWidget {
  const _PreProduction({required this.status});
  final OrderStatus? status;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Container(
      margin: const EdgeInsets.only(top: Insets.xxl),
      padding: const EdgeInsets.all(Insets.xl),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: Radii.cardBorder,
      ),
      child: Column(
        children: [
          Icon(Icons.bakery_dining_outlined,
              size: 40, color: cs.onSurfaceVariant),
          const SizedBox(height: Insets.md),
          Text('Production hasn\'t started yet',
              style: context.tt.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: Insets.sm),
          Text(
            'Once your deposit is paid, you\'ll watch every stage of your cake '
            'come to life here — live.',
            textAlign: TextAlign.center,
            style: context.tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
