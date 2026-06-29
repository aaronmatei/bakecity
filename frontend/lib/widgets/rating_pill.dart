import 'package:flutter/material.dart';

import '../core/theme/app_tokens.dart';

/// A compact star + rating pill. On a surface by default; pass [onImage] for a
/// translucent dark pill that stays legible over photography.
class RatingPill extends StatelessWidget {
  const RatingPill({
    super.key,
    required this.rating,
    this.reviewCount,
    this.onImage = false,
  });

  final double rating;
  final int? reviewCount;
  final bool onImage;

  @override
  Widget build(BuildContext context) {
    final bake = context.bake;
    final isNew = rating <= 0;
    final fg = onImage ? Colors.white : context.cs.onSurface;
    final bg = onImage
        ? Colors.black.withValues(alpha: 0.42)
        : context.cs.surfaceContainerHighest;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Radii.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 14, color: bake.star),
          const SizedBox(width: 3),
          Text(
            isNew ? 'New' : rating.toStringAsFixed(1),
            style: context.tt.labelMedium?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (!isNew && reviewCount != null && reviewCount! > 0) ...[
            const SizedBox(width: 3),
            Text(
              '($reviewCount)',
              style: context.tt.labelSmall?.copyWith(
                color: fg.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
