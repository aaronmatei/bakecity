import 'package:flutter/material.dart';

import '../core/theme/app_tokens.dart';

/// A home-feed rail: a display-type section header (with an optional "See all →"
/// affordance) above a lazily-built horizontal list of cards.
class RailSection extends StatelessWidget {
  const RailSection({
    super.key,
    required this.title,
    required this.height,
    required this.itemCount,
    required this.itemBuilder,
    this.onSeeAll,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final double height;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              Insets.screenH, 0, Insets.sm, Insets.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.tt.titleLarge),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitle!,
                          style: context.tt.bodySmall?.copyWith(
                            color: context.cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (onSeeAll != null)
                TextButton(
                  onPressed: onSeeAll,
                  style: TextButton.styleFrom(
                    foregroundColor: context.cs.primary,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('See all  →'),
                ),
            ],
          ),
        ),
        SizedBox(
          height: height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Insets.screenH),
            itemCount: itemCount,
            clipBehavior: Clip.none,
            separatorBuilder: (_, __) => const SizedBox(width: Insets.lg),
            itemBuilder: itemBuilder,
          ),
        ),
      ],
    );
  }
}
