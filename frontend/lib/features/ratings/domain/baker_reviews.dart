import 'review.dart';

/// A baker's reviews with aggregate rating (GET /bakers/:id/reviews).
class BakerReviews {
  const BakerReviews({
    required this.bakerId,
    required this.averageRating,
    required this.count,
    required this.reviews,
  });

  final String bakerId;
  final double averageRating;
  final int count;
  final List<Review> reviews;

  factory BakerReviews.fromJson(Map<String, dynamic> json) {
    final list = (json['reviews'] as List?) ?? const [];
    return BakerReviews(
      bakerId: json['baker_id']?.toString() ?? '',
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0,
      count: (json['count'] as num?)?.toInt() ?? 0,
      reviews: list
          .map((e) => Review.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
