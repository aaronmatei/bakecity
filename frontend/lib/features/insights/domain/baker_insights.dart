/// One product's sales performance for a baker.
class ProductPerf {
  const ProductPerf({
    required this.productId,
    required this.title,
    required this.orderCount,
    required this.revenueCents,
  });

  final String productId;
  final String title;
  final int orderCount;
  final int revenueCents;

  factory ProductPerf.fromJson(Map<String, dynamic> json) => ProductPerf(
        productId: json['product_id']?.toString() ?? '',
        title: (json['title']?.toString().isNotEmpty ?? false)
            ? json['title'].toString()
            : 'Custom order',
        orderCount: (json['order_count'] as num?)?.toInt() ?? 0,
        revenueCents:
            (((json['revenue'] as num?)?.toDouble() ?? 0) * 100).round(),
      );
}

/// The signed-in baker's order-book summary (GET /orders/insights).
class BakerInsights {
  const BakerInsights({
    required this.statusCounts,
    required this.completedOrders,
    required this.grossRevenueCents,
    required this.netRevenueCents,
    required this.topProducts,
    this.followerCount = 0,
    this.revenueTrendCents = const [],
    this.revenueTrendPeriods = const [],
  });

  final Map<String, int> statusCounts;
  final int completedOrders;
  final int grossRevenueCents;
  final int netRevenueCents;
  final int followerCount;
  final List<ProductPerf> topProducts;

  /// Net revenue per month (cents), oldest → newest, for the trend sparkline.
  final List<int> revenueTrendCents;

  /// The "YYYY-MM" period for each trend point, parallel to [revenueTrendCents].
  final List<String> revenueTrendPeriods;

  /// Net revenue per completed order (cents).
  int get avgOrderValueCents =>
      completedOrders > 0 ? (netRevenueCents / completedOrders).round() : 0;

  factory BakerInsights.fromJson(Map<String, dynamic> json) {
    final counts = <String, int>{};
    (json['status_counts'] as Map?)?.forEach((k, v) {
      counts[k.toString()] = (v as num).toInt();
    });
    return BakerInsights(
      statusCounts: counts,
      completedOrders: (json['completed_orders'] as num?)?.toInt() ?? 0,
      grossRevenueCents:
          (((json['gross_revenue'] as num?)?.toDouble() ?? 0) * 100).round(),
      netRevenueCents:
          (((json['net_revenue'] as num?)?.toDouble() ?? 0) * 100).round(),
      followerCount: (json['follower_count'] as num?)?.toInt() ?? 0,
      topProducts: ((json['top_products'] as List?) ?? const [])
          .map((e) => ProductPerf.fromJson(e as Map<String, dynamic>))
          .toList(),
      revenueTrendCents: ((json['revenue_trend'] as List?) ?? const [])
          .map((e) =>
              (((e['revenue'] as num?)?.toDouble() ?? 0) * 100).round())
          .toList(),
      revenueTrendPeriods: ((json['revenue_trend'] as List?) ?? const [])
          .map((e) => (e['period'] ?? '').toString())
          .toList(),
    );
  }

  int get totalOrders => statusCounts.values.fold(0, (a, b) => a + b);

  /// Sum of counts across the given statuses.
  int countFor(Iterable<String> statuses) =>
      statuses.fold(0, (a, s) => a + (statusCounts[s] ?? 0));
}
