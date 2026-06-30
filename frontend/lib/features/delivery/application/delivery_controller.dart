import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/errors/app_exception.dart';
import '../../../services/api_client.dart';
import '../../orders/application/orders_controller.dart';
import '../domain/delivery.dart';

/// Loads an order's delivery, or null if it hasn't been dispatched yet (the
/// backend returns 404 until a dispatch row exists).
final orderDeliveryProvider =
    FutureProvider.family<Delivery?, String>((ref, orderId) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.get<Map<String, dynamic>>(
      ApiEndpoints.orderDelivery(orderId),
    );
    final data = response.data;
    return data == null ? null : Delivery.fromJson(data);
  } on ApiException catch (e) {
    if (e.statusCode == 404) return null;
    rethrow;
  }
});

/// Dispatches and confirms deliveries.
final deliveryControllerProvider = Provider<DeliveryController>((ref) {
  return DeliveryController(ref);
});

class DeliveryController {
  DeliveryController(this._ref);

  final Ref _ref;

  /// Baker dispatches the order (READY -> OUT_FOR_DELIVERY).
  Future<void> dispatch({
    required String orderId,
    required String method,
    String? courierRef,
  }) async {
    await _ref.read(apiClientProvider).post<Map<String, dynamic>>(
      ApiEndpoints.orderDeliveryDispatch(orderId),
      data: {
        'method': method,
        if (courierRef != null && courierRef.isNotEmpty)
          'courier_ref': courierRef,
      },
    );
    _ref.invalidate(orderDeliveryProvider(orderId));
    _ref.invalidate(orderDetailProvider(orderId));
  }

  /// Baker submits proof-of-delivery. The order stays OUT_FOR_DELIVERY, awaiting
  /// the customer's confirmation (or the timed auto-confirm).
  Future<void> submitProof({
    required String orderId,
    required String proofMediaId,
  }) async {
    await _ref.read(apiClientProvider).post<Map<String, dynamic>>(
      ApiEndpoints.orderDeliveryProof(orderId),
      data: {'proof_media_id': proofMediaId},
    );
    _ref.invalidate(orderDeliveryProvider(orderId));
    _ref.invalidate(orderDetailProvider(orderId));
  }

  /// Customer confirms receipt, moving the order to DELIVERED and issuing the
  /// balance invoice.
  Future<void> confirm({
    required String orderId,
    String? proofMediaId,
  }) async {
    await _ref.read(apiClientProvider).post<Map<String, dynamic>>(
      ApiEndpoints.orderDeliveryConfirm(orderId),
      data: {
        if (proofMediaId != null && proofMediaId.isNotEmpty)
          'proof_media_id': proofMediaId,
      },
    );
    _ref.invalidate(orderDeliveryProvider(orderId));
    _ref.invalidate(orderDetailProvider(orderId));
  }
}
