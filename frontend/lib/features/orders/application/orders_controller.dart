import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../services/api_client.dart';
import '../../auth/application/auth_controller.dart';
import '../domain/order.dart';

/// Loads the current user's orders.
final ordersControllerProvider =
    AsyncNotifierProvider<OrdersController, List<Order>>(OrdersController.new);

class OrdersController extends AsyncNotifier<List<Order>> {
  ApiClient get _api => ref.read(apiClientProvider);

  @override
  Future<List<Order>> build() {
    // Rebuild when the signed-in user changes, so a stale cache from a previous
    // session can never show another account's orders.
    final userId = ref.watch(authControllerProvider.select((s) => s.user?.id));
    if (userId == null) return Future.value(const []);
    return _fetch();
  }

  Future<List<Order>> _fetch() async {
    // role=all returns every order the user is a party to — orders they placed
    // (as customer) and orders placed with them (as baker). Without it the
    // backend defaults to customer-only, so bakers see none of their orders.
    final response = await _api.get<Map<String, dynamic>>(
      ApiEndpoints.orders,
      queryParameters: {'role': 'all'},
    );
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
  /// Returns the created order; throws an [AppException] on failure so the
  /// caller can surface the message.
  Future<Order> createOrder({
    required String bakerId,
    required DateTime eventDate,
    String? productId,
    String? deliveryAddress,
    String fulfillment = 'delivery',
    bool buyNow = false,
    String? sizeId,
    List<Map<String, dynamic>>? items,
    double? lat,
    double? lng,
    Map<String, String> specs = const {},
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.orders,
      data: {
        'baker_id': bakerId,
        'event_date': _ymd(eventDate),
        'fulfillment': fulfillment,
        if (buyNow) 'buy_now': true,
        if (buyNow && sizeId != null) 'size_id': sizeId,
        if (items != null && items.isNotEmpty) 'items': items,
        if (productId != null) 'product_id': productId,
        if (deliveryAddress != null && deliveryAddress.isNotEmpty)
          'delivery_address': deliveryAddress,
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
  }

  /// Cancels an order, applying the backend's refund matrix. Returns the
  /// updated order (now CANCELLED/REFUNDED) and refreshes the detail + list so
  /// the UI reflects the new status. Throws an [AppException] on failure.
  Future<Order> cancelOrder(String orderId) async {
    final response = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.orderCancel(orderId),
    );
    final order = Order.fromJson(response.data!);
    ref.invalidate(orderDetailProvider(orderId));
    await refresh();
    return order;
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
