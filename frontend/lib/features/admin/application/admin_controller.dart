import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/admin_service.dart';
import '../../../services/baker_service.dart';
import '../../disputes/domain/dispute.dart';
import '../../media/domain/order_media.dart';
import '../domain/baker_summary.dart';
import '../domain/platform_stats.dart';

/// Baker approval queue.
final pendingBakersProvider =
    FutureProvider.autoDispose<List<BakerSummary>>((ref) {
  return ref.read(adminServiceProvider).pendingBakers();
});

/// A pending baker's submitted KYC identity documents, for review.
final bakerKycDocsProvider =
    FutureProvider.autoDispose.family<List<OrderMedia>, String>((ref, bakerId) {
  return ref.read(bakerServiceProvider).kycDocuments(bakerId);
});

/// Open dispute queue.
final adminDisputesProvider = FutureProvider.autoDispose<List<Dispute>>((ref) {
  return ref.read(adminServiceProvider).disputes();
});

/// Platform analytics snapshot.
final adminAnalyticsProvider =
    FutureProvider.autoDispose<PlatformStats>((ref) {
  return ref.read(adminServiceProvider).analytics();
});

/// Admin mutations that refresh the relevant queues on success.
final adminControllerProvider = Provider<AdminController>((ref) {
  return AdminController(ref);
});

class AdminController {
  AdminController(this._ref);

  final Ref _ref;

  AdminService get _svc => _ref.read(adminServiceProvider);

  Future<void> approveBaker(String id) async {
    await _svc.approveBaker(id);
    _ref.invalidate(pendingBakersProvider);
  }

  Future<void> resolveDispute(
    String id, {
    required String resolution,
    double refundAmount = 0,
  }) async {
    await _svc.resolveDispute(id, resolution: resolution, refundAmount: refundAmount);
    _ref.invalidate(adminDisputesProvider);
    _ref.invalidate(adminAnalyticsProvider);
  }

  Future<void> refundOrder(
    String orderId, {
    required double amount,
    String? reason,
  }) async {
    await _svc.refundOrder(orderId, amount: amount, reason: reason);
    _ref.invalidate(adminAnalyticsProvider);
  }
}
