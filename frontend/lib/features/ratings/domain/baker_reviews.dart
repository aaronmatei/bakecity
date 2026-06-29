import 'review.dart';

/// A baker's reviews with aggregate rating (GET /bakers/:id/reviews).
class BakerReviews {
  const BakerReviews({
    required this.bakerId,
    required this.averageRating,
    required this.count,
    required this.reviews,
    this.distribution = const [0, 0, 0, 0, 0],
  });

  final String bakerId;
  final double averageRating;
  final int count;
  final List<Review> reviews;

  /// Count of reviews per star, index 0 = 1-star … 4 = 5-star.
  final List<int> distribution;

  factory BakerReviews.fromJson(Map<String, dynamic> json) {
    final list = (json['reviews'] as List?) ?? const [];
    final dist = (json['distribution'] as List?)
            ?.map((e) => (e as num).toInt())
            .toList() ??
        const [0, 0, 0, 0, 0];
    return BakerReviews(
      bakerId: json['baker_id']?.toString() ?? '',
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0,
      count: (json['count'] as num?)?.toInt() ?? 0,
      distribution: dist.length == 5 ? dist : const [0, 0, 0, 0, 0],
      reviews: list
          .map((e) => Review.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
