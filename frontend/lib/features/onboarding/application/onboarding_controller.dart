import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/baker_service.dart';
import '../../bakers/domain/my_baker_profile.dart';

/// Loads the signed-in baker's profile for the KYC onboarding flow and drives
/// the "submit for review" action.
final onboardingControllerProvider =
    AsyncNotifierProvider<OnboardingController, MyBakerProfile?>(
  OnboardingController.new,
);

class OnboardingController extends AsyncNotifier<MyBakerProfile?> {
  BakerService get _service => ref.read(bakerServiceProvider);

  @override
  Future<MyBakerProfile?> build() => _service.myProfile();

  /// Reloads the profile (used to retry after an error).
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_service.myProfile);
  }

  /// Saves the baker's details, then submits KYC for review. On success the
  /// profile state advances to "under review". Throws on failure so the caller
  /// can surface a message without discarding the loaded form.
  Future<void> submit({
    required String businessName,
    required String bio,
    required double deliveryRadiusKm,
    required int leadTimeDays,
    required int dailyCapacity,
    double? lat,
    double? lng,
  }) async {
    final current = state.valueOrNull;
    final saved = await _service.saveDetails(
      id: current?.id,
      businessName: businessName,
      bio: bio,
      deliveryRadiusKm: deliveryRadiusKm,
      leadTimeDays: leadTimeDays,
      dailyCapacity: dailyCapacity,
      lat: lat,
      lng: lng,
    );
    final reviewed = await _service.submitForReview(saved.id);
    state = AsyncValue.data(reviewed);
  }
}
