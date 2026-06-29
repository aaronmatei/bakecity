import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/baker_service.dart';
import '../domain/my_baker_profile.dart';

/// Loads a baker's profile for the public storefront view.
final bakerProfileProvider =
    FutureProvider.family<MyBakerProfile, String>((ref, bakerId) {
  return ref.watch(bakerServiceProvider).profile(bakerId);
});
