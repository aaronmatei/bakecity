import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';

/// Presentation metadata for [OrderStatus] — a friendly label, accent colour and
/// icon — shared by the dashboards and order lists so status looks consistent.
extension OrderStatusUi on OrderStatus {
  String get label => switch (this) {
        OrderStatus.draft => 'Draft',
        OrderStatus.pendingQuote => 'Awaiting quote',
        OrderStatus.quoted => 'Quote ready',
        OrderStatus.accepted => 'Deposit due',
        OrderStatus.depositPaid => 'Deposit paid',
        OrderStatus.inProduction => 'In production',
        OrderStatus.ready => 'Ready',
        OrderStatus.dispatched => 'Out for delivery',
        OrderStatus.delivered => 'Delivered',
        OrderStatus.completed => 'Completed',
        OrderStatus.cancelled => 'Cancelled',
        OrderStatus.disputed => 'Disputed',
      };

  Color get color => switch (this) {
        OrderStatus.draft => const Color(0xFF9E9E9E),
        OrderStatus.pendingQuote => const Color(0xFFEF6C00),
        OrderStatus.quoted => const Color(0xFF1976D2),
        OrderStatus.accepted => const Color(0xFFEF6C00),
        OrderStatus.depositPaid => const Color(0xFF00897B),
        OrderStatus.inProduction => const Color(0xFF5E35B1),
        OrderStatus.ready => const Color(0xFF2E7D32),
        OrderStatus.dispatched => const Color(0xFF1565C0),
        OrderStatus.delivered => const Color(0xFF2E7D32),
        OrderStatus.completed => const Color(0xFF2E7D32),
        OrderStatus.cancelled => const Color(0xFF757575),
        OrderStatus.disputed => const Color(0xFFC62828),
      };

  IconData get icon => switch (this) {
        OrderStatus.draft => Icons.edit_note,
        OrderStatus.pendingQuote => Icons.hourglass_top,
        OrderStatus.quoted => Icons.request_quote_outlined,
        OrderStatus.accepted => Icons.lock_clock,
        OrderStatus.depositPaid => Icons.verified_outlined,
        OrderStatus.inProduction => Icons.bakery_dining_outlined,
        OrderStatus.ready => Icons.inventory_2_outlined,
        OrderStatus.dispatched => Icons.local_shipping_outlined,
        OrderStatus.delivered => Icons.done_all,
        OrderStatus.completed => Icons.check_circle_outline,
        OrderStatus.cancelled => Icons.cancel_outlined,
        OrderStatus.disputed => Icons.gavel_outlined,
      };

  /// Whether the order is still in flight (not finished or cancelled).
  bool get isActive =>
      this != OrderStatus.completed && this != OrderStatus.cancelled;
}

/// A small rounded status pill used across dashboards and lists.
class OrderStatusChip extends StatelessWidget {
  const OrderStatusChip({super.key, required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final color = status.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
