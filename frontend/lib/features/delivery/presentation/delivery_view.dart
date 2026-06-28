import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../auth/application/auth_controller.dart';
import '../../../widgets/app_error_view.dart';
import '../../../widgets/loading_indicator.dart';
import '../../../widgets/primary_button.dart';
import '../application/delivery_controller.dart';
import '../domain/delivery.dart';

/// Delivery dispatch + proof-of-delivery confirmation for an order.
///
/// The baker dispatches; the customer confirms receipt, which releases the
/// escrow balance.
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

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(orderDeliveryProvider(widget.orderId));
    final isBaker =
        ref.watch(authControllerProvider).user?.role == UserRole.baker;

    return async.when(
      loading: () => const LoadingIndicator(),
      error: (e, _) => AppErrorView(
        message: e.toString(),
        onRetry: () => ref.invalidate(orderDeliveryProvider(widget.orderId)),
      ),
      data: (delivery) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _statusCard(delivery),
          const SizedBox(height: 16),
          if (isBaker) ..._bakerActions(delivery) else _customerActions(delivery),
        ],
      ),
    );
  }

  Widget _statusCard(Delivery? d) {
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
      child: ListTile(
        leading: const Icon(Icons.local_shipping_outlined),
        title: const Text('Delivery status'),
        subtitle: Text(subtitle),
      ),
    );
  }

  List<Widget> _bakerActions(Delivery? d) {
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
        label: d?.isDispatched == true ? 'Re-dispatch' : 'Mark as dispatched',
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

  Widget _customerActions(Delivery? d) {
    return OutlinedButton.icon(
      onPressed: _busy || d?.isDelivered == true
          ? null
          : () => _run(
                () => ref
                    .read(deliveryControllerProvider)
                    .confirm(orderId: widget.orderId),
                'Receipt confirmed.',
              ),
      icon: const Icon(Icons.check_circle_outline),
      label: Text(d?.isDelivered == true ? 'Delivered' : 'Confirm receipt'),
    );
  }
}
