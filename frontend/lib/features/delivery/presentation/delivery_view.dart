import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../widgets/primary_button.dart';

/// Delivery dispatch + confirmation view for an order.
///
/// Stub: the baker dispatches; the customer confirms receipt, which releases
/// the escrow balance to the baker.
class DeliveryView extends ConsumerWidget {
  const DeliveryView({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Card(
            child: ListTile(
              leading: Icon(Icons.local_shipping_outlined),
              title: Text('Delivery status'),
              subtitle: Text('Not yet dispatched'),
            ),
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: 'Mark as dispatched',
            icon: Icons.send_outlined,
            onPressed: () {
              // TODO: POST ApiEndpoints.orderDeliveryDispatch(orderId).
            },
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              // TODO: POST ApiEndpoints.orderDeliveryConfirm(orderId).
            },
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Confirm receipt'),
          ),
        ],
      ),
    );
  }
}
