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

  /// Creates a new order request (status QUOTE_REQUESTED). [eventDate] is sent
  /// as YYYY-MM-DD; [specs] are free-form key/value attributes (flavor, tiers…).
  /// Returns the created order on success.
  Future<Order?> createOrder({
    required String bakerId,
    required DateTime eventDate,
    String? productId,
    String? deliveryAddress,
    double? lat,
    double? lng,
    Map<String, String> specs = const {},
  }) async {
    try {
      final response = await _api.post<Map<String, dynamic>>(
        ApiEndpoints.orders,
        data: {
          'baker_id': bakerId,
          'event_date': _ymd(eventDate),
          if (productId != null) 'product_id': productId,
          if (deliveryAddress != null) 'delivery_address': deliveryAddress,
          if (lat != null) 'lat': lat,
          if (lng != null) 'lng': lng,
          if (specs.isNotEmpty)
            'specs': [
              for (final e in specs.entries) {'key': e.key, 'value': e.value},
            ],
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

  /// Formats a date as the backend's expected YYYY-MM-DD.
  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// Loads a single order by id.
final orderDetailProvider =
    FutureProvider.family<Order, String>((ref, orderId) async {
  final api = ref.watch(apiClientProvider);
  final response =
      await api.get<Map<String, dynamic>>(ApiEndpoints.order(orderId));
  return Order.fromJson(response.data!);
});
