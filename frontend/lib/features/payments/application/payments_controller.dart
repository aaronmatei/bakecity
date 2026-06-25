import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../services/payment_service.dart';

/// UI state for an in-flight payment.
class PaymentState {
  const PaymentState({
    this.isProcessing = false,
    this.result,
    this.errorMessage,
  });

  final bool isProcessing;
  final PaymentInitResult? result;
  final String? errorMessage;

  PaymentState copyWith({
    bool? isProcessing,
    PaymentInitResult? result,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PaymentState(
      isProcessing: isProcessing ?? this.isProcessing,
      result: result ?? this.result,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Drives deposit / balance payment flows for an order.
final paymentsControllerProvider =
    StateNotifierProvider<PaymentsController, PaymentState>((ref) {
  return PaymentsController(ref.watch(paymentServiceProvider));
});

class PaymentsController extends StateNotifier<PaymentState> {
  PaymentsController(this._service) : super(const PaymentState());

  final PaymentService _service;

  Future<void> payDeposit({
    required String orderId,
    required String phone,
  }) {
    return _run(() => _service.initiateDeposit(orderId: orderId, phone: phone));
  }

  Future<void> payBalance({
    required String orderId,
    required String phone,
  }) {
    return _run(() => _service.initiateBalance(orderId: orderId, phone: phone));
  }

  Future<void> _run(Future<PaymentInitResult> Function() action) async {
    state = state.copyWith(isProcessing: true, clearError: true);
    try {
      final result = await action();
      state = state.copyWith(isProcessing: false, result: result);
    } on AppException catch (e) {
      state = state.copyWith(isProcessing: false, errorMessage: e.message);
    }
  }
}
