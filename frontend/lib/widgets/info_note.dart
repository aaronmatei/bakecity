import 'package:flutter/material.dart';

import '../core/theme/app_tokens.dart';

/// A soft informational note (icon + text) used across the order tabs for
/// contextual status messages — token-styled for a consistent look.
class InfoNote extends StatelessWidget {
  const InfoNote({super.key, required this.icon, required this.text, this.tone});

  final IconData icon;
  final String text;

  /// Optional accent colour for the icon (e.g. success). Defaults to muted.
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Container(
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: Radii.cardBorder,
      ),
      child: Row(
        children: [
          Icon(icon, color: tone ?? cs.onSurfaceVariant),
          const SizedBox(width: Insets.md),
          Expanded(child: Text(text, style: context.tt.bodyMedium)),
        ],
      ),
    );
  }
}
