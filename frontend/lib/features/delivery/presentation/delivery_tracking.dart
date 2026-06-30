import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/helpers/formatters.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../widgets/info_note.dart';
import '../../../widgets/media_thumbnail.dart';
import '../../orders/domain/order.dart';
import '../domain/delivery.dart';

/// Customer-facing live tracking for an order's delivery: a map-style ETA
/// banner, a four-step progress timeline and a courier card. Everything is
/// derived from the real order status + delivery timestamps — no fabricated
/// data. The ETA is an estimate from the dispatch time and is labelled as such.
class DeliveryTracking extends StatelessWidget {
  const DeliveryTracking({
    super.key,
    required this.delivery,
    required this.status,
    required this.order,
    required this.isCustomer,
    this.proofUrl,
  });

  final Delivery? delivery;
  final OrderStatus? status;
  final Order? order;
  final bool isCustomer;
  final String? proofUrl;

  /// Typical door-to-door window used to estimate arrival from dispatch time.
  static const _deliveryWindow = Duration(minutes: 40);

  bool get _isPickup =>
      order?.isPickup == true || delivery?.method == 'pickup';

  /// 0 = not confirmed … 5 = delivered. Linearised happy path so terminal
  /// states (disputed/cancelled) don't accidentally light up every step.
  int get _rank {
    if (delivery?.isDelivered == true) return 5;
    if (delivery?.isDispatched == true) return 4;
    return switch (status) {
      OrderStatus.depositPaid => 1,
      OrderStatus.inProduction => 2,
      OrderStatus.ready => 3,
      OrderStatus.dispatched => 4,
      OrderStatus.delivered || OrderStatus.completed => 5,
      _ => 0,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (status == OrderStatus.cancelled) {
      return const InfoNote(
        icon: Icons.cancel_outlined,
        text: 'This order was cancelled — there\'s nothing out for delivery.',
      );
    }

    final rank = _rank;
    final outForDelivery = rank == 4 && !_isPickup;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (outForDelivery) ...[
          _MapBanner(dispatchedAt: delivery?.dispatchedAt),
          const SizedBox(height: Insets.lg),
        ],
        _TimelineCard(rank: rank, delivery: delivery, isPickup: _isPickup),
        if (rank >= 4 && rank < 5) ...[
          const SizedBox(height: Insets.lg),
          _CourierCard(
            delivery: delivery,
            order: order,
            isCustomer: isCustomer,
            isPickup: _isPickup,
          ),
        ],
        if (proofUrl != null) ...[
          const SizedBox(height: Insets.lg),
          _ProofCard(url: proofUrl!),
        ],
      ],
    );
  }
}

/// A lightweight map-style banner with a dotted route and an estimated-arrival
/// overlay. Not a real map (that needs a keyed tiles provider) — a tasteful
/// placeholder that surfaces the ETA prominently while out for delivery.
class _MapBanner extends StatelessWidget {
  const _MapBanner({this.dispatchedAt});

  final DateTime? dispatchedAt;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final eta = dispatchedAt?.add(DeliveryTracking._deliveryWindow);
    final remaining = eta?.difference(DateTime.now());
    final minutes = remaining?.inMinutes;
    final countdown = (minutes != null && minutes >= 1)
        ? '~$minutes min'
        : 'Arriving soon';
    final byLine = eta != null ? 'Estimated arrival by ${Formatters.clockTime(eta)}' : null;

    return ClipRRect(
      borderRadius: Radii.cardBorder,
      child: Container(
        height: 156,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cs.primaryContainer.withValues(alpha: 0.55),
              cs.surfaceContainerHighest,
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _RoutePainter(cs.primary)),
            ),
            // Origin (bakery) and destination (you) pins.
            Positioned(
              left: 28,
              top: 36,
              child: _MapPin(icon: Icons.storefront, color: cs.primary),
            ),
            Positioned(
              right: 30,
              bottom: 40,
              child: _MapPin(icon: Icons.home_rounded, color: context.bake.berry),
            ),
            Positioned(
              left: Insets.lg,
              bottom: Insets.lg,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: Insets.md, vertical: Insets.sm),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: Radii.chipBorder,
                  boxShadow: context.bake.cardShadow,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('🚴', style: context.tt.titleMedium),
                    const SizedBox(width: Insets.sm),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Arriving $countdown',
                            style: context.tt.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        if (byLine != null)
                          Text(byLine,
                              style: context.tt.bodySmall
                                  ?.copyWith(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Insets.sm),
      decoration: BoxDecoration(
        color: context.cs.surface,
        shape: BoxShape.circle,
        boxShadow: context.bake.cardShadow,
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }
}

/// Dotted diagonal route line connecting the two pins.
class _RoutePainter extends CustomPainter {
  _RoutePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    const start = Offset(46, 54);
    final end = Offset(size.width - 48, size.height - 58);
    final control = Offset(size.width * 0.5, size.height * 0.2);
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
    // Dashed stroke.
    final metrics = path.computeMetrics().first;
    const dash = 9.0, gap = 7.0;
    double d = 0;
    while (d < metrics.length) {
      canvas.drawPath(
        metrics.extractPath(d, (d + dash).clamp(0, metrics.length)),
        paint,
      );
      d += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _RoutePainter old) => old.color != color;
}

/// Four-step vertical progress timeline.
class _TimelineCard extends StatelessWidget {
  const _TimelineCard({
    required this.rank,
    required this.delivery,
    required this.isPickup,
  });

  final int rank;
  final Delivery? delivery;
  final bool isPickup;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final steps = <(String, String, DateTime?)>[
      ('Order confirmed', 'Your bakery accepted the order', null),
      ('Freshly baked & packed', 'Made to order and boxed up', null),
      (
        isPickup ? 'Ready for pickup' : 'Out for delivery',
        isPickup
            ? 'Collect it from the bakery'
            : 'On the way to your address',
        delivery?.dispatchedAt,
      ),
      (
        isPickup ? 'Picked up' : 'Delivered',
        'Enjoy your treats!',
        delivery?.deliveredAt ?? delivery?.confirmedAt,
      ),
    ];

    // First not-yet-complete step is the active one.
    final completed = [rank >= 1, rank >= 3, rank >= 5, rank >= 5];
    final activeIndex = completed.indexWhere((c) => !c);

    return Container(
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: Radii.cardBorder,
        boxShadow: context.bake.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < steps.length; i++)
            _TimelineRow(
              title: steps[i].$1,
              subtitle: steps[i].$2,
              timestamp: steps[i].$3,
              done: completed[i],
              active: i == activeIndex,
              isFirst: i == 0,
              isLast: i == steps.length - 1,
            ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.title,
    required this.subtitle,
    required this.timestamp,
    required this.done,
    required this.active,
    required this.isFirst,
    required this.isLast,
  });

  final String title;
  final String subtitle;
  final DateTime? timestamp;
  final bool done;
  final bool active;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final success = context.bake.success;
    final reached = done || active;
    final nodeColor = done
        ? success
        : active
            ? cs.primary
            : cs.outlineVariant;
    final lineAbove = done || active ? success : cs.outlineVariant;
    final lineBelow = done ? success : cs.outlineVariant;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rail: connector lines + node.
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    width: 2,
                    color: isFirst ? Colors.transparent : lineAbove,
                  ),
                ),
                _Node(color: nodeColor, done: done, active: active),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast ? Colors.transparent : lineBelow,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: Insets.lg, top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: context.tt.titleSmall?.copyWith(
                            fontWeight:
                                active ? FontWeight.w700 : FontWeight.w600,
                            color: reached ? cs.onSurface : cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (timestamp != null)
                        Text(Formatters.clockTime(timestamp!),
                            style: context.tt.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: context.tt.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Node extends StatelessWidget {
  const _Node({required this.color, required this.done, required this.active});
  final Color color;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: done ? color : context.cs.surface,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
        boxShadow: active
            ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8)]
            : null,
      ),
      child: done
          ? Icon(Icons.check, size: 14, color: context.cs.onPrimary)
          : active
              ? Center(
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                )
              : null,
    );
  }
}

/// Who's bringing the order — own delivery / courier / pickup — plus a quick
/// "Message" action that jumps to the order's Chat tab.
class _CourierCard extends StatelessWidget {
  const _CourierCard({
    required this.delivery,
    required this.order,
    required this.isCustomer,
    required this.isPickup,
  });

  final Delivery? delivery;
  final Order? order;
  final bool isCustomer;
  final bool isPickup;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final method = delivery?.method ?? order?.fulfillmentType ?? 'own';
    final counterparty =
        (isCustomer ? order?.bakerName : order?.customerName)?.trim();
    final ref = delivery?.courierRef?.trim();

    final (IconData icon, String title, String subtitle) = isPickup
        ? (
            Icons.storefront_outlined,
            'Pickup from the bakery',
            counterparty == null || counterparty.isEmpty
                ? 'Collect your order in person'
                : 'Collect from $counterparty',
          )
        : method == 'courier'
            ? (
                Icons.two_wheeler_outlined,
                'Out with a courier',
                ref != null && ref.isNotEmpty
                    ? 'Tracking ref · $ref'
                    : 'On the way to you',
              )
            : (
                Icons.delivery_dining_outlined,
                counterparty == null || counterparty.isEmpty
                    ? 'The bakery is delivering'
                    : '$counterparty is delivering',
                'Bringing it to your door',
              );

    return Container(
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: Radii.cardBorder,
        boxShadow: context.bake.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: cs.primary),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: context.tt.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                Text(subtitle,
                    style: context.tt.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Message',
            onPressed: () => DefaultTabController.maybeOf(context)?.animateTo(1),
            icon: const Icon(Icons.chat_bubble_outline, size: 20),
          ),
        ],
      ),
    );
  }
}

class _ProofCard extends StatelessWidget {
  const _ProofCard({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Container(
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: Radii.cardBorder,
        boxShadow: context.bake.cardShadow,
      ),
      child: Row(
        children: [
          MediaThumbnail(url: url, size: 64),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Proof of delivery',
                    style: context.tt.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                Text('Photo taken at drop-off',
                    style: context.tt.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
