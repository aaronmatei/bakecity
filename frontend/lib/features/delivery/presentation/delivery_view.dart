import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../services/upload_service.dart';
import '../../../widgets/app_error_view.dart';
import '../../../widgets/info_note.dart';
import '../../../widgets/loading_indicator.dart';
import '../../../widgets/media_thumbnail.dart';
import '../../../widgets/primary_button.dart';
import '../../auth/application/auth_controller.dart';
import '../../media/application/media_controller.dart';
import '../../orders/application/orders_controller.dart';
import '../application/delivery_controller.dart';
import '../domain/delivery.dart';

/// Delivery dispatch + proof-of-delivery confirmation for an order.
class DeliveryView extends ConsumerStatefulWidget {
  const DeliveryView({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<DeliveryView> createState() => _DeliveryViewState();
}

class _DeliveryViewState extends ConsumerState<DeliveryView> {
  static const _methods = ['own', 'courier', 'pickup'];
  String _method = 'own';
  final _courierRefController = TextEditingController();
  bool _busy = false;
  bool _uploadingProof = false;
  String? _proofMediaId;

  @override
  void dispose() {
    _courierRefController.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, String okMessage) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(okMessage)));
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _attachProof() async {
    setState(() => _uploadingProof = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final mediaId = await ref.read(uploadServiceProvider).pickAndUpload(
            kind: MediaKind.deliveryProof,
            orderId: widget.orderId,
          );
      if (mediaId != null) {
        setState(() => _proofMediaId = mediaId);
        ref.invalidate(orderMediaProvider(widget.orderId));
        messenger
            .showSnackBar(const SnackBar(content: Text('Proof photo attached.')));
      }
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _uploadingProof = false);
    }
  }

  Future<void> _markDelivered() async {
    await _run(
      () => ref.read(deliveryControllerProvider).confirm(
            orderId: widget.orderId,
            proofMediaId: _proofMediaId,
          ),
      'Order marked delivered.',
    );
    if (mounted) {
      ref.invalidate(orderMediaProvider(widget.orderId));
      setState(() => _proofMediaId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(orderDeliveryProvider(widget.orderId));
    final isBaker =
        ref.watch(authControllerProvider).user?.role == UserRole.baker;
    final orderStatus =
        ref.watch(orderDetailProvider(widget.orderId)).valueOrNull?.status;
    final media =
        ref.watch(orderMediaProvider(widget.orderId)).valueOrNull ?? const [];
    final proofs =
        media.where((m) => m.kind == MediaKind.deliveryProof).toList();
    final proofUrl = proofs.isNotEmpty ? proofs.first.displayUrl : null;

    return async.when(
      loading: () => const LoadingIndicator(),
      error: (e, _) => AppErrorView(
        message: e.toString(),
        onRetry: () => ref.invalidate(orderDeliveryProvider(widget.orderId)),
      ),
      data: (delivery) => ListView(
        padding: const EdgeInsets.all(Insets.screenH),
        children: [
          _statusCard(delivery, proofUrl),
          const SizedBox(height: Insets.lg),
          if (isBaker)
            ..._bakerActions(delivery, orderStatus)
          else
            _customerActions(delivery, orderStatus),
        ],
      ),
    );
  }

  Widget _statusCard(Delivery? d, String? proofUrl) {
    final cs = context.cs;
    final (IconData icon, String subtitle, Color tone) = d == null
        ? (Icons.local_shipping_outlined, 'Not yet dispatched', cs.onSurfaceVariant)
        : d.isDelivered
            ? (Icons.check_circle_outline, 'Delivered', context.bake.success)
            : d.isDispatched
                ? (Icons.local_shipping_outlined,
                    'Out for delivery (${d.method})', cs.primary)
                : (Icons.schedule_outlined, 'Pending', cs.onSurfaceVariant);

    return Container(
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: Radii.cardBorder,
        boxShadow: context.bake.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: tone),
              const SizedBox(width: Insets.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Delivery status',
                      style: context.tt.labelMedium
                          ?.copyWith(color: cs.onSurfaceVariant)),
                  Text(subtitle,
                      style: context.tt.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
          if (proofUrl != null) ...[
            const SizedBox(height: Insets.lg),
            Row(
              children: [
                MediaThumbnail(url: proofUrl, size: 64),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: Text('Proof of delivery',
                      style: context.tt.bodyMedium),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _bakerActions(Delivery? d, OrderStatus? status) {
    if (status == OrderStatus.ready) {
      return [
        DropdownButtonFormField<String>(
          initialValue: _method,
          decoration: const InputDecoration(labelText: 'Method'),
          items: [
            for (final m in _methods)
              DropdownMenuItem(value: m, child: Text(m)),
          ],
          onChanged: _busy ? null : (v) => setState(() => _method = v ?? 'own'),
        ),
        const SizedBox(height: Insets.sm),
        TextField(
          controller: _courierRefController,
          decoration: const InputDecoration(
            labelText: 'Courier reference (optional)',
          ),
        ),
        const SizedBox(height: Insets.lg),
        PrimaryButton(
          label: 'Mark as dispatched',
          icon: Icons.send_outlined,
          isLoading: _busy,
          onPressed: _busy
              ? null
              : () => _run(
                    () => ref.read(deliveryControllerProvider).dispatch(
                          orderId: widget.orderId,
                          method: _method,
                          courierRef: _courierRefController.text.trim(),
                        ),
                    'Order dispatched.',
                  ),
        ),
      ];
    }

    if (status == OrderStatus.dispatched) {
      return [
        const InfoNote(
          icon: Icons.photo_camera_outlined,
          text: 'Attach a drop-off photo to mark this order delivered. '
              '(The customer can also confirm receipt themselves.)',
        ),
        const SizedBox(height: Insets.md),
        OutlinedButton.icon(
          onPressed: _busy || _uploadingProof ? null : _attachProof,
          icon: _uploadingProof
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(_proofMediaId == null
                  ? Icons.add_a_photo_outlined
                  : Icons.check_circle_outline),
          label: Text(
              _proofMediaId == null ? 'Attach proof photo' : 'Proof attached'),
        ),
        const SizedBox(height: Insets.md),
        PrimaryButton(
          label: 'Mark as delivered',
          icon: Icons.check_circle_outline,
          isLoading: _busy,
          onPressed: (_busy || _proofMediaId == null) ? null : _markDelivered,
        ),
      ];
    }

    return [
      InfoNote(
        icon: status == OrderStatus.delivered || status == OrderStatus.completed
            ? Icons.check_circle_outline
            : Icons.timelapse_outlined,
        text: status == OrderStatus.delivered || status == OrderStatus.completed
            ? 'This order has been delivered.'
            : 'You can dispatch once production reaches 100% on the '
                'Production tab.',
      ),
    ];
  }

  Widget _customerActions(Delivery? d, OrderStatus? status) {
    final delivered = d?.isDelivered == true || status == OrderStatus.delivered;
    final canConfirm = status == OrderStatus.dispatched && !delivered;
    // Only a baker can attach proof, so a delivered order WITH proof was closed
    // out by the baker — not the customer confirming receipt.
    final bakerMarked = delivered && d?.proofMediaId != null;

    if (delivered) {
      return InfoNote(
        icon: bakerMarked
            ? Icons.local_shipping_outlined
            : Icons.check_circle_outline,
        text: bakerMarked
            ? 'Your baker marked this order delivered and attached a photo. '
                'Settle the remaining balance on the Payment tab — or open a '
                'dispute on the Issue tab if it didn\'t arrive or there\'s a problem.'
            : 'You\'ve confirmed receipt. Thanks!',
      );
    }
    if (!canConfirm) {
      return const InfoNote(
        icon: Icons.local_shipping_outlined,
        text: 'You can confirm receipt once the baker dispatches your order.',
      );
    }
    return PrimaryButton(
      label: 'Confirm receipt',
      icon: Icons.check_circle_outline,
      isLoading: _busy,
      onPressed: _busy
          ? null
          : () => _run(
                () => ref
                    .read(deliveryControllerProvider)
                    .confirm(orderId: widget.orderId),
                'Receipt confirmed.',
              ),
    );
  }
}
