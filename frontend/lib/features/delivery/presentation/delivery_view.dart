import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../services/upload_service.dart';
import '../../../widgets/app_error_view.dart';
import '../../../widgets/loading_indicator.dart';
import '../../../widgets/media_thumbnail.dart';
import '../../../widgets/primary_button.dart';
import '../../auth/application/auth_controller.dart';
import '../../media/application/media_controller.dart';
import '../../orders/application/orders_controller.dart';
import '../application/delivery_controller.dart';
import '../domain/delivery.dart';

/// Delivery dispatch + proof-of-delivery confirmation for an order.
///
/// The baker dispatches, then marks the order delivered by attaching a
/// drop-off photo; alternatively the customer confirms receipt. Either path
/// reaches DELIVERED and issues the balance invoice.
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
        padding: const EdgeInsets.all(16),
        children: [
          _statusCard(delivery, proofUrl),
          const SizedBox(height: 16),
          if (isBaker)
            ..._bakerActions(delivery, orderStatus)
          else
            _customerActions(delivery, orderStatus),
        ],
      ),
    );
  }

  Widget _statusCard(Delivery? d, String? proofUrl) {
    final String subtitle;
    if (d == null) {
      subtitle = 'Not yet dispatched';
    } else if (d.isDelivered) {
      subtitle = 'Delivered';
    } else if (d.isDispatched) {
      subtitle = 'Out for delivery (${d.method})';
    } else {
      subtitle = 'Pending';
    }
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.local_shipping_outlined),
            title: const Text('Delivery status'),
            subtitle: Text(subtitle),
          ),
          if (proofUrl != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  MediaThumbnail(url: proofUrl, size: 64),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Proof of delivery',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _bakerActions(Delivery? d, OrderStatus? status) {
    // READY: dispatch. OUT_FOR_DELIVERY: mark delivered with a proof photo.
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
        const SizedBox(height: 8),
        TextField(
          controller: _courierRefController,
          decoration: const InputDecoration(
            labelText: 'Courier reference (optional)',
          ),
        ),
        const SizedBox(height: 16),
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
        const _Hint(
          icon: Icons.photo_camera_outlined,
          text: 'Attach a drop-off photo to mark this order delivered. '
              '(The customer can also confirm receipt themselves.)',
        ),
        const SizedBox(height: 12),
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
        const SizedBox(height: 12),
        PrimaryButton(
          label: 'Mark as delivered',
          icon: Icons.check_circle_outline,
          isLoading: _busy,
          onPressed: (_busy || _proofMediaId == null) ? null : _markDelivered,
        ),
      ];
    }

    return [
      _Hint(
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
    // The customer confirms receipt only once the order is out for delivery.
    final canConfirm = status == OrderStatus.dispatched && !delivered;

    if (delivered) {
      return const _Hint(
        icon: Icons.check_circle_outline,
        text: 'You’ve confirmed receipt. Thanks!',
      );
    }
    if (!canConfirm) {
      return const _Hint(
        icon: Icons.local_shipping_outlined,
        text: 'You can confirm receipt once the baker dispatches your order.',
      );
    }
    return OutlinedButton.icon(
      onPressed: _busy
          ? null
          : () => _run(
                () => ref
                    .read(deliveryControllerProvider)
                    .confirm(orderId: widget.orderId),
                'Receipt confirmed.',
              ),
      icon: const Icon(Icons.check_circle_outline),
      label: const Text('Confirm receipt'),
    );
  }
}

/// A small contextual hint row used when no action is currently available.
class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
