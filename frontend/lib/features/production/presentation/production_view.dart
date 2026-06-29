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
/// as their cake is made; the baker (only) also gets the update composer.
class ProductionView extends ConsumerStatefulWidget {
  const ProductionView({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<ProductionView> createState() => _ProductionViewState();
}

class _ProductionViewState extends ConsumerState<ProductionView> {
  final _stageController = TextEditingController();
  final _notesController = TextEditingController();
  double _progress = 0;
  bool _submitting = false;
  bool _uploading = false;
  String? _mediaId;
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
    _stageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final stage = _stageController.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    if (stage.isEmpty) {
      messenger
          .showSnackBar(const SnackBar(content: Text('Enter a stage name.')));
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(productionControllerProvider).addUpdate(
            orderId: widget.orderId,
            stage: stage,
            progressPct: _progress.round(),
            notes: _notesController.text.trim(),
            mediaId: _mediaId,
          );
      _stageController.clear();
      _notesController.clear();
      setState(() {
        _progress = 0;
        _mediaId = null;
      });
      ref.invalidate(orderMediaProvider(widget.orderId));
      messenger.showSnackBar(const SnackBar(content: Text('Update posted.')));
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _attachPhoto() async {
    setState(() => _uploading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final mediaId = await ref.read(uploadServiceProvider).pickAndUpload(
            kind: MediaKind.production,
            orderId: widget.orderId,
          );
      if (mediaId != null) {
        setState(() => _mediaId = mediaId);
        ref.invalidate(orderMediaProvider(widget.orderId));
        messenger
            .showSnackBar(const SnackBar(content: Text('Photo attached.')));
      }
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
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
        return Column(
          children: [
            Expanded(
              child: RefreshIndicator(
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
                      )
                    else
                      _PreProduction(status: status),
                  ],
                ),
              ),
            ),
            if (canPost) _composer(),
          ],
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

  Widget _composer() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(Insets.lg),
        decoration: BoxDecoration(
          color: context.cs.surface,
          border: Border(top: BorderSide(color: context.cs.outlineVariant)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _stageController,
              decoration: const InputDecoration(
                labelText: 'Stage (e.g. Baking, Decorating)',
              ),
            ),
            const SizedBox(height: Insets.sm),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
            Row(
              children: [
                Text('Progress: ${_progress.round()}%'),
                Expanded(
                  child: Slider(
                    value: _progress,
                    max: 100,
                    divisions: 20,
                    label: '${_progress.round()}%',
                    onChanged: _submitting
                        ? null
                        : (v) => setState(() => _progress = v),
                  ),
                ),
              ],
            ),
            if (_progress.round() == 100)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'Posting at 100% marks the order ready for delivery.',
                  style: context.tt.bodySmall?.copyWith(color: context.cs.primary),
                ),
              ),
            OutlinedButton.icon(
              onPressed: _uploading || _submitting ? null : _attachPhoto,
              icon: _uploading
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(_mediaId == null
                      ? Icons.add_a_photo_outlined
                      : Icons.check_circle_outline),
              label: Text(_mediaId == null ? 'Attach photo' : 'Photo attached'),
            ),
            const SizedBox(height: Insets.sm),
            PrimaryButton(
              label: 'Post update',
              icon: Icons.add_outlined,
              isLoading: _submitting,
              onPressed: _submitting ? null : _submit,
            ),
          ],
        ),
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
