import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/helpers/formatters.dart';
import '../../../routes/app_routes.dart';
import '../../../widgets/app_error_view.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading_indicator.dart';
import '../application/orders_controller.dart';

class OrdersListScreen extends ConsumerWidget {
  const OrdersListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Orders')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(ordersControllerProvider.notifier).refresh(),
        child: orders.when(
          loading: () => const LoadingIndicator(),
          error: (e, _) => AppErrorView(
            message: e.toString(),
            onRetry: () =>
                ref.read(ordersControllerProvider.notifier).refresh(),
          ),
          data: (list) {
            if (list.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  EmptyState(
                    icon: Icons.receipt_long_outlined,
                    message: 'You have no orders yet.',
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final order = list[i];
                return Card(
                  child: ListTile(
                    title: Text(order.title ?? 'Order #${order.id}'),
                    subtitle: Text(
                      '${_statusLabel(order.status)} • '
                      '${Formatters.shortDate(order.createdAt)}',
                    ),
                    trailing: order.status == OrderStatus.completed
                        ? TextButton(
                            onPressed: () => context.goNamed(
                              AppRoutes.orderReviewName,
                              pathParameters: {'orderId': order.id},
                            ),
                            child: const Text('Review'),
                          )
                        : (order.totalCents != null
                            ? Text(
                                Formatters.currencyFromCents(order.totalCents!))
                            : null),
                    onTap: () => context.goNamed(
                      AppRoutes.orderDetailName,
                      pathParameters: {'orderId': order.id},
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _statusLabel(OrderStatus status) {
    return status.name
        .replaceAllMapped(
          RegExp('[A-Z]'),
          (m) => ' ${m.group(0)}',
        )
        .trim();
  }
}
