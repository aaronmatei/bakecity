import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../services/api_client.dart';
import '../../auth/application/auth_controller.dart';
import '../domain/baker_insights.dart';

/// The signed-in baker's order-book insights. Scoped to the auth user id so it
/// resets when the account changes (never leaks one baker's numbers to another).
final bakerInsightsProvider = FutureProvider<BakerInsights>((ref) async {
  ref.watch(authControllerProvider.select((s) => s.user?.id));
  final api = ref.watch(apiClientProvider);
  final response =
      await api.get<Map<String, dynamic>>(ApiEndpoints.orderInsights);
  return BakerInsights.fromJson(response.data ?? const {});
});
