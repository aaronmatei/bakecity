/// Aggregate platform analytics snapshot (GET /analytics/overview).
class PlatformStats {
  const PlatformStats({
    required this.totalOrders,
    required this.completedOrders,
    required this.gmv,
    required this.platformRevenue,
    required this.activeBakers,
    required this.openDisputes,
  });

  final int totalOrders;
  final int completedOrders;

  /// Gross merchandise value of completed orders (KES).
  final double gmv;

  /// Commission realized on completed orders (KES).
  final double platformRevenue;

  final int activeBakers;
  final int openDisputes;

  factory PlatformStats.fromJson(Map<String, dynamic> json) {
    return PlatformStats(
      totalOrders: (json['total_orders'] as num?)?.toInt() ?? 0,
      completedOrders: (json['completed_orders'] as num?)?.toInt() ?? 0,
      gmv: (json['gmv'] as num?)?.toDouble() ?? 0,
      platformRevenue: (json['platform_revenue'] as num?)?.toDouble() ?? 0,
      activeBakers: (json['active_bakers'] as num?)?.toInt() ?? 0,
      openDisputes: (json['open_disputes'] as num?)?.toInt() ?? 0,
    );
  }
}
