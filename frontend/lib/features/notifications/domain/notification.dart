/// An in-app notification from the backend feed (`GET /notifications`).
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.channel,
    required this.payload,
    required this.createdAt,
    required this.read,
  });

  final String id;

  /// Event type, e.g. `deposit_confirmed`, `order_completed`, `payout_sent`.
  final String type;

  /// Delivery channel: `in_app`, `push`, or `sms`.
  final String channel;

  /// Structured event data (e.g. `{order_id, amount}`).
  final Map<String, dynamic> payload;

  final DateTime createdAt;
  final bool read;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'].toString(),
      type: json['type'] as String? ?? '',
      channel: json['channel'] as String? ?? 'in_app',
      payload: (json['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      read: json['read_at'] != null,
    );
  }
}
