/// A chat message within an order conversation.
class Message {
  const Message({
    required this.id,
    required this.orderId,
    required this.senderId,
    required this.body,
    required this.createdAt,
    this.attachmentUrls = const [],
    this.readAt,
  });

  final String id;
  final String orderId;
  final String senderId;
  final String body;
  final List<String> attachmentUrls;

  /// When the counterparty read this message; null if still unread.
  final DateTime? readAt;
  final DateTime createdAt;

  /// Whether the counterparty has read this message.
  bool get isRead => readAt != null;

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'].toString(),
      orderId: (json['order_id'] ?? json['thread_id'] ?? '').toString(),
      senderId: json['sender_id'].toString(),
      body: json['body'] as String? ?? '',
      attachmentUrls: (json['attachment_urls'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      readAt: _date(json['read_at']),
      createdAt: _date(json['created_at']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'order_id': orderId,
        'sender_id': senderId,
        'body': body,
        'attachment_urls': attachmentUrls,
        'read_at': readAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };

  static DateTime? _date(Object? value) =>
      value is String && value.isNotEmpty ? DateTime.tryParse(value) : null;
}
