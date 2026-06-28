import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../services/api_client.dart';
import '../domain/production_update.dart';

/// Loads an order's production timeline (chronological).
final orderProductionProvider =
    FutureProvider.family<List<ProductionUpdate>, String>((ref, orderId) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.get<Map<String, dynamic>>(
    ApiEndpoints.orderProduction(orderId),
  );
  final items = (response.data?['updates'] ?? const []) as List;
  return items
      .map((e) => ProductionUpdate.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Posts production updates (baker only; the backend enforces authorization).
final productionControllerProvider = Provider<ProductionController>((ref) {
  return ProductionController(ref);
});

class ProductionController {
  ProductionController(this._ref);

  final Ref _ref;

  /// Posts a stage update. A progress of 100 marks the order READY. Refreshes
  /// the timeline on success.
  Future<void> addUpdate({
    required String orderId,
    required String stage,
    required int progressPct,
    String? notes,
    String? mediaId,
  }) async {
    final api = _ref.read(apiClientProvider);
    await api.post<Map<String, dynamic>>(
      ApiEndpoints.orderProduction(orderId),
      data: {
        'stage': stage,
        'progress_pct': progressPct,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (mediaId != null && mediaId.isNotEmpty) 'media_id': mediaId,
      },
    );
    _ref.invalidate(orderProductionProvider(orderId));
  }
}
