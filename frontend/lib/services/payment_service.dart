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

/// Result of initiating an escrow payment. Mirrors the backend `Payment` row
/// returned by the deposit/balance endpoints: a pending STK push whose final
/// state arrives later via the PSP settlement webhook.
class PaymentInitResult {
  const PaymentInitResult({
    required this.status,
    this.paymentId,
    this.pspRef,
    this.amount,
  });

  final PaymentInitStatus status;
  final String? paymentId;
  final String? pspRef;
  final double? amount;

  factory PaymentInitResult.fromJson(Map<String, dynamic> json) {
    return PaymentInitResult(
      // Backend statuses: pending | succeeded | failed.
      status: switch (json['status'] as String?) {
        'succeeded' => PaymentInitStatus.sent,
        'failed' => PaymentInitStatus.failed,
        _ => PaymentInitStatus.pending,
      },
      paymentId: json['id'] as String?,
      pspRef: json['psp_ref'] as String?,
      amount: (json['amount'] as num?)?.toDouble(),
    );
  }
}

/// A baker's ledger position (GET /payouts/balance).
class BakerBalance {
  const BakerBalance({
    required this.available,
    required this.pending,
    required this.paidOut,
  });

  /// Released funds awaiting payout (KES).
  final double available;

  /// Funds held in escrow for in-flight orders (KES).
  final double pending;

  /// Total disbursed to date (KES).
  final double paidOut;

  factory BakerBalance.fromJson(Map<String, dynamic> json) {
    return BakerBalance(
      available: (json['available'] as num?)?.toDouble() ?? 0,
      pending: (json['pending'] as num?)?.toDouble() ?? 0,
      paidOut: (json['paid_out'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Result of a payout request (POST /payouts).
class PayoutResult {
  const PayoutResult({
    required this.id,
    required this.amount,
    required this.status,
    this.pspRef,
  });

  final String id;
  final double amount;
  final String status; // paid | failed | pending
  final String? pspRef;

  factory PayoutResult.fromJson(Map<String, dynamic> json) {
    return PayoutResult(
      id: json['id'].toString(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? '',
      pspRef: json['psp_ref'] as String?,
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

  /// Fetches the caller-baker's available / held / paid-out balances.
  Future<BakerBalance> fetchBalance() async {
    final response =
        await _api.get<Map<String, dynamic>>(ApiEndpoints.payoutsBalance);
    return BakerBalance.fromJson(response.data ?? const {});
  }

  /// Requests a payout of the baker's full available balance.
  Future<PayoutResult> requestPayout() async {
    final response =
        await _api.post<Map<String, dynamic>>(ApiEndpoints.payouts);
    return PayoutResult.fromJson(response.data ?? const {});
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
