import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/helpers/formatters.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../routes/app_routes.dart';
import '../../../widgets/app_error_view.dart';
import '../../../widgets/dashboard_widgets.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading_indicator.dart';
import '../application/insights_controller.dart';
import '../domain/baker_insights.dart';

const _monthAbbr = [
  '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

/// "2026-06" → "Jun".
String _monthLabel(String period) {
  final parts = period.split('-');
  final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  return (m >= 1 && m <= 12) ? _monthAbbr[m] : '';
}

const _newStatuses = ['QUOTE_REQUESTED', 'NEGOTIATING', 'QUOTED'];
const _activeStatuses = [
  'APPROVED',
  'DEPOSIT_PAID',
  'IN_PRODUCTION',
  'READY',
  'DISPATCHED',
  'DELIVERED'
];

/// A baker's sales insights: revenue, order pipeline, and top products.
class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(bakerInsightsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: async.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => AppErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(bakerInsightsProvider),
        ),
        data: (d) {
          if (d.totalOrders == 0) {
            return const EmptyState(
              icon: Icons.insights_outlined,
              title: 'No orders yet',
              message:
                  'Once customers start ordering, your sales insights appear here.',
            );
          }
          return RefreshIndicator(
            color: context.cs.primary,
            onRefresh: () async => ref.invalidate(bakerInsightsProvider),
            child: ListView(
              padding: const EdgeInsets.all(Insets.screenH),
              children: [
                Row(
                  children: [
                    Icon(Icons.favorite, size: 16, color: context.cs.primary),
                    const SizedBox(width: 6),
                    Text(
                      '${d.followerCount} follower${d.followerCount == 1 ? '' : 's'}',
                      style: context.tt.labelLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: Insets.md),
                _RevenueCard(insights: d),
                const SizedBox(height: Insets.lg),
                Row(
                  children: [
                    DashStatTile(
                      value: '${d.countFor(_newStatuses)}',
                      label: 'New requests',
                      icon: Icons.request_quote_outlined,
                      color: const Color(0xFFEF6C00),
                      onTap: () => context.pushNamed(AppRoutes.ordersName),
                    ),
                    const SizedBox(width: Insets.md),
                    DashStatTile(
                      value: '${d.countFor(_activeStatuses)}',
                      label: 'In progress',
                      icon: Icons.bakery_dining_outlined,
                      color: const Color(0xFF5E35B1),
                      onTap: () => context.pushNamed(AppRoutes.ordersName),
                    ),
                    const SizedBox(width: Insets.md),
                    DashStatTile(
                      value: '${d.completedOrders}',
                      label: 'Completed',
                      icon: Icons.check_circle_outline,
                      color: const Color(0xFF2E7D32),
                      onTap: () => context.pushNamed(AppRoutes.ordersName),
                    ),
                  ],
                ),
                const SizedBox(height: Insets.xl),
                Text('Top products', style: context.tt.titleMedium),
                const SizedBox(height: Insets.sm),
                if (d.topProducts.isEmpty)
                  Text('No completed product orders yet.',
                      style: context.tt.bodyMedium
                          ?.copyWith(color: context.cs.onSurfaceVariant))
                else
                  ..._topProducts(context, d.topProducts),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _topProducts(BuildContext context, List<ProductPerf> products) {
    final maxRevenue = products
        .map((p) => p.revenueCents)
        .fold<int>(1, (a, b) => b > a ? b : a);
    return [
      for (var i = 0; i < products.length; i++)
        _ProductRow(
          rank: i + 1,
          product: products[i],
          fraction: products[i].revenueCents / maxRevenue,
        ),
    ];
  }
}

class _RevenueCard extends StatelessWidget {
  const _RevenueCard({required this.insights});
  final BakerInsights insights;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Insets.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.primary.withValues(alpha: 0.78)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: Radii.cardBorder,
        boxShadow: context.bake.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Net earnings',
              style: context.tt.labelLarge
                  ?.copyWith(color: cs.onPrimary.withValues(alpha: 0.9))),
          const SizedBox(height: Insets.xs),
          Text(
            Formatters.currencyFromCents(insights.netRevenueCents),
            style: context.tt.displaySmall?.copyWith(
                color: cs.onPrimary, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: Insets.sm),
          Text(
            'From ${insights.completedOrders} completed order'
            '${insights.completedOrders == 1 ? '' : 's'} · '
            '${Formatters.currencyFromCents(insights.grossRevenueCents)} gross',
            style: context.tt.bodyMedium
                ?.copyWith(color: cs.onPrimary.withValues(alpha: 0.9)),
          ),
          if (insights.completedOrders > 0)
            Text(
              'Avg ${Formatters.currencyFromCents(insights.avgOrderValueCents)} per order',
              style: context.tt.bodySmall
                  ?.copyWith(color: cs.onPrimary.withValues(alpha: 0.85)),
            ),
          if (insights.revenueTrendCents.where((v) => v > 0).isNotEmpty) ...[
            const SizedBox(height: Insets.lg),
            SizedBox(
              height: 44,
              width: double.infinity,
              child: CustomPaint(
                painter: _SparklinePainter(
                  values: insights.revenueTrendCents,
                  color: cs.onPrimary,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final p in insights.revenueTrendPeriods)
                  Text(_monthLabel(p),
                      style: context.tt.labelSmall?.copyWith(
                          color: cs.onPrimary.withValues(alpha: 0.7))),
              ],
            ),
            const SizedBox(height: Insets.xs),
            Text('Net revenue · last 6 months',
                style: context.tt.labelSmall
                    ?.copyWith(color: cs.onPrimary.withValues(alpha: 0.85))),
          ],
        ],
      ),
    );
  }
}

/// A minimal area sparkline over the monthly revenue values (baseline at zero).
class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.values, required this.color});
  final List<int> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final maxV = values.reduce((a, b) => a > b ? a : b).toDouble();
    final range = maxV <= 0 ? 1.0 : maxV;
    final dx = size.width / (values.length - 1);
    final points = <Offset>[
      for (var i = 0; i < values.length; i++)
        Offset(i * dx, size.height - (values[i] / range) * size.height),
    ];

    final fill = Path()..moveTo(points.first.dx, size.height);
    for (final p in points) {
      fill.lineTo(p.dx, p.dy);
    }
    fill
      ..lineTo(points.last.dx, size.height)
      ..close();
    canvas.drawPath(
        fill, Paint()..color = color.withValues(alpha: 0.18));

    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      line.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(points.last, 3, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) => old.values != values;
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.rank,
    required this.product,
    required this.fraction,
  });
  final int rank;
  final ProductPerf product;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('$rank.',
                  style: context.tt.bodyMedium
                      ?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: Text(product.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.tt.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ),
              Text(Formatters.currencyFromCents(product.revenueCents),
                  style: context.tt.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: fraction.clamp(0.04, 1.0),
                    minHeight: 6,
                    backgroundColor: cs.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(cs.primary),
                  ),
                ),
              ),
              const SizedBox(width: Insets.sm),
              Text(
                '${product.orderCount} order${product.orderCount == 1 ? '' : 's'}',
                style: context.tt.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
