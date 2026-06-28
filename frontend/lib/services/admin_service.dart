import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/api_endpoints.dart';
import '../features/admin/domain/baker_summary.dart';
import '../features/admin/domain/platform_stats.dart';
import '../features/disputes/domain/dispute.dart';
import 'api_client.dart';

/// Provides the [AdminService].
final adminServiceProvider = Provider<AdminService>((ref) {
  return AdminService(ref.read(apiClientProvider));
});

/// Admin-scoped API calls: baker approval, dispute resolution, refunds, and
/// platform analytics (all behind the admin role on the backend).
class AdminService {
  AdminService(this._api);

  final ApiClient _api;

  Future<List<BakerSummary>> pendingBakers() async {
    final response =
        await _api.get<Map<String, dynamic>>(ApiEndpoints.adminBakersPending);
    final items = (response.data?['bakers'] ?? const []) as List;
    return items
        .map((e) => BakerSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> approveBaker(String id) =>
      _api.post<void>(ApiEndpoints.adminBakerApprove(id));

  Future<List<Dispute>> disputes({String status = 'open'}) async {
    final response = await _api.get<Map<String, dynamic>>(
      ApiEndpoints.adminDisputes,
      queryParameters: {'status': status},
    );
    final items = (response.data?['disputes'] ?? const []) as List;
    return items
        .map((e) => Dispute.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> resolveDispute(
    String id, {
    required String resolution,
    double refundAmount = 0,
  }) =>
      _api.post<void>(
        ApiEndpoints.adminDisputeResolve(id),
        data: {'resolution': resolution, 'refund_amount': refundAmount},
      );

  Future<void> refundOrder(
    String orderId, {
    required double amount,
    String? reason,
  }) =>
      _api.post<void>(
        ApiEndpoints.adminOrderRefund(orderId),
        data: {
          'amount': amount,
          if (reason != null && reason.isNotEmpty) 'reason': reason,
        },
      );

  Future<PlatformStats> analytics() async {
    final response =
        await _api.get<Map<String, dynamic>>(ApiEndpoints.analyticsOverview);
    return PlatformStats.fromJson(response.data ?? const {});
  }
}
