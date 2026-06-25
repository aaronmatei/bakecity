import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Production timeline / stage tracker for an order.
///
/// Stub: the baker advances production stages and posts progress photos;
/// the customer sees a read-only timeline.
class ProductionView extends ConsumerWidget {
  const ProductionView({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO: Load stages from ApiEndpoints.orderProduction(orderId).
    const stages = ['Confirmed', 'Baking', 'Decorating', 'Ready'];
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: stages.length,
      itemBuilder: (context, i) {
        return ListTile(
          leading: CircleAvatar(child: Text('${i + 1}')),
          title: Text(stages[i]),
          subtitle: const Text('Pending'),
        );
      },
    );
  }
}
