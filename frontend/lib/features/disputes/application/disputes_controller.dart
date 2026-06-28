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
  return DisputesController(ref);
});

class DisputesController {
  DisputesController(this._ref);

  final Ref _ref;

  /// Opens a new dispute on an order, then refreshes the order's dispute list.
  /// [description], if given, is folded into the reason (the backend takes a
  /// single free-text reason).
  Future<Dispute> raiseDispute({
    required String orderId,
    required String reason,
    String? description,
  }) async {
    final fullReason = (description != null && description.isNotEmpty)
        ? '$reason\n\n$description'
        : reason;
    final response =
        await _ref.read(apiClientProvider).post<Map<String, dynamic>>(
      ApiEndpoints.orderDisputes(orderId),
      data: {'reason': fullReason},
    );
    _ref.invalidate(orderDisputesProvider(orderId));
    return Dispute.fromJson(response.data!);
  }
}
