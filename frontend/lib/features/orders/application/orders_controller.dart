import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/errors/app_exception.dart';
import '../../../services/api_client.dart';
import '../domain/order.dart';

/// Loads the current user's orders.
final ordersControllerProvider =
    AsyncNotifierProvider<OrdersController, List<Order>>(OrdersController.new);

class OrdersController extends AsyncNotifier<List<Order>> {
  ApiClient get _api => ref.read(apiClientProvider);

  @override
  Future<List<Order>> build() => _fetch();

  Future<List<Order>> _fetch() async {
    final response =
        await _api.get<Map<String, dynamic>>(ApiEndpoints.orders);
    final items = (response.data?['data'] ?? response.data?['orders'] ?? [])
        as List;
    return items
        .map((e) => Order.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Re-fetches the orders list.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  /// Creates a new order request. Returns the created order on success.
  Future<Order?> createOrder({
    required String bakerId,
    String? productId,
    String? title,
    String? description,
    DateTime? eventDate,
    List<String> referenceImageUrls = const [],
  }) async {
    try {
      final response = await _api.post<Map<String, dynamic>>(
        ApiEndpoints.orders,
        data: {
          'baker_id': bakerId,
          if (productId != null) 'product_id': productId,
          if (title != null) 'title': title,
          if (description != null) 'description': description,
          if (eventDate != null) 'event_date': eventDate.toIso8601String(),
          'reference_image_urls': referenceImageUrls,
        },
      );
      final order = Order.fromJson(response.data!);
      await refresh();
      return order;
    } on AppException {
      // TODO: Surface error to the caller / UI.
      return null;
    }
  }
}

/// Loads a single order by id.
final orderDetailProvider =
    FutureProvider.family<Order, String>((ref, orderId) async {
  final api = ref.watch(apiClientProvider);
  final response =
      await api.get<Map<String, dynamic>>(ApiEndpoints.order(orderId));
  return Order.fromJson(response.data!);
});
