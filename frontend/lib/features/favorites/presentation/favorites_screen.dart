import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../widgets/app_error_view.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading_indicator.dart';
import '../../home/widgets/product_card.dart';
import '../application/favorites_controller.dart';

/// The saved-treats grid, backed by the user's server-synced wishlist.
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(favoriteProductsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
      body: products.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => AppErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(favoriteProductsProvider),
        ),
        data: (saved) {
          if (saved.isEmpty) {
            return const EmptyState(
              icon: Icons.favorite_border_rounded,
              title: 'No favorites yet',
              message: 'Tap the heart on any treat to save it here.',
            );
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth =
                  (constraints.maxWidth - Insets.screenH * 2 - Insets.lg) / 2;
              return SingleChildScrollView(
                padding: const EdgeInsets.all(Insets.screenH),
                child: Wrap(
                  spacing: Insets.lg,
                  runSpacing: Insets.xl,
                  children: [
                    for (final p in saved)
                      ProductCard(product: p, width: itemWidth),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
