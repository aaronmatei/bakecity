/// A chat message within an order conversation.
class Message {
  const Message({
    required this.id,
    required this.orderId,
    required this.senderId,
    required this.body,
    required this.createdAt,
    this.attachmentUrls = const [],
    this.isRead = false,
  });

  final String id;
  final String orderId;
  final String senderId;
  final String body;
  final List<String> attachmentUrls;
  final bool isRead;
  final DateTime createdAt;

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'].toString(),
      orderId: json['order_id'].toString(),
      senderId: json['sender_id'].toString(),
      body: json['body'] as String? ?? '',
      attachmentUrls: (json['attachment_urls'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      isRead: json['is_read'] as bool? ?? false,
      createdAt: _date(json['created_at']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'order_id': orderId,
        'sender_id': senderId,
        'body': body,
        'attachment_urls': attachmentUrls,
        'is_read': isRead,
        'created_at': createdAt.toIso8601String(),
      };

  static DateTime? _date(Object? value) =>
      value is String && value.isNotEmpty ? DateTime.tryParse(value) : null;
}
