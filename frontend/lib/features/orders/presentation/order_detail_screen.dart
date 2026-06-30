import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../application/orders_controller.dart';
import '../../delivery/presentation/delivery_view.dart';
import '../../disputes/presentation/dispute_view.dart';
import '../../media/presentation/order_gallery_view.dart';
import '../../messaging/presentation/messaging_view.dart';
import '../../payments/presentation/payment_view.dart';
import '../../production/presentation/production_view.dart';
import '../../quotes/presentation/quotes_view.dart';
import 'cancel_order_dialog.dart';

/// Order detail with tabs for chat, quotes, production, photos, delivery,
/// payment and disputes. The app bar offers a cancel action while the order is
/// still cancellable for the current user.
class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderDetailProvider(orderId));
    final user = ref.watch(authControllerProvider).user;
    final isCustomer = user?.isCustomer ?? false;
    final order = orderAsync.valueOrNull;
    final canCancel =
        order != null && orderCancellable(order.status, isCustomer: isCustomer);

    return DefaultTabController(
      length: 7,
      child: Scaffold(
        appBar: AppBar(
          title: orderAsync.maybeWhen(
            data: (o) {
              final counterparty = (user?.id != null && o.customerId == user!.id)
                  ? o.bakerName
                  : o.customerName;
              if (counterparty == null || counterparty.isEmpty) {
                return Text('Order #${o.number ?? orderId}');
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Order #${o.number ?? orderId}'),
                  Text(
                    'with $counterparty',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              );
            },
            orElse: () => const Text('Order'),
          ),
          actions: [
            if (canCancel)
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'cancel') {
                    showCancelOrderDialog(context, ref, order,
                        isCustomer: isCustomer);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'cancel',
                    child: Row(
                      children: [
                        Icon(Icons.cancel_outlined,
                            color: Theme.of(context).colorScheme.error),
                        const SizedBox(width: 8),
                        const Text('Cancel order'),
                      ],
                    ),
                  ),
                ],
              ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Chat'),
              Tab(text: 'Quotes'),
              Tab(text: 'Production'),
              Tab(text: 'Photos'),
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
            OrderGalleryView(orderId: orderId),
            DeliveryView(orderId: orderId),
            PaymentView(orderId: orderId),
            DisputeView(orderId: orderId),
          ],
        ),
      ),
    );
  }
}
