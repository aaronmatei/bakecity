import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/helpers/formatters.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../routes/app_routes.dart';
import '../../../widgets/app_error_view.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading_indicator.dart';
import '../../../widgets/network_photo.dart';
import '../../../widgets/press_scale.dart';
import '../domain/order.dart';
import '../domain/order_status_ui.dart';
import '../application/orders_controller.dart';

/// The customer's orders, as premium cards with a live status chip and a
/// lifecycle progress bar.
class OrdersListScreen extends ConsumerWidget {
  const OrdersListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Your orders')),
      body: RefreshIndicator(
        color: context.cs.primary,
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
                    title: 'No orders yet',
                    message: 'When you order a custom bake, you can track it here.',
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(Insets.screenH),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: Insets.lg),
              itemBuilder: (context, i) => _OrderCard(order: list[i]),
            );
          },
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});
  final Order order;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final image = order.referenceImageUrls.isNotEmpty
        ? order.referenceImageUrls.first
        : null;
    final completed = order.status == OrderStatus.completed;
    final cancelled = order.status == OrderStatus.cancelled;
    // The agreed price is the order total, set once a quote is accepted.
    final hasPrice = order.totalCents != null && order.totalCents! > 0;

    return PressScale(
      onTap: () => context.pushNamed(
        AppRoutes.orderDetailName,
        pathParameters: {'orderId': order.id},
      ),
      child: Container(
        padding: const EdgeInsets.all(Insets.md),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: Radii.cardBorder,
          boxShadow: context.bake.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NetworkPhoto(
                  url: image,
                  width: 60,
                  height: 60,
                  radius: Radii.chip,
                  fallbackIcon: Icons.cake_outlined,
                ),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.title ?? 'Order #${order.number ?? order.id}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.tt.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        Formatters.shortDate(order.createdAt),
                        style: context.tt.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(height: Insets.sm),
                      OrderStatusChip(status: order.status),
                    ],
                  ),
                ),
                const SizedBox(width: Insets.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasPrice) ...[
                      Text('Agreed',
                          style: context.tt.labelSmall
                              ?.copyWith(color: cs.onSurfaceVariant)),
                      Text(
                        Formatters.currencyFromCents(order.totalCents!),
                        style: context.tt.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ] else if (!completed)
                      Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
                    if (completed)
                      TextButton(
                        onPressed: () => context.pushNamed(
                          AppRoutes.orderReviewName,
                          pathParameters: {'orderId': order.id},
                        ),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          foregroundColor: cs.primary,
                        ),
                        child: const Text('Review'),
                      ),
                  ],
                ),
              ],
            ),
            if (!cancelled) ...[
              const SizedBox(height: Insets.md),
              _LifecycleBar(status: order.status),
              if (hasPrice) ...[
                const SizedBox(height: Insets.md),
                _DepositBalanceRow(order: order),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// The agreed price split into deposit + balance, each marked paid or due.
class _DepositBalanceRow extends StatelessWidget {
  const _DepositBalanceRow({required this.order});
  final Order order;

  static const _depositPaidStatuses = {
    OrderStatus.depositPaid,
    OrderStatus.inProduction,
    OrderStatus.ready,
    OrderStatus.dispatched,
    OrderStatus.delivered,
    OrderStatus.completed,
  };

  @override
  Widget build(BuildContext context) {
    final depositPaid = _depositPaidStatuses.contains(order.status);
    final balancePaid = order.status == OrderStatus.completed;
    return Row(
      children: [
        Expanded(
          child: _Leg(
            label: 'Deposit',
            cents: order.depositCents,
            paid: depositPaid,
          ),
        ),
        const SizedBox(width: Insets.md),
        Expanded(
          child: _Leg(
            label: 'Balance',
            cents: order.balanceCents,
            paid: balancePaid,
          ),
        ),
      ],
    );
  }
}

class _Leg extends StatelessWidget {
  const _Leg({required this.label, required this.cents, required this.paid});
  final String label;
  final int? cents;
  final bool paid;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final color = paid ? context.bake.success : cs.onSurfaceVariant;
    final amount = cents != null ? Formatters.currencyFromCents(cents!) : '—';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(paid ? Icons.check_circle : Icons.schedule_outlined,
            size: 13, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            '$label $amount · ${paid ? 'paid' : 'due'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.tt.bodySmall?.copyWith(color: cs.onSurface),
          ),
        ),
      ],
    );
  }
}

/// A thin progress bar showing how far the order is through its lifecycle,
/// tinted with the status colour.
class _LifecycleBar extends StatelessWidget {
  const _LifecycleBar({required this.status});
  final OrderStatus status;

  double get _fraction => switch (status) {
        OrderStatus.draft ||
        OrderStatus.pendingQuote ||
        OrderStatus.quoted =>
          0.1,
        OrderStatus.accepted => 0.22,
        OrderStatus.depositPaid => 0.38,
        OrderStatus.inProduction => 0.58,
        OrderStatus.ready => 0.72,
        OrderStatus.dispatched => 0.86,
        OrderStatus.delivered => 0.95,
        OrderStatus.completed => 1.0,
        OrderStatus.cancelled || OrderStatus.disputed => 0.0,
      };

  @override
  Widget build(BuildContext context) {
    final color = status.color;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: _fraction),
        duration: context.reduceMotion ? Duration.zero : Motion.slow,
        curve: Motion.curve,
        builder: (context, t, _) => LinearProgressIndicator(
          value: t,
          minHeight: 6,
          backgroundColor: context.cs.outlineVariant,
          valueColor: AlwaysStoppedAnimation(color),
        ),
      ),
    );
  }
}
