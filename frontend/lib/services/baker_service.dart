import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/api_endpoints.dart';
import '../core/errors/app_exception.dart';
import '../features/bakers/domain/my_baker_profile.dart';
import '../features/media/domain/order_media.dart';
import 'api_client.dart';

/// Provides the [BakerService].
final bakerServiceProvider = Provider<BakerService>((ref) {
  return BakerService(api: ref.watch(apiClientProvider));
});

/// Manages the signed-in baker's own profile: loading it, saving onboarding
/// details, and submitting KYC for review.
class BakerService {
  BakerService({required ApiClient api}) : _api = api;

  final ApiClient _api;

  /// A baker's profile by id (public storefront view).
  Future<MyBakerProfile> profile(String id) async {
    final response =
        await _api.get<Map<String, dynamic>>(ApiEndpoints.baker(id));
    return MyBakerProfile.fromJson(response.data!);
  }

  /// The authenticated user's baker profile, or null if they have none yet
  /// (e.g. an older account created before the profile was provisioned).
  Future<MyBakerProfile?> myProfile() async {
    try {
      final response =
          await _api.get<Map<String, dynamic>>(ApiEndpoints.myBaker);
      final data = response.data;
      return data == null ? null : MyBakerProfile.fromJson(data);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Creates (if [id] is null) or updates the baker profile with onboarding
  /// details, returning the saved profile.
  Future<MyBakerProfile> saveDetails({
    String? id,
    required String businessName,
    required String bio,
    required double deliveryRadiusKm,
    required int leadTimeDays,
    required int dailyCapacity,
    double? lat,
    double? lng,
  }) async {
    final body = <String, dynamic>{
      'business_name': businessName,
      'bio': bio,
      'delivery_radius_km': deliveryRadiusKm,
      'lead_time_days': leadTimeDays,
      'daily_order_capacity': dailyCapacity,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
    };
    final response = id == null
        ? await _api.post<Map<String, dynamic>>(ApiEndpoints.bakers, data: body)
        : await _api.patch<Map<String, dynamic>>(
            ApiEndpoints.baker(id),
            data: body,
          );
    return MyBakerProfile.fromJson(response.data!);
  }

  /// Submits the profile's KYC for admin review (moves it to "submitted").
  Future<MyBakerProfile> submitForReview(String id) async {
    final response =
        await _api.post<Map<String, dynamic>>(ApiEndpoints.bakerVerify(id));
    return MyBakerProfile.fromJson(response.data!);
  }

  /// The baker's submitted KYC identity documents (owner or admin), with
  /// presigned URLs for display.
  Future<List<OrderMedia>> kycDocuments(String id) async {
    final response =
        await _api.get<Map<String, dynamic>>(ApiEndpoints.bakerKyc(id));
    final items = (response.data?['documents'] ?? const []) as List;
    return items
        .map((e) => OrderMedia.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
