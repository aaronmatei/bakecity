/// A customer review of a baker / completed order.
class Review {
  const Review({
    required this.id,
    required this.orderId,
    required this.bakerId,
    required this.authorId,
    required this.rating,
    required this.createdAt,
    this.authorName,
    this.comment,
    this.imageUrls = const [],
  });

  final String id;
  final String orderId;
  final String bakerId;
  final String authorId;
  final String? authorName;

  /// Star rating from 1 to 5.
  final int rating;
  final String? comment;
  final List<String> imageUrls;
  final DateTime createdAt;

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'].toString(),
      orderId: json['order_id'].toString(),
      bakerId: json['baker_id'].toString(),
      authorId: json['author_id'].toString(),
      authorName: json['author_name'] as String?,
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      comment: json['comment'] as String?,
      imageUrls:
          (json['image_urls'] as List?)?.map((e) => e.toString()).toList() ??
              const [],
      createdAt: _date(json['created_at']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'order_id': orderId,
        'baker_id': bakerId,
        'author_id': authorId,
        'author_name': authorName,
        'rating': rating,
        'comment': comment,
        'image_urls': imageUrls,
        'created_at': createdAt.toIso8601String(),
      };

  static DateTime? _date(Object? value) =>
      value is String && value.isNotEmpty ? DateTime.tryParse(value) : null;
}
