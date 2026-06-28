import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/errors/app_exception.dart';
import '../../../services/api_client.dart';
import '../domain/baker_reviews.dart';
import '../domain/review.dart';

/// The review for an order, or null if none has been left yet (404).
final orderReviewProvider =
    FutureProvider.family<Review?, String>((ref, orderId) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response =
        await api.get<Map<String, dynamic>>(ApiEndpoints.orderReview(orderId));
    final data = response.data;
    return data == null ? null : Review.fromJson(data);
  } on ApiException catch (e) {
    if (e.statusCode == 404) return null;
    rethrow;
  }
});

/// A baker's reviews with aggregate rating.
final bakerReviewsProvider =
    FutureProvider.family<BakerReviews, String>((ref, bakerId) async {
  final api = ref.watch(apiClientProvider);
  final response =
      await api.get<Map<String, dynamic>>(ApiEndpoints.bakerReviews(bakerId));
  return BakerReviews.fromJson(response.data ?? const {});
});

/// Submits customer reviews of completed orders.
final reviewsControllerProvider = Provider<ReviewsController>((ref) {
  return ReviewsController(ref);
});

class ReviewsController {
  ReviewsController(this._ref);

  final Ref _ref;

  /// Posts a 1–5 star review for a completed order, then refreshes its review.
  Future<Review> submit({
    required String orderId,
    required int rating,
    String? body,
  }) async {
    final response =
        await _ref.read(apiClientProvider).post<Map<String, dynamic>>(
      ApiEndpoints.reviews,
      data: {
        'order_id': orderId,
        'rating': rating,
        if (body != null && body.isNotEmpty) 'body': body,
      },
    );
    _ref.invalidate(orderReviewProvider(orderId));
    return Review.fromJson(response.data!);
  }
}
