import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/helpers/formatters.dart';
import '../../../widgets/app_error_view.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading_indicator.dart';
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
        error: (e, _) => AppErrorView(
          message: e.toString(),
          onRetry: controller.refresh,
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none,
              message: "You're all caught up.",
            );
          }
          return RefreshIndicator(
            onRefresh: controller.refresh,
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final n = items[i];
                final scheme = Theme.of(context).colorScheme;
                return ListTile(
                  leading: Icon(
                    n.read
                        ? Icons.notifications_none
                        : Icons.notifications_active,
                    color: n.read ? null : scheme.primary,
                  ),
                  title: Text(
                    _title(n.type),
                    style: TextStyle(
                      fontWeight: n.read ? FontWeight.normal : FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(Formatters.relativeTime(n.createdAt)),
                  onTap: n.read ? null : () => controller.markRead(n.id),
                );
              },
            ),
          );
        },
      ),
    );
  }

  /// Human-readable title for an event type (mirrors the backend's render()).
  String _title(String type) {
    switch (type) {
      case 'quote_proposed':
        return 'Quote ready';
      case 'quote_accepted':
        return 'Quote accepted';
      case 'deposit_confirmed':
        return 'Deposit confirmed';
      case 'production_update':
        return 'Production update';
      case 'out_for_delivery':
        return 'Out for delivery';
      case 'delivered':
        return 'Delivered';
      case 'order_completed':
        return 'Order completed';
      case 'review_request':
        return 'Leave a review';
      case 'dispute_raised':
        return 'Dispute opened';
      case 'dispute_resolved':
        return 'Dispute resolved';
      case 'payout_sent':
        return 'Payout sent';
      case 'order_cancelled':
        return 'Order cancelled';
      default:
        return 'Notification';
    }
  }
}
