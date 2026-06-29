import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../widgets/press_scale.dart';
import '../../products/domain/product.dart';

/// A category pill with small imagery. The fill animates to the accent when
/// selected.
class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final Category category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final fg = selected ? cs.onPrimary : cs.onSurface;
    return PressScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.fast,
        curve: Motion.curve,
        padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
        decoration: BoxDecoration(
          color: selected ? cs.primary : cs.surface,
          borderRadius: BorderRadius.circular(40),
          border: Border.all(
            color: selected ? cs.primary : cs.outlineVariant,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: selected
                  ? cs.onPrimary.withValues(alpha: 0.2)
                  : cs.surfaceContainerHighest,
              backgroundImage:
                  (category.iconUrl != null && category.iconUrl!.isNotEmpty)
                      ? NetworkImage(category.iconUrl!)
                      : null,
              child: (category.iconUrl == null || category.iconUrl!.isEmpty)
                  ? Icon(Icons.cake_outlined, size: 16, color: fg)
                  : null,
            ),
            const SizedBox(width: Insets.sm),
            Text(
              category.name,
              style: context.tt.labelLarge?.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
