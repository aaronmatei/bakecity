import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../routes/app_routes.dart';
import '../../../widgets/network_photo.dart';
import '../../../widgets/press_scale.dart';
import '../../../widgets/rating_pill.dart';
import '../../bakers/domain/baker_profile.dart';

/// Premium baker card: cover photo with a circular logo, name + verified tick,
/// rating pill and distance.
class BakerCard extends StatelessWidget {
  const BakerCard({super.key, required this.baker, this.width = 264});

  final BakerProfile baker;
  final double width;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return PressScale(
      onTap: () => context.pushNamed(
        AppRoutes.bakerStorefrontName,
        pathParameters: {'bakerId': baker.id},
      ),
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                NetworkPhoto(
                  url: baker.coverImageUrl,
                  height: 120,
                  width: width,
                  fallbackIcon: Icons.storefront_outlined,
                ),
                Positioned(
                  left: Insets.md,
                  bottom: -18,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      shape: BoxShape.circle,
                    ),
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor: cs.secondaryContainer,
                      backgroundImage: (baker.avatarUrl != null &&
                              baker.avatarUrl!.isNotEmpty)
                          ? NetworkImage(baker.avatarUrl!)
                          : null,
                      child: (baker.avatarUrl == null ||
                              baker.avatarUrl!.isEmpty)
                          ? Icon(Icons.storefront,
                              color: cs.onSecondaryContainer, size: 22)
                          : null,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          baker.businessName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.tt.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (baker.isVerified) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.verified, size: 16, color: cs.primary),
                      ],
                    ],
                  ),
                  const SizedBox(height: Insets.sm),
                  Row(
                    children: [
                      RatingPill(
                        rating: baker.rating,
                        reviewCount: baker.reviewCount,
                      ),
                      if (baker.distanceKm != null) ...[
                        const SizedBox(width: Insets.sm),
                        Icon(Icons.place_outlined,
                            size: 14, color: cs.onSurfaceVariant),
                        const SizedBox(width: 2),
                        Text(
                          '${baker.distanceKm!.toStringAsFixed(1)} km',
                          style: context.tt.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
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
