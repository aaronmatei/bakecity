import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/helpers/formatters.dart';
import '../../auth/application/auth_controller.dart';
import '../../media/application/media_controller.dart';
import '../../media/domain/order_media.dart';
import '../../orders/application/orders_controller.dart';
import '../../../services/upload_service.dart';
import '../../../widgets/app_error_view.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading_indicator.dart';
import '../../../widgets/media_thumbnail.dart';
import '../../../widgets/primary_button.dart';
import '../application/production_controller.dart';

/// Production timeline for an order. The baker posts stage updates; everyone
/// sees the chronological timeline.
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

  @override
  void dispose() {
    _stageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final stage = _stageController.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    if (stage.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Enter a stage name.')));
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
        messenger.showSnackBar(const SnackBar(content: Text('Photo attached.')));
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
    final orderStatus =
        ref.watch(orderDetailProvider(widget.orderId)).valueOrNull?.status;
    final media = ref.watch(orderMediaProvider(widget.orderId)).valueOrNull ??
        const <OrderMedia>[];
    // The backend accepts production updates only while DEPOSIT_PAID (starts
    // production) or IN_PRODUCTION.
    final canPost = isBaker &&
        (orderStatus == OrderStatus.depositPaid ||
            orderStatus == OrderStatus.inProduction);

    final references =
        media.where((m) => m.kind == MediaKind.reference).toList();
    // Map each production photo by its media id so updates can show their image.
    final productionPhotos = {
      for (final m in media)
        if (m.kind == MediaKind.production) m.id: m,
    };

    return Column(
      children: [
        if (isBaker && orderStatus != null)
          _ProductionBanner(status: orderStatus),
        if (references.isNotEmpty) _ReferenceStrip(references: references),
        Expanded(
          child: updates.when(
            loading: () => const LoadingIndicator(),
            error: (e, _) => AppErrorView(
              message: e.toString(),
              onRetry: () =>
                  ref.invalidate(orderProductionProvider(widget.orderId)),
            ),
            data: (items) {
              if (items.isEmpty) {
                return const EmptyState(
                  icon: Icons.timeline_outlined,
                  message: 'Production has not started yet.',
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final u = items[i];
                  final hasNotes = u.notes != null && u.notes!.isNotEmpty;
                  final photo = u.mediaId == null
                      ? null
                      : productionPhotos[u.mediaId];
                  return ListTile(
                    leading: CircleAvatar(child: Text('${u.progressPct}%')),
                    title: Text(u.stage),
                    subtitle: Text(
                      [
                        if (hasNotes) u.notes!,
                        Formatters.relativeTime(u.createdAt),
                      ].join('\n'),
                    ),
                    isThreeLine: hasNotes,
                    trailing: photo != null
                        ? MediaThumbnail(url: photo.displayUrl, size: 56)
                        : null,
                  );
                },
              );
            },
          ),
        ),
        if (canPost) _composer(),
      ],
    );
  }

  Widget _composer() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _stageController,
              decoration: const InputDecoration(
                labelText: 'Stage (e.g. Baking, Decorating)',
              ),
            ),
            const SizedBox(height: 8),
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
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
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
            const SizedBox(height: 8),
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

/// A horizontal strip of the customer's reference photos, shown above the
/// timeline so the baker can see what to make.
class _ReferenceStrip extends StatelessWidget {
  const _ReferenceStrip({required this.references});

  final List<OrderMedia> references;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Reference photos', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: references.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) =>
                  MediaThumbnail(url: references[i].displayUrl, size: 72),
            ),
          ),
        ],
      ),
    );
  }
}

/// A contextual banner telling the baker where the order stands and what to do
/// next in the production flow.
class _ProductionBanner extends StatelessWidget {
  const _ProductionBanner({required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (IconData icon, String message) = switch (status) {
      OrderStatus.draft ||
      OrderStatus.pendingQuote ||
      OrderStatus.quoted ||
      OrderStatus.accepted =>
        (Icons.payments_outlined,
            'Production starts once the customer pays the deposit.'),
      OrderStatus.depositPaid => (
          Icons.play_circle_outline,
          'Deposit received — post your first update to start production.'
        ),
      OrderStatus.inProduction => (
          Icons.timelapse_outlined,
          'In production. Post updates, and set 100% when it’s ready.'
        ),
      OrderStatus.ready => (
          Icons.check_circle_outline,
          'Production complete. Dispatch from the Delivery tab.'
        ),
      OrderStatus.dispatched =>
        (Icons.local_shipping_outlined, 'Out for delivery.'),
      OrderStatus.delivered => (Icons.done_all, 'Delivered.'),
      OrderStatus.completed =>
        (Icons.verified_outlined, 'Order completed.'),
      OrderStatus.cancelled ||
      OrderStatus.disputed =>
        (Icons.block_outlined, 'No production updates for this order.'),
    };

    return Container(
      width: double.infinity,
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
