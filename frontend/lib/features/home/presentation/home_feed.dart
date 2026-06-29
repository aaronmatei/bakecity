import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../routes/app_routes.dart';
import '../../../widgets/app_error_view.dart';
import '../../../widgets/press_scale.dart';
import '../../../widgets/rail_section.dart';
import '../../../widgets/skeletons.dart';
import '../../discovery/application/discovery_controller.dart';
import '../../notifications/application/notifications_controller.dart';
import '../../products/application/products_controller.dart';
import '../../products/domain/product.dart';
import '../domain/offer.dart';
import '../widgets/baker_card.dart';
import '../widgets/category_chip.dart';
import '../widgets/offer_card.dart';
import '../widgets/product_card.dart';

/// Home-screen category filter (local to the feed). Null = all.
final _selectedCategoryProvider = StateProvider.autoDispose<String?>((_) => null);

/// The image-forward customer home: a single sliver scroll view with a pinned
/// search header and a vertical stack of horizontally-scrolling rails.
class HomeFeed extends ConsumerWidget {
  const HomeFeed({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reduce = context.reduceMotion;

    // Body rails, revealed with a downward stagger on first paint.
    final rails = <Widget>[
      const _OffersCarousel(),
      const _CategoriesRail(),
      const _BakersRail(),
      const _ProductRail(title: 'Top rated', variant: _RailVariant.plain),
      const _ProductRail(title: 'Best sellers', variant: _RailVariant.ranked),
      const _ProductRail(title: 'New on BakeCity', variant: _RailVariant.fresh),
      const SizedBox(height: Insets.xxl),
    ];

    return RefreshIndicator(
      color: context.cs.primary,
      onRefresh: () async {
        ref.invalidate(nearbyBakersProvider);
        ref.invalidate(productsProvider(null));
      },
      child: CustomScrollView(
        slivers: [
          const _HomeAppBar(),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final child = Padding(
                  padding: EdgeInsets.only(
                    top: i == 0 ? Insets.lg : 0,
                    bottom: i == rails.length - 1 ? 0 : Insets.section,
                  ),
                  child: rails[i],
                );
                if (reduce) return child;
                return child
                    .animate()
                    .fadeIn(
                      delay: Duration(milliseconds: 40 * i),
                      duration: Motion.base,
                    )
                    .slideY(begin: 0.06, end: 0, curve: Motion.curve);
              },
              childCount: rails.length,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _HomeAppBar extends ConsumerWidget {
  const _HomeAppBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = context.cs;
    final unread = ref.watch(unreadNotificationsProvider).valueOrNull ?? 0;
    return SliverAppBar(
      pinned: true,
      floating: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleSpacing: Insets.screenH,
      toolbarHeight: 60,
      title: Row(
        children: [
          Expanded(
            child: PressScale(
              onTap: () => context.pushNamed(AppRoutes.discoveryName),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Deliver to',
                      style: context.tt.labelSmall
                          ?.copyWith(color: cs.onSurfaceVariant)),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Bakers near you',
                          style: context.tt.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      Icon(Icons.keyboard_arrow_down_rounded,
                          size: 20, color: cs.onSurface),
                    ],
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Notifications',
            icon: unread > 0
                ? Badge.count(
                    count: unread,
                    child: const Icon(Icons.notifications_outlined))
                : const Icon(Icons.notifications_outlined),
            onPressed: () => context.pushNamed(AppRoutes.notificationsName),
          ),
          PressScale(
            onTap: () => context.pushNamed(AppRoutes.profileName),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: cs.primaryContainer,
              child: Icon(Icons.person_outline,
                  size: 20, color: cs.onPrimaryContainer),
            ),
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              Insets.screenH, 0, Insets.screenH, Insets.md),
          child: Hero(
            tag: 'home-search-bar',
            child: Material(
              color: Colors.transparent,
              child: PressScale(
                onTap: () => context.pushNamed(AppRoutes.searchName),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded,
                          color: cs.onSurfaceVariant, size: 22),
                      const SizedBox(width: Insets.md),
                      Text('Search cakes, bakers, treats…',
                          style: context.tt.bodyMedium
                              ?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Offers carousel
// ---------------------------------------------------------------------------

class _OffersCarousel extends StatefulWidget {
  const _OffersCarousel();

  @override
  State<_OffersCarousel> createState() => _OffersCarouselState();
}

class _OffersCarouselState extends State<_OffersCarousel> {
  static const _height = 184.0;
  final _controller = PageController(viewportFraction: 0.9);
  double _page = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() => _page = _controller.page ?? 0));
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_controller.hasClients || curatedOffers.isEmpty) return;
      final next = ((_controller.page ?? 0).round() + 1) % curatedOffers.length;
      _controller.animateToPage(next,
          duration: Motion.slow, curve: Motion.curve);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: _height,
          child: PageView.builder(
            controller: _controller,
            itemCount: curatedOffers.length,
            itemBuilder: (context, i) {
              final delta = (_page - i).clamp(-1.0, 1.0);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: OfferCard(
                  offer: curatedOffers[i],
                  index: i,
                  parallax: delta,
                  onTap: () => context.pushNamed(AppRoutes.discoveryName),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: Insets.md),
        _Dots(count: curatedOffers.length, active: _page.round()),
      ],
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.active});
  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final on = i == active;
        return AnimatedContainer(
          duration: Motion.fast,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: on ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: on ? cs.primary : cs.outlineVariant,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// Categories
// ---------------------------------------------------------------------------

class _CategoriesRail extends ConsumerWidget {
  const _CategoriesRail();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    final selected = ref.watch(_selectedCategoryProvider);

    return categories.when(
      loading: () => const SizedBox(
        height: 56,
        child: RailSkeleton(
          height: 56,
          count: 5,
          itemBuilder: _chipSkeleton,
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: 56,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Insets.screenH),
            itemCount: items.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: Insets.sm),
            itemBuilder: (context, i) {
              if (i == 0) {
                return CategoryChip(
                  category: const Category(id: '_all', name: 'All'),
                  selected: selected == null,
                  onTap: () =>
                      ref.read(_selectedCategoryProvider.notifier).state = null,
                );
              }
              final c = items[i - 1];
              return CategoryChip(
                category: c,
                selected: selected == c.id,
                onTap: () => ref
                    .read(_selectedCategoryProvider.notifier)
                    .state = (selected == c.id ? null : c.id),
              );
            },
          ),
        );
      },
    );
  }

  static Widget _chipSkeleton(BuildContext context, int i) =>
      const ShimmerBox(width: 96, height: 44, radius: 40);
}

// ---------------------------------------------------------------------------
// Bakers rail
// ---------------------------------------------------------------------------

class _BakersRail extends ConsumerWidget {
  const _BakersRail();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bakers = ref.watch(nearbyBakersProvider);
    return bakers.when(
      loading: () => const _RailLoading(
        title: 'Top bakers near you',
        height: 196,
        skeleton: _bakerSkeleton,
      ),
      error: (e, _) => _RailError(
        title: 'Top bakers near you',
        onRetry: () => ref.invalidate(nearbyBakersProvider),
      ),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        final shown = items.take(10).toList();
        return RailSection(
          title: 'Top bakers near you',
          subtitle: 'Hand-picked, highly rated',
          height: 196,
          itemCount: shown.length,
          onSeeAll: () => context.pushNamed(AppRoutes.discoveryName),
          itemBuilder: (context, i) => BakerCard(baker: shown[i]),
        );
      },
    );
  }

  static Widget _bakerSkeleton(BuildContext context, int i) =>
      const BakerCardSkeleton();
}

// ---------------------------------------------------------------------------
// Product rails
// ---------------------------------------------------------------------------

enum _RailVariant { plain, ranked, fresh }

class _ProductRail extends ConsumerWidget {
  const _ProductRail({required this.title, required this.variant});

  final String title;
  final _RailVariant variant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productsProvider(null));
    final categoryId = ref.watch(_selectedCategoryProvider);

    return products.when(
      loading: () => _RailLoading(title: title, height: 230),
      error: (e, _) => _RailError(
        title: title,
        onRetry: () => ref.invalidate(productsProvider(null)),
      ),
      data: (all) {
        var list = categoryId == null
            ? all
            : all.where((p) => p.categoryId == categoryId).toList();
        // Derive each rail from the catalog (no dedicated endpoints yet):
        // "new" reverses to surface the most recently added.
        if (variant == _RailVariant.fresh) list = list.reversed.toList();
        list = list.take(10).toList();
        if (list.isEmpty) return const SizedBox.shrink();
        return RailSection(
          title: title,
          height: 230,
          itemCount: list.length,
          onSeeAll: () => context.pushNamed(AppRoutes.discoveryName),
          itemBuilder: (context, i) => ProductCard(
            product: list[i],
            rank: variant == _RailVariant.ranked ? i + 1 : null,
            isNew: variant == _RailVariant.fresh,
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Rail loading / error shells
// ---------------------------------------------------------------------------

class _RailLoading extends StatelessWidget {
  const _RailLoading({
    required this.title,
    required this.height,
    this.skeleton,
  });

  final String title;
  final double height;
  final IndexedWidgetBuilder? skeleton;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              Insets.screenH, 0, Insets.screenH, Insets.md),
          child: Text(title, style: context.tt.titleLarge),
        ),
        RailSkeleton(height: height - 44, itemBuilder: skeleton),
      ],
    );
  }
}

class _RailError extends StatelessWidget {
  const _RailError({required this.title, required this.onRetry});
  final String title;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.screenH),
      child: AppErrorView(message: 'Couldn\'t load $title.', onRetry: onRetry),
    );
  }
}
