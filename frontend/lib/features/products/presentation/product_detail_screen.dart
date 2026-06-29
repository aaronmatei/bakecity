import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/helpers/formatters.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../routes/app_routes.dart';
import '../../../widgets/app_error_view.dart';
import '../../../widgets/favorite_heart.dart';
import '../../../widgets/loading_indicator.dart';
import '../../../widgets/network_photo.dart';
import '../../../widgets/press_scale.dart';
import '../../../widgets/rating_pill.dart';
import '../../bakers/application/baker_storefront_controller.dart';
import '../../home/widgets/product_card.dart' show productHeroTag;
import '../application/products_controller.dart';
import '../domain/product.dart';

/// The chosen size id per product (null = the cheapest/default size).
final _selectedSizeProvider =
    StateProvider.autoDispose.family<String?, String>((_, __) => null);

/// The effective price (cents) for the product at the chosen size, applying any
/// offer discount.
int _priceForSelection(Product p, String? sizeId) {
  var cents = p.basePriceCents;
  if (p.sizes.isNotEmpty) {
    final s = p.sizes.firstWhere((x) => x.id == sizeId,
        orElse: () => p.sizes.first);
    cents = s.priceCents;
  }
  if (p.isOnOffer && p.discountPct != null) {
    return (cents * (100 - p.discountPct!) / 100).round();
  }
  return cents;
}

/// Product detail: a full-bleed hero image under a collapsing app bar, a
/// rounded content sheet that slides up over it, and a sticky bottom CTA.
class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = ref.watch(productDetailProvider(productId));
    return Scaffold(
      body: product.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => Scaffold(
          appBar: AppBar(),
          body: AppErrorView(
            message: e.toString(),
            onRetry: () => ref.invalidate(productDetailProvider(productId)),
          ),
        ),
        data: (p) => _Detail(product: p),
      ),
      bottomNavigationBar: product.maybeWhen(
        data: (p) => _CtaBar(product: p),
        orElse: () => null,
      ),
    );
  }
}

class _Detail extends ConsumerWidget {
  const _Detail({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = context.cs;
    final image =
        product.imageUrls.isNotEmpty ? product.imageUrls.first : null;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          stretch: true,
          expandedHeight: 360,
          backgroundColor: cs.surface,
          surfaceTintColor: Colors.transparent,
          leading: const _CircleButton(icon: Icons.arrow_back, back: true),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: Insets.sm),
              child: Center(child: FavoriteHeart(productId: product.id, size: 22)),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            collapseMode: CollapseMode.parallax,
            stretchModes: const [StretchMode.zoomBackground],
            background: Hero(
              tag: productHeroTag(product.id),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  NetworkPhoto(url: image, radius: 0, fit: BoxFit.cover),
                  // Top scrim so the back/favorite buttons stay legible.
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.center,
                        colors: [Color(0x66000000), Colors.transparent],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Transform.translate(
            offset: const Offset(0, -Radii.sheet),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(Radii.sheet)),
              ),
              padding: const EdgeInsets.fromLTRB(
                  Insets.screenH, Insets.xl, Insets.screenH, Insets.xxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, style: context.tt.headlineSmall),
                  const SizedBox(height: Insets.sm),
                  Row(
                    children: [
                      Text(
                        'From ${Formatters.currencyFromCents(product.basePriceCents)}',
                        style: context.tt.titleMedium?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      _Pill(
                        icon: Icons.schedule_outlined,
                        label: product.leadTimeDays <= 1
                            ? 'Ready next day'
                            : 'Ready in ${product.leadTimeDays} days',
                      ),
                    ],
                  ),
                  if (product.ratingAvg > 0 || product.dietary.isNotEmpty) ...[
                    const SizedBox(height: Insets.md),
                    Wrap(
                      spacing: Insets.sm,
                      runSpacing: Insets.sm,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (product.ratingAvg > 0)
                          RatingPill(
                              rating: product.ratingAvg,
                              reviewCount: product.ratingCount),
                        for (final d in product.dietary) _DietChip(label: d),
                      ],
                    ),
                  ],
                  if (product.sizes.isNotEmpty) ...[
                    const SizedBox(height: Insets.xl),
                    Text('Choose a size', style: context.tt.titleLarge),
                    const SizedBox(height: Insets.md),
                    _SizePicker(product: product),
                  ],
                  const SizedBox(height: Insets.xl),
                  _BakerRow(bakerId: product.bakerId),
                  const SizedBox(height: Insets.xl),
                  if (product.description != null &&
                      product.description!.isNotEmpty) ...[
                    Text('About this treat', style: context.tt.titleLarge),
                    const SizedBox(height: Insets.md),
                    Text(
                      product.description!,
                      style: context.tt.bodyLarge?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: Insets.xl),
                  ],
                  if (product.isCustomizable) ...[
                    Text('Make it yours', style: context.tt.titleLarge),
                    const SizedBox(height: Insets.md),
                    const _CustomiseHint(),
                    const SizedBox(height: Insets.xl),
                  ],
                  PressScale(
                    onTap: () => context.pushNamed(
                      AppRoutes.bakerReviewsName,
                      pathParameters: {'bakerId': product.bakerId},
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
                            child: Text('Read baker reviews',
                                style: context.tt.titleSmall),
                          ),
                          Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The baker identity row, loaded by id. Tappable to the storefront.
class _BakerRow extends ConsumerWidget {
  const _BakerRow({required this.bakerId});
  final String bakerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = context.cs;
    final baker = ref.watch(bakerProfileProvider(bakerId)).valueOrNull;
    return PressScale(
      onTap: () => context.pushNamed(
        AppRoutes.bakerStorefrontName,
        pathParameters: {'bakerId': bakerId},
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: cs.secondaryContainer,
            child: Icon(Icons.storefront, color: cs.onSecondaryContainer),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  baker?.businessName ?? 'View bakery',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.tt.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  'Tap to view the bakery',
                  style: context.tt.bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
        ],
      ),
    );
  }
}

class _CustomiseHint extends StatelessWidget {
  const _CustomiseHint();

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    const options = [
      ('Flavour', Icons.icecream_outlined),
      ('Size & tiers', Icons.layers_outlined),
      ('Message', Icons.edit_outlined),
      ('Date', Icons.event_outlined),
    ];
    return Wrap(
      spacing: Insets.sm,
      runSpacing: Insets.sm,
      children: [
        for (final (label, icon) in options)
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: Insets.md, vertical: Insets.sm),
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
          ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: Insets.md, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: Radii.chipBorder,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: cs.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(label, style: context.tt.labelMedium),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, this.back = false});
  final IconData icon;
  final bool back;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Insets.sm),
      child: Material(
        color: Colors.black.withValues(alpha: 0.3),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: back ? () => Navigator.of(context).maybePop() : null,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}

/// Sticky bottom bar with the size-aware price and the primary order CTA.
class _CtaBar extends ConsumerWidget {
  const _CtaBar({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = context.cs;
    final sizeId = ref.watch(_selectedSizeProvider(product.id));
    final price = _priceForSelection(product, sizeId);
    final label = product.sizes.isNotEmpty
        ? product.sizes
            .firstWhere((s) => s.id == sizeId, orElse: () => product.sizes.first)
            .label
        : (product.isOnOffer ? 'Offer price' : 'From');
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        boxShadow: context.bake.cardShadow,
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(
            Insets.screenH, Insets.md, Insets.screenH, Insets.md),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    style: context.tt.labelSmall
                        ?.copyWith(color: cs.onSurfaceVariant)),
                Text(
                  Formatters.currencyFromCents(price),
                  style: context.tt.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(width: Insets.lg),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => context.pushNamed(
                  AppRoutes.productOrderRequestName,
                  pathParameters: {'productId': product.id},
                  queryParameters: {
                    if (product.sizes.isNotEmpty) 'size': label,
                  },
                ),
                icon: const Icon(Icons.add_shopping_cart_outlined),
                label: Text(product.isCustomizable && product.sizes.isEmpty
                    ? 'Request quote'
                    : 'Request order'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Selectable weight/serving chips that drive the displayed price.
class _SizePicker extends ConsumerWidget {
  const _SizePicker({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = context.cs;
    final selected =
        ref.watch(_selectedSizeProvider(product.id)) ?? product.sizes.first.id;
    return Wrap(
      spacing: Insets.sm,
      runSpacing: Insets.sm,
      children: [
        for (final s in product.sizes)
          PressScale(
            onTap: () => ref
                .read(_selectedSizeProvider(product.id).notifier)
                .state = s.id,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: Insets.md, vertical: Insets.sm),
              decoration: BoxDecoration(
                color: s.id == selected ? cs.primary : cs.surface,
                borderRadius: Radii.chipBorder,
                border: Border.all(
                    color: s.id == selected ? cs.primary : cs.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.label,
                      style: context.tt.labelLarge?.copyWith(
                          color: s.id == selected ? cs.onPrimary : cs.onSurface,
                          fontWeight: FontWeight.w700)),
                  Text(
                    '${s.serves != null ? 'Serves ${s.serves} · ' : ''}'
                    '${Formatters.currencyFromCents(s.priceCents)}',
                    style: context.tt.bodySmall?.copyWith(
                        color: s.id == selected
                            ? cs.onPrimary.withValues(alpha: 0.9)
                            : cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// A dietary tag chip (e.g. "eggless", "gluten free").
class _DietChip extends StatelessWidget {
  const _DietChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: 4),
      decoration: BoxDecoration(
        color: context.bake.success.withValues(alpha: 0.12),
        borderRadius: Radii.chipBorder,
      ),
      child: Text(label.replaceAll('_', ' '),
          style: context.tt.labelSmall?.copyWith(
              color: context.bake.success, fontWeight: FontWeight.w700)),
    );
  }
}
