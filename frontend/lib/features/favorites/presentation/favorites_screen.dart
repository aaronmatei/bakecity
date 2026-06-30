import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../routes/app_routes.dart';
import '../../../widgets/app_error_view.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading_indicator.dart';
import '../../../widgets/press_scale.dart';
import '../../bakers/domain/my_baker_profile.dart';
import '../../home/widgets/product_card.dart';
import '../application/favorites_controller.dart';

/// Saved treats and bakeries, backed by the user's server-synced wishlists.
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Favorites'),
          bottom: const TabBar(
            tabs: [Tab(text: 'Treats'), Tab(text: 'Bakeries')],
          ),
        ),
        body: const TabBarView(children: [_TreatsTab(), _BakeriesTab()]),
      ),
    );
  }
}

class _TreatsTab extends ConsumerWidget {
  const _TreatsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(favoriteProductsProvider);
    return products.when(
      loading: () => const LoadingIndicator(),
      error: (e, _) => AppErrorView(
        message: e.toString(),
        onRetry: () => ref.invalidate(favoriteProductsProvider),
      ),
      data: (saved) {
        if (saved.isEmpty) {
          return const EmptyState(
            icon: Icons.favorite_border_rounded,
            title: 'No saved treats yet',
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
    );
  }
}

class _BakeriesTab extends ConsumerWidget {
  const _BakeriesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bakers = ref.watch(favoriteBakerProfilesProvider);
    return bakers.when(
      loading: () => const LoadingIndicator(),
      error: (e, _) => AppErrorView(
        message: e.toString(),
        onRetry: () => ref.invalidate(favoriteBakerProfilesProvider),
      ),
      data: (saved) {
        if (saved.isEmpty) {
          return const EmptyState(
            icon: Icons.storefront_outlined,
            title: 'No saved bakeries yet',
            message: 'Tap the heart on a bakery to follow it here.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(Insets.screenH),
          itemCount: saved.length,
          separatorBuilder: (_, __) => const SizedBox(height: Insets.md),
          itemBuilder: (context, i) => _BakerTile(baker: saved[i]),
        );
      },
    );
  }
}

class _BakerTile extends ConsumerWidget {
  const _BakerTile({required this.baker});
  final MyBakerProfile baker;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = context.cs;
    return PressScale(
      onTap: () => context.pushNamed(
        AppRoutes.bakerStorefrontName,
        pathParameters: {'bakerId': baker.id},
      ),
      child: Container(
        padding: const EdgeInsets.all(Insets.md),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: Radii.cardBorder,
          boxShadow: context.bake.cardShadow,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: cs.primary.withValues(alpha: 0.12),
              child: Icon(Icons.storefront, color: cs.primary),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(baker.businessName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.tt.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  if (baker.bio.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(baker.bio,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.tt.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: 'Remove',
              icon: Icon(Icons.favorite, color: cs.primary),
              onPressed: () => ref
                  .read(favoriteBakersProvider.notifier)
                  .toggle(baker.id),
            ),
          ],
        ),
      ),
    );
  }
}
