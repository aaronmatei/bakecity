import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/api_endpoints.dart';
import '../core/errors/app_exception.dart';
import 'api_client.dart';

/// Provides the [PaymentService].
final paymentServiceProvider = Provider<PaymentService>((ref) {
  return PaymentService(ref.watch(apiClientProvider));
});

/// Status of an initiated payment (M-Pesa STK push, etc.).
enum PaymentInitStatus { pending, sent, failed }

/// Result of initiating an escrow payment.
class PaymentInitResult {
  const PaymentInitResult({
    required this.status,
    this.checkoutRequestId,
    this.message,
  });

  final PaymentInitStatus status;
  final String? checkoutRequestId;
  final String? message;

  factory PaymentInitResult.fromJson(Map<String, dynamic> json) {
    return PaymentInitResult(
      status: switch (json['status'] as String?) {
        'sent' => PaymentInitStatus.sent,
        'failed' => PaymentInitStatus.failed,
        _ => PaymentInitStatus.pending,
      },
      checkoutRequestId: json['checkout_request_id'] as String?,
      message: json['message'] as String?,
    );
  }
}

/// Triggers escrow deposit / balance payments via the backend.
///
/// The backend handles the actual provider integration and receives the
/// async confirmation webhook; the client just initiates and then polls /
/// listens for status. These methods are intentionally thin stubs.
class PaymentService {
  PaymentService(this._api);

  final ApiClient _api;

  /// Initiates the deposit (escrow) STK push for an order.
  Future<PaymentInitResult> initiateDeposit({
    required String orderId,
    required String phone,
  }) {
    return _initiate(
      ApiEndpoints.orderPaymentDeposit(orderId),
      phone: phone,
    );
  }

  /// Initiates the balance payment STK push for an order.
  Future<PaymentInitResult> initiateBalance({
    required String orderId,
    required String phone,
  }) {
    return _initiate(
      ApiEndpoints.orderPaymentBalance(orderId),
      phone: phone,
    );
  }

  Future<PaymentInitResult> _initiate(
    String path, {
    required String phone,
  }) async {
    // TODO: Surface provider-specific reference/amount once finalised.
    final response = await _api.post<Map<String, dynamic>>(
      path,
      data: {'phone': phone},
    );
    final data = response.data;
    if (data == null) {
      throw const ApiException(
        statusCode: 500,
        message: 'Empty payment response.',
      );
    }
    return PaymentInitResult.fromJson(data);
  }
}
