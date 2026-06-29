import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/helpers/formatters.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../widgets/media_thumbnail.dart';
import '../../media/domain/order_media.dart';
import '../domain/production_update.dart';

/// The canonical stages a custom bake moves through. Bakers post free-form
/// stage strings; [classifyStage] maps each to one of these so the customer
/// sees a consistent, animated journey.
enum BakeStage { ingredients, preparation, baking, decoration, packaging, ready }

extension BakeStageUi on BakeStage {
  String get label => switch (this) {
        BakeStage.ingredients => 'Ingredients',
        BakeStage.preparation => 'Preparation',
        BakeStage.baking => 'Baking',
        BakeStage.decoration => 'Decoration',
        BakeStage.packaging => 'Packaging',
        BakeStage.ready => 'Ready',
      };

  IconData get icon => switch (this) {
        BakeStage.ingredients => Icons.shopping_basket_outlined,
        BakeStage.preparation => Icons.blender_outlined,
        BakeStage.baking => Icons.local_fire_department_outlined,
        BakeStage.decoration => Icons.brush_outlined,
        BakeStage.packaging => Icons.inventory_2_outlined,
        BakeStage.ready => Icons.check_circle_outline,
      };

  /// A representative completion percentage for this stage, used so the progress
  /// ring still advances when a baker posts a stage name without moving the
  /// percentage slider (the common case).
  int get baselinePct => switch (this) {
        BakeStage.ingredients => 10,
        BakeStage.preparation => 30,
        BakeStage.baking => 55,
        BakeStage.decoration => 75,
        BakeStage.packaging => 90,
        BakeStage.ready => 100,
      };
}

/// Classifies a free-form baker stage string, falling back to progress %.
BakeStage classifyStage(String raw, int pct) {
  final s = raw.toLowerCase();
  bool has(List<String> ks) => ks.any(s.contains);
  if (has(['ready', 'done', 'complete', 'finish'])) return BakeStage.ready;
  if (has(['pack', 'box', 'wrap'])) return BakeStage.packaging;
  if (has(['decor', 'ice', 'icing', 'frost', 'pip', 'fondant', 'garnish'])) {
    return BakeStage.decoration;
  }
  if (has(['bak', 'oven', 'cook', 'roast'])) return BakeStage.baking;
  if (has(['prep', 'mix', 'batter', 'dough', 'whisk', 'knead'])) {
    return BakeStage.preparation;
  }
  if (has(['ingredient', 'purchas', 'shop', 'buy', 'source'])) {
    return BakeStage.ingredients;
  }
  // Fall back to progress buckets.
  if (pct >= 100) return BakeStage.ready;
  if (pct >= 80) return BakeStage.packaging;
  if (pct >= 55) return BakeStage.decoration;
  if (pct >= 30) return BakeStage.baking;
  if (pct >= 10) return BakeStage.preparation;
  return BakeStage.ingredients;
}

enum _NodeState { completed, current, future }

/// The signature production tracker: an animated overall-progress ring above a
/// vertical timeline of stages whose nodes light up, draw checkmarks and fill
/// their connectors as work progresses. The current stage expands with a live
/// media carousel.
class ProductionTimeline extends StatelessWidget {
  const ProductionTimeline({
    super.key,
    required this.updates,
    required this.status,
    required this.productionMedia,
  });

  final List<ProductionUpdate> updates;
  final OrderStatus? status;
  final List<OrderMedia> productionMedia;

  bool get _complete =>
      status == OrderStatus.ready ||
      status == OrderStatus.dispatched ||
      status == OrderStatus.delivered ||
      status == OrderStatus.completed;

  @override
  Widget build(BuildContext context) {
    final sorted = [...updates]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final latest = sorted.isNotEmpty ? sorted.last : null;
    final started = sorted.isNotEmpty || status == OrderStatus.inProduction;

    final current = _complete
        ? BakeStage.ready
        : (latest != null
            ? classifyStage(latest.stage, latest.progressPct)
            : BakeStage.ingredients);

    // Reaching the terminal "Ready" stage counts as complete for display, even
    // if the order status hasn't advanced yet — so it never reads "Ready · live".
    final complete = _complete || (started && current == BakeStage.ready);

    // The ring reflects the explicit progress %, but never less than the
    // current stage's baseline — so a baker who posts "Decoration" without
    // touching the slider still shows meaningful progress instead of 0%.
    final pct = complete
        ? 100
        : (started
            ? math.max(latest?.progressPct ?? 0, current.baselinePct)
            : 0);
    final currentIndex = current.index;

    // Latest update mapped to each stage, for completed-stage timestamps.
    final byStage = <BakeStage, ProductionUpdate>{};
    for (final u in sorted) {
      byStage[classifyStage(u.stage, u.progressPct)] = u;
    }

    const stages = BakeStage.values;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProgressHeader(
          pct: pct,
          label: complete
              ? 'All done · Ready for delivery'
              : started
                  ? '$pct% · ${current.label} in progress'
                  : 'Waiting for the baker to begin',
        ),
        const SizedBox(height: Insets.xl),
        for (int i = 0; i < stages.length; i++)
          _StageRow(
            stage: stages[i],
            state: _stateFor(i, currentIndex, started, complete),
            update: byStage[stages[i]],
            isLast: i == stages.length - 1,
            // Live media only on the active stage.
            media: (_stateFor(i, currentIndex, started, complete) ==
                        _NodeState.current &&
                    !complete)
                ? productionMedia
                : const [],
          ),
      ],
    );
  }

  _NodeState _stateFor(int i, int currentIndex, bool started, bool complete) {
    if (complete) return _NodeState.completed;
    if (!started) return i == 0 ? _NodeState.current : _NodeState.future;
    if (i < currentIndex) return _NodeState.completed;
    if (i == currentIndex) return _NodeState.current;
    return _NodeState.future;
  }
}

// ---------------------------------------------------------------------------
// Progress ring
// ---------------------------------------------------------------------------

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.pct, required this.label});
  final int pct;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Row(
      children: [
        SizedBox(
          width: 92,
          height: 92,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: pct / 100),
            duration: context.reduceMotion ? Duration.zero : Motion.slow,
            curve: Motion.curve,
            builder: (context, value, _) => CustomPaint(
              painter: _RingPainter(
                value: value,
                track: cs.outlineVariant,
                fill: cs.primary,
              ),
              child: Center(
                child: Text(
                  '${(value * 100).round()}%',
                  style: context.tt.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: Insets.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your order', style: context.tt.labelMedium
                  ?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 2),
              Text(label, style: context.tt.titleMedium),
            ],
          ),
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.value, required this.track, required this.fill});
  final double value;
  final Color track;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 9.0;
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.shortestSide - stroke) / 2;
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    final fillPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = fill;
    canvas.drawCircle(center, radius, trackPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * value.clamp(0.0, 1.0),
      false,
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.fill != fill || old.track != track;
}

// ---------------------------------------------------------------------------
// Stage row (node + connector + card)
// ---------------------------------------------------------------------------

class _StageRow extends StatelessWidget {
  const _StageRow({
    required this.stage,
    required this.state,
    required this.update,
    required this.isLast,
    required this.media,
  });

  final BakeStage stage;
  final _NodeState state;
  final ProductionUpdate? update;
  final bool isLast;
  final List<OrderMedia> media;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              _Node(stage: stage, state: state),
              if (!isLast)
                Expanded(child: _Connector(filled: state == _NodeState.completed)),
            ],
          ),
          const SizedBox(width: Insets.lg),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : Insets.xl),
              child: _StageCard(
                stage: stage,
                state: state,
                update: update,
                media: media,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Node extends StatelessWidget {
  const _Node({required this.stage, required this.state});
  final BakeStage stage;
  final _NodeState state;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    const size = 40.0;
    switch (state) {
      case _NodeState.completed:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
          child: _AnimatedCheck(color: cs.onPrimary),
        );
      case _NodeState.current:
        return _PulsingNode(
          size: size,
          child: Container(
            width: size,
            height: size,
            decoration:
                BoxDecoration(color: cs.primary, shape: BoxShape.circle),
            child: Icon(stage.icon, size: 20, color: cs.onPrimary),
          ),
        );
      case _NodeState.future:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: cs.surface,
            shape: BoxShape.circle,
            border: Border.all(color: cs.outlineVariant, width: 2),
          ),
          child: Icon(stage.icon, size: 18, color: cs.onSurfaceVariant),
        );
    }
  }
}

/// A pulsing halo behind the active node.
class _PulsingNode extends StatefulWidget {
  const _PulsingNode({required this.child, required this.size});
  final Widget child;
  final double size;

  @override
  State<_PulsingNode> createState() => _PulsingNodeState();
}

class _PulsingNodeState extends State<_PulsingNode>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (context.reduceMotion) return widget.child;
    final cs = context.cs;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final t = _c.value;
              return Container(
                width: widget.size * (1 + t * 0.7),
                height: widget.size * (1 + t * 0.7),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cs.primary.withValues(alpha: (1 - t) * 0.28),
                ),
              );
            },
          ),
          widget.child,
        ],
      ),
    );
  }
}

/// Draws a checkmark from 0→1 the first time it appears.
class _AnimatedCheck extends StatelessWidget {
  const _AnimatedCheck({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (context.reduceMotion) {
      return Icon(Icons.check_rounded, size: 22, color: color);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.base,
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => CustomPaint(
        painter: _CheckPainter(progress: t, color: color),
        size: const Size(40, 40),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final a = Offset(size.width * 0.30, size.height * 0.52);
    final b = Offset(size.width * 0.44, size.height * 0.66);
    final c = Offset(size.width * 0.72, size.height * 0.36);
    // First half draws a→b, second half b→c.
    final path = Path()..moveTo(a.dx, a.dy);
    if (progress <= 0.5) {
      final t = progress / 0.5;
      path.lineTo(a.dx + (b.dx - a.dx) * t, a.dy + (b.dy - a.dy) * t);
    } else {
      path.lineTo(b.dx, b.dy);
      final t = (progress - 0.5) / 0.5;
      path.lineTo(b.dx + (c.dx - b.dx) * t, b.dy + (c.dy - b.dy) * t);
    }
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.progress != progress;
}

/// The vertical connector that fills downward as the stage above completes.
class _Connector extends StatelessWidget {
  const _Connector({required this.filled});
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return SizedBox(
      width: 3,
      child: Stack(
        children: [
          Container(color: cs.outlineVariant),
          Positioned.fill(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: filled ? 1 : 0),
              duration: context.reduceMotion ? Duration.zero : Motion.slow,
              curve: Motion.curve,
              builder: (context, t, _) => Align(
                alignment: Alignment.topCenter,
                child: FractionallySizedBox(
                  heightFactor: t,
                  child: Container(color: cs.primary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StageCard extends StatelessWidget {
  const _StageCard({
    required this.stage,
    required this.state,
    required this.update,
    required this.media,
  });

  final BakeStage stage;
  final _NodeState state;
  final ProductionUpdate? update;
  final List<OrderMedia> media;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final isCurrent = state == _NodeState.current;
    final muted = state == _NodeState.future;

    final title = Text(
      stage.label,
      style: context.tt.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: muted ? cs.onSurfaceVariant : cs.onSurface,
      ),
    );

    final subtitle = switch (state) {
      _NodeState.completed => Text(
          update != null
              ? 'Done · ${Formatters.relativeTime(update!.createdAt)}'
              : 'Done',
          style: context.tt.bodySmall
              ?.copyWith(color: context.bake.success),
        ),
      _NodeState.current => _InProgressLabel(
          note: update?.notes,
        ),
      _NodeState.future => Text(
          'Up next',
          style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
    };

    final card = Container(
      padding: EdgeInsets.all(isCurrent ? Insets.lg : Insets.md),
      decoration: BoxDecoration(
        color: isCurrent ? cs.surface : Colors.transparent,
        borderRadius: Radii.cardBorder,
        border: isCurrent ? Border.all(color: cs.outlineVariant) : null,
        boxShadow: isCurrent ? context.bake.cardShadow : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: title),
              if (isCurrent) const _LiveBadge(),
            ],
          ),
          const SizedBox(height: 2),
          subtitle,
          if (isCurrent && media.isNotEmpty) ...[
            const SizedBox(height: Insets.md),
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: media.length,
                separatorBuilder: (_, __) => const SizedBox(width: Insets.sm),
                itemBuilder: (context, i) =>
                    MediaThumbnail(url: media[i].displayUrl, size: 96),
              ),
            ),
          ],
        ],
      ),
    );

    // Slight top alignment so the card centres against its node.
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: card,
    );
  }
}

class _InProgressLabel extends StatelessWidget {
  const _InProgressLabel({this.note});
  final String? note;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final text = (note != null && note!.isNotEmpty) ? note! : 'In progress…';
    final label = Text(
      text,
      style: context.tt.bodySmall?.copyWith(color: cs.primary),
    );
    if (context.reduceMotion) return label;
    return label
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .fadeIn(duration: const Duration(milliseconds: 900));
  }
}

/// A small pulsing "live" badge for the active stage.
class _LiveBadge extends StatefulWidget {
  const _LiveBadge();

  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bake = context.bake;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bake.berry.withValues(alpha: 0.12),
        borderRadius: Radii.chipBorder,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (context.reduceMotion)
            Icon(Icons.circle, size: 8, color: bake.berry)
          else
            FadeTransition(
              opacity: _c,
              child: Icon(Icons.circle, size: 8, color: bake.berry),
            ),
          const SizedBox(width: 5),
          Text(
            'Live',
            style: context.tt.labelSmall?.copyWith(
              color: bake.berry,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
