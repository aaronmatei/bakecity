import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../services/api_client.dart';
import '../domain/dispute.dart';

/// Loads disputes for an order.
final orderDisputesProvider =
    FutureProvider.family<List<Dispute>, String>((ref, orderId) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.get<Map<String, dynamic>>(
    ApiEndpoints.orderDisputes(orderId),
  );
  final items =
      (response.data?['data'] ?? response.data?['disputes'] ?? []) as List;
  return items
      .map((e) => Dispute.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Raises disputes against an order.
final disputesControllerProvider = Provider<DisputesController>((ref) {
  return DisputesController(ref.read(apiClientProvider));
});

class DisputesController {
  DisputesController(this._api);

  final ApiClient _api;

  /// Opens a new dispute on an order.
  Future<Dispute> raiseDispute({
    required String orderId,
    required String reason,
    String? description,
    List<String> evidenceUrls = const [],
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.orderDisputes(orderId),
      data: {
        'reason': reason,
        if (description != null) 'description': description,
        'evidence_urls': evidenceUrls,
      },
    );
    return Dispute.fromJson(response.data!);
  }
}
