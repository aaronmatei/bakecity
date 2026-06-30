import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../routes/app_routes.dart';
import '../../../widgets/app_error_view.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading_indicator.dart';
import '../../../widgets/press_scale.dart';
import '../../favorites/application/favorites_controller.dart';
import '../../home/widgets/category_chip.dart';
import '../../home/widgets/product_card.dart';
import '../../products/application/products_controller.dart';
import '../../products/domain/product.dart';
import '../application/baker_storefront_controller.dart';
import '../domain/my_baker_profile.dart';

const _storefrontSorts = [
  ('top_rated', 'Top rated'),
  ('price_asc', 'Price: low to high'),
  ('price_desc', 'Price: high to low'),
  ('newest', 'Newest'),
];

/// A baker's public storefront: a cover header with key stats, then their
/// catalog as a premium grid leading into the custom-order flow.
class BakerStorefrontScreen extends ConsumerWidget {
  const BakerStorefrontScreen({super.key, required this.bakerId});

  final String bakerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(bakerProfileProvider(bakerId));

    return Scaffold(
      body: profile.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => Scaffold(
          appBar: AppBar(),
          body: AppErrorView(
            message: e is AppException ? e.message : e.toString(),
            onRetry: () => ref.invalidate(bakerProfileProvider(bakerId)),
          ),
        ),
        data: (baker) => RefreshIndicator(
          color: context.cs.primary,
          onRefresh: () async {
            ref.invalidate(bakerProfileProvider(bakerId));
            ref.invalidate(productSearchProvider);
          },
          child: CustomScrollView(
            slivers: [
              _CoverBar(baker: baker),
              SliverToBoxAdapter(child: _StoreInfo(baker: baker, bakerId: bakerId)),
              SliverToBoxAdapter(child: _Menu(bakerId: bakerId)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoverBar extends ConsumerWidget {
  const _CoverBar({required this.baker});
  final MyBakerProfile baker;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = context.cs;
    final saved = ref.watch(favoriteBakersProvider).contains(baker.id);
    return SliverAppBar(
      pinned: true,
      expandedHeight: 176,
      backgroundColor: cs.surface,
      surfaceTintColor: Colors.transparent,
      foregroundColor: Colors.white,
      actions: [
        IconButton(
          tooltip: saved ? 'Saved' : 'Save bakery',
          icon: Icon(saved ? Icons.favorite : Icons.favorite_border,
              color: Colors.white),
          onPressed: () =>
              ref.read(favoriteBakersProvider.notifier).toggle(baker.id),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 56, bottom: 14, right: 16),
        title: Text(
          baker.businessName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [cs.primary, cs.secondary],
                ),
              ),
            ),
            const Center(
              child: Icon(Icons.storefront, size: 56, color: Colors.white30),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, context.bake.scrim],
                  stops: const [0.5, 1],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreInfo extends StatelessWidget {
  const _StoreInfo({required this.baker, required this.bakerId});
  final MyBakerProfile baker;
  final String bakerId;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          Insets.screenH, Insets.lg, Insets.screenH, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (baker.isApproved)
            Row(
              children: [
                Icon(Icons.verified, size: 18, color: cs.primary),
                const SizedBox(width: 6),
                Text('Verified bakery',
                    style: context.tt.labelLarge?.copyWith(
                        color: cs.primary, fontWeight: FontWeight.w700)),
              ],
            ),
          if (baker.bio.isNotEmpty) ...[
            const SizedBox(height: Insets.md),
            Text(
              baker.bio,
              style: context.tt.bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant, height: 1.5),
            ),
          ],
          const SizedBox(height: Insets.lg),
          Wrap(
            spacing: Insets.sm,
            runSpacing: Insets.sm,
            children: [
              _InfoChip(
                icon: Icons.schedule_outlined,
                label: '${baker.leadTimeDays}-day lead time',
              ),
              _InfoChip(
                icon: Icons.delivery_dining_outlined,
                label: 'Delivers ~${baker.deliveryRadiusKm.toStringAsFixed(0)} km',
              ),
              _InfoChip(
                icon: Icons.bakery_dining_outlined,
                label: 'Up to ${baker.dailyCapacity}/day',
              ),
            ],
          ),
          const SizedBox(height: Insets.lg),
          PressScale(
            onTap: () => context.pushNamed(
              AppRoutes.bakerReviewsName,
              pathParameters: {'bakerId': bakerId},
            ),
            child: Container(
              padding: const EdgeInsets.all(Insets.lg),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: Radii.cardBorder,
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Row(
                children: [
                  Icon(Icons.star_rounded, color: context.bake.star),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: Text('Ratings & reviews',
                        style: context.tt.titleSmall),
                  ),
                  Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
                ],
              ),
            ),
          ),
          const SizedBox(height: Insets.xl),
          Text('Menu', style: context.tt.titleLarge),
          const SizedBox(height: Insets.md),
        ],
      ),
    );
  }
}

class _Menu extends ConsumerStatefulWidget {
  const _Menu({required this.bakerId});
  final String bakerId;

  @override
  ConsumerState<_Menu> createState() => _MenuState();
}

class _MenuState extends ConsumerState<_Menu> {
  String? _categoryId; // null = all
  String _sort = 'top_rated';

  @override
  Widget build(BuildContext context) {
    final filter =
        ProductFilter(bakerId: widget.bakerId, sort: _sort, limit: 100);
    final products = ref.watch(productSearchProvider(filter));
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];

    return products.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: LoadingIndicator(),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(Insets.screenH),
        child: AppErrorView(
          message: e is AppException ? e.message : e.toString(),
          onRetry: () => ref.invalidate(productSearchProvider(filter)),
        ),
      ),
      data: (all) {
        if (all.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: EmptyState(
              icon: Icons.cake_outlined,
              message: 'This bakery hasn\'t published any treats yet.',
            ),
          );
        }
        // Only the categories this baker actually stocks.
        final present = all
            .map((p) => p.categoryId)
            .whereType<String>()
            .where((s) => s.isNotEmpty)
            .toSet();
        final cats =
            categories.where((c) => present.contains(c.id)).toList();
        final shown = _categoryId == null
            ? all
            : all.where((p) => p.categoryId == _categoryId).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (cats.length > 1)
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: Insets.screenH),
                  itemCount: cats.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: Insets.sm),
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return CategoryChip(
                        category: const Category(id: '_all', name: 'All'),
                        selected: _categoryId == null,
                        onTap: () => setState(() => _categoryId = null),
                      );
                    }
                    final c = cats[i - 1];
                    return CategoryChip(
                      category: c,
                      selected: _categoryId == c.id,
                      onTap: () => setState(() =>
                          _categoryId = _categoryId == c.id ? null : c.id),
                    );
                  },
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Insets.screenH, Insets.sm, Insets.screenH, Insets.sm),
              child: Row(
                children: [
                  Text('${shown.length} treats',
                      style: context.tt.bodySmall
                          ?.copyWith(color: context.cs.onSurfaceVariant)),
                  const Spacer(),
                  _SortMenu(
                    sort: _sort,
                    onChanged: (v) => setState(() => _sort = v),
                  ),
                ],
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final w =
                    (constraints.maxWidth - Insets.screenH * 2 - Insets.lg) / 2;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(
                      Insets.screenH, 0, Insets.screenH, Insets.xxl),
                  child: Wrap(
                    spacing: Insets.lg,
                    runSpacing: Insets.xl,
                    children: [
                      for (final p in shown)
                        ProductCard(
                          product: p,
                          width: w,
                          discountPct: p.isOnOffer ? p.discountPct : null,
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _SortMenu extends StatelessWidget {
  const _SortMenu({required this.sort, required this.onChanged});
  final String sort;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final label = _storefrontSorts
        .firstWhere((s) => s.$1 == sort, orElse: () => _storefrontSorts.first)
        .$2;
    return PopupMenuButton<String>(
      onSelected: onChanged,
      itemBuilder: (_) => [
        for (final s in _storefrontSorts)
          PopupMenuItem(value: s.$1, child: Text(s.$2)),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.swap_vert, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(label, style: context.tt.labelLarge),
          Icon(Icons.arrow_drop_down, size: 18, color: cs.onSurfaceVariant),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: Radii.chipBorder,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(label, style: context.tt.labelLarge),
        ],
      ),
    );
  }
}
