import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/api_endpoints.dart';
import 'api_client.dart';

/// Provides the [SmsStatusService].
final smsStatusServiceProvider = Provider<SmsStatusService>((ref) {
  return SmsStatusService(ref.watch(apiClientProvider));
});

/// Tracks delivery status of SMS-critical notifications.
///
/// Some events (deposit received, order ready, dispatch) are delivered to
/// customers over SMS for reliability. This service polls the backend for the
/// latest status of an order so the UI can reflect SMS confirmation.
class SmsStatusService {
  SmsStatusService(this._api);

  final ApiClient _api;

  /// Fetches the latest order status snapshot (used to confirm SMS-critical
  /// state transitions). Returns the raw status map.
  Future<Map<String, dynamic>> fetchOrderStatus(String orderId) async {
    final response = await _api.get<Map<String, dynamic>>(
      ApiEndpoints.order(orderId),
    );
    return response.data ?? const {};
  }

  /// Polls [fetchOrderStatus] on an interval until [predicate] returns true or
  /// [timeout] elapses. Yields each polled snapshot.
  Stream<Map<String, dynamic>> pollOrderStatus(
    String orderId, {
    Duration interval = const Duration(seconds: 5),
    Duration timeout = const Duration(minutes: 2),
    bool Function(Map<String, dynamic> status)? predicate,
  }) async* {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final status = await fetchOrderStatus(orderId);
      yield status;
      if (predicate != null && predicate(status)) return;
      await Future<void>.delayed(interval);
    }
  }
}
