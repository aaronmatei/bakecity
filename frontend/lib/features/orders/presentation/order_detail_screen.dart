import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/orders_controller.dart';
import '../../delivery/presentation/delivery_view.dart';
import '../../disputes/presentation/dispute_view.dart';
import '../../messaging/presentation/messaging_view.dart';
import '../../payments/presentation/payment_view.dart';
import '../../production/presentation/production_view.dart';
import '../../quotes/presentation/quotes_view.dart';

/// Order detail with tabs for chat, quotes, production, delivery, payment and
/// disputes.
class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: ref.watch(orderDetailProvider(orderId)).maybeWhen(
                data: (o) => Text('Order #${o.number ?? orderId}'),
                orElse: () => const Text('Order'),
              ),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Chat'),
              Tab(text: 'Quotes'),
              Tab(text: 'Production'),
              Tab(text: 'Delivery'),
              Tab(text: 'Payment'),
              Tab(text: 'Dispute'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            MessagingView(orderId: orderId),
            QuotesView(orderId: orderId),
            ProductionView(orderId: orderId),
            DeliveryView(orderId: orderId),
            PaymentView(orderId: orderId),
            DisputeView(orderId: orderId),
          ],
        ),
      ),
    );
  }
}
