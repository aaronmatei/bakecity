import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/helpers/formatters.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../routes/app_routes.dart';
import '../../../widgets/favorite_heart.dart';
import '../../../widgets/network_photo.dart';
import '../../../widgets/press_scale.dart';
import '../../products/domain/product.dart';

/// Shared hero tag so a card image flies into the detail screen's header.
String productHeroTag(String productId) => 'product-image-$productId';

/// Premium product card: large rounded hero image, floating favorite heart,
/// optional rank badge / "New" tag / discount, then name + price. Fixed width
/// so rails stay rhythmic and images never layout-shift.
class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    this.width = 170,
    this.rank,
    this.isNew = false,
    this.discountPct,
  });

  final Product product;
  final double width;
  final int? rank;
  final bool isNew;
  final int? discountPct;

  @override
  Widget build(BuildContext context) {
    final image = product.imageUrls.isNotEmpty ? product.imageUrls.first : null;
    final soldOut = !product.isAvailable;
    return PressScale(
      onTap: () => context.pushNamed(
        AppRoutes.productDetailName,
        pathParameters: {'productId': product.id},
      ),
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Hero(
                  tag: productHeroTag(product.id),
                  child: NetworkPhoto(url: image, aspectRatio: 4 / 3),
                ),
                // Sold-out scrim + badge dims the whole image.
                if (soldOut)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: Radii.cardBorder,
                      child: Container(
                        color: context.cs.surface.withValues(alpha: 0.62),
                        alignment: Alignment.center,
                        child: const _SoldOutBadge(),
                      ),
                    ),
                  ),
                Positioned(
                  top: Insets.sm,
                  right: Insets.sm,
                  child: FavoriteHeart(productId: product.id),
                ),
                if (rank != null)
                  Positioned(top: Insets.sm, left: Insets.sm, child: _Rank(rank!))
                else if (isNew && !soldOut)
                  const Positioned(
                      top: Insets.sm, left: Insets.sm, child: _Tag('New')),
                if (discountPct != null && !soldOut)
                  Positioned(
                    bottom: Insets.sm,
                    left: Insets.sm,
                    child: _Discount(discountPct!),
                  ),
              ],
            ),
            const SizedBox(height: Insets.md),
            Text(
              product.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              _secondaryLabel(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.tt.bodySmall
                  ?.copyWith(color: context.cs.onSurfaceVariant),
            ),
            const SizedBox(height: Insets.sm),
            _PriceRow(cents: product.basePriceCents, discountPct: discountPct),
          ],
        ),
      ),
    );
  }

  /// Prefer an appetising description; fall back to the lead-time label. Kept to
  /// one line so card height (and the home rails) stay constant.
  String _secondaryLabel() {
    final desc = product.description?.trim();
    if (desc != null && desc.isNotEmpty) return desc;
    return _leadLabel(product.leadTimeDays);
  }

  static String _leadLabel(int days) =>
      days <= 1 ? 'Ready next day' : 'Ready in $days days';
}

class _SoldOutBadge extends StatelessWidget {
  const _SoldOutBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: context.cs.surface,
        borderRadius: BorderRadius.circular(Radii.chip),
        boxShadow: context.bake.cardShadow,
      ),
      child: Text(
        'Sold out',
        style: context.tt.labelMedium?.copyWith(
          fontWeight: FontWeight.w800,
          color: context.cs.onSurface,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.cents, this.discountPct});
  final int cents;
  final int? discountPct;

  @override
  Widget build(BuildContext context) {
    if (discountPct == null) {
      return Text(
        Formatters.currencyFromCents(cents),
        style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      );
    }
    final discounted = (cents * (100 - discountPct!) / 100).round();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          Formatters.currencyFromCents(discounted),
          style: context.tt.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: context.bake.berry,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          Formatters.currencyFromCents(cents),
          style: context.tt.bodySmall?.copyWith(
            color: context.cs.onSurfaceVariant,
            decoration: TextDecoration.lineThrough,
          ),
        ),
      ],
    );
  }
}

class _Rank extends StatelessWidget {
  const _Rank(this.rank);
  final int rank;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.cs.primary,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$rank',
        style: context.tt.labelMedium?.copyWith(
          color: context.cs.onPrimary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: context.cs.primary,
        borderRadius: BorderRadius.circular(Radii.chip),
      ),
      child: Text(
        label,
        style: context.tt.labelSmall?.copyWith(
          color: context.cs.onPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Discount extends StatelessWidget {
  const _Discount(this.pct);
  final int pct;

  @override
  Widget build(BuildContext context) {
    final bake = context.bake;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bake.berry,
        borderRadius: BorderRadius.circular(Radii.chip),
      ),
      child: Text(
        '-$pct%',
        style: context.tt.labelSmall?.copyWith(
          color: bake.onBerry,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
