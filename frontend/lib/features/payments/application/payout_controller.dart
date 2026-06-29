import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/payment_service.dart';
import '../../auth/application/auth_controller.dart';

/// Loads the baker's balance and drives payout requests.
final payoutControllerProvider =
    AsyncNotifierProvider<PayoutController, BakerBalance>(PayoutController.new);

class PayoutController extends AsyncNotifier<BakerBalance> {
  PaymentService get _service => ref.read(paymentServiceProvider);

  @override
  Future<BakerBalance> build() {
    // Reset on account change so one baker never sees another's balance.
    ref.watch(authControllerProvider.select((s) => s.user?.id));
    return _service.fetchBalance();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(_service.fetchBalance);
  }

  /// Requests a payout of the full available balance, then refreshes the
  /// balance. Throws [AppException] on failure for the caller to surface.
  Future<PayoutResult> withdraw() async {
    final result = await _service.requestPayout();
    state = await AsyncValue.guard(_service.fetchBalance);
    return result;
  }
}
