import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_tokens.dart';
import '../features/favorites/application/favorites_controller.dart';

/// A floating favorite heart that fills + bounces with haptic feedback on tap.
/// Sits on a translucent white pill so it stays legible over any image.
class FavoriteHeart extends ConsumerWidget {
  const FavoriteHeart({super.key, required this.productId, this.size = 20});

  final String productId;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFav = ref.watch(favoritesProvider).contains(productId);
    final bake = context.bake;

    final icon = Icon(
      isFav ? Icons.favorite : Icons.favorite_border,
      size: size,
      color: isFav ? bake.berry : Colors.white,
    );

    return Semantics(
      button: true,
      label: isFav ? 'Remove from favorites' : 'Add to favorites',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          ref.read(favoritesProvider.notifier).toggle(productId);
        },
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.28),
            shape: BoxShape.circle,
          ),
          // Re-key on state so the bounce replays each toggle.
          child: context.reduceMotion
              ? icon
              : icon
                  .animate(key: ValueKey(isFav))
                  .scale(
                    begin: const Offset(0.6, 0.6),
                    end: const Offset(1, 1),
                    duration: Motion.base,
                    curve: Curves.easeOutBack,
                  ),
        ),
      ),
    );
  }
}
