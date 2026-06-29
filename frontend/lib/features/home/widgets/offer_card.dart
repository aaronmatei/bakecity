import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../widgets/network_photo.dart';
import '../../../widgets/press_scale.dart';
import '../domain/offer.dart';

/// A full-bleed promo card for the offers carousel: image (or warm gradient),
/// a bottom scrim for legibility, a discount badge and short copy. [parallax]
/// (−1..1, the page's scroll offset) nudges the background for depth.
class OfferCard extends StatelessWidget {
  const OfferCard({
    super.key,
    required this.offer,
    required this.index,
    this.parallax = 0,
    this.onTap,
  });

  final Offer offer;
  final int index;
  final double parallax;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final bake = context.bake;
    final hasImage = offer.imageUrl != null && offer.imageUrl!.isNotEmpty;

    return PressScale(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.cardLg),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background: image with parallax, or a warm brand gradient.
            if (hasImage)
              Transform.translate(
                offset: Offset(parallax * 28, 0),
                child: NetworkPhoto(
                  url: offer.imageUrl,
                  radius: 0,
                  fit: BoxFit.cover,
                ),
              )
            else
              DecoratedBox(
                decoration: BoxDecoration(gradient: offerGradient(index, cs)),
              ),
            // Scrim for text legibility.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, bake.scrim],
                  stops: const [0.45, 1],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Insets.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: Insets.md, vertical: 6),
                    decoration: BoxDecoration(
                      color: bake.berry,
                      borderRadius: BorderRadius.circular(Radii.chip),
                    ),
                    child: Text(
                      offer.badge,
                      style: context.tt.labelLarge?.copyWith(
                        color: bake.onBerry,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        offer.title,
                        style: context.tt.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: Insets.xs),
                      Text(
                        offer.subtitle,
                        style: context.tt.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
