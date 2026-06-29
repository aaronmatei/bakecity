import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/helpers/formatters.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../widgets/app_error_view.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading_indicator.dart';
import '../../../widgets/press_scale.dart';
import '../application/notifications_controller.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsControllerProvider);
    final controller = ref.read(notificationsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            tooltip: 'Mark all read',
            icon: const Icon(Icons.done_all),
            onPressed: () => controller.markAllRead(),
          ),
        ],
      ),
      body: async.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => AppErrorView(message: e.toString(), onRetry: controller.refresh),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none,
              title: 'All caught up',
              message: 'New updates about your orders will show up here.',
            );
          }
          return RefreshIndicator(
            color: context.cs.primary,
            onRefresh: controller.refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(Insets.screenH),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: Insets.md),
              itemBuilder: (context, i) {
                final n = items[i];
                return _NotificationCard(
                  type: n.type,
                  unread: !n.read,
                  time: Formatters.relativeTime(n.createdAt),
                  onTap: n.read ? null : () => controller.markRead(n.id),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.type,
    required this.unread,
    required this.time,
    required this.onTap,
  });

  final String type;
  final bool unread;
  final String time;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final accent = _accent(type, context);
    return PressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(Insets.md),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: Radii.cardBorder,
          boxShadow: context.bake.cardShadow,
          border: unread
              ? Border.all(color: cs.primary.withValues(alpha: 0.4))
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(_icon(type), size: 20, color: accent),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _title(type),
                    style: context.tt.titleSmall?.copyWith(
                      fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(time,
                      style: context.tt.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            if (unread)
              Container(
                width: 9,
                height: 9,
                decoration:
                    BoxDecoration(color: cs.primary, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }

  Color _accent(String type, BuildContext context) {
    final bake = context.bake;
    return switch (type) {
      'deposit_confirmed' || 'order_completed' || 'payout_sent' => bake.success,
      'dispute_raised' || 'order_cancelled' => bake.berry,
      _ => context.cs.primary,
    };
  }

  IconData _icon(String type) => switch (type) {
        'quote_proposed' => Icons.request_quote_outlined,
        'quote_accepted' => Icons.handshake_outlined,
        'deposit_confirmed' => Icons.verified_outlined,
        'production_update' => Icons.bakery_dining_outlined,
        'out_for_delivery' => Icons.local_shipping_outlined,
        'delivered' => Icons.done_all,
        'order_completed' => Icons.check_circle_outline,
        'review_request' => Icons.star_outline,
        'dispute_raised' => Icons.gavel_outlined,
        'dispute_resolved' => Icons.balance_outlined,
        'payout_sent' => Icons.account_balance_wallet_outlined,
        'order_cancelled' => Icons.cancel_outlined,
        _ => Icons.notifications_outlined,
      };

  String _title(String type) => switch (type) {
        'quote_proposed' => 'Quote ready',
        'quote_accepted' => 'Quote accepted',
        'deposit_confirmed' => 'Deposit confirmed',
        'production_update' => 'Production update',
        'out_for_delivery' => 'Out for delivery',
        'delivered' => 'Delivered',
        'order_completed' => 'Order completed',
        'review_request' => 'Leave a review',
        'dispute_raised' => 'Dispute opened',
        'dispute_resolved' => 'Dispute resolved',
        'payout_sent' => 'Payout sent',
        'order_cancelled' => 'Order cancelled',
        _ => 'Notification',
      };
}
