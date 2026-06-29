import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../core/theme/app_tokens.dart';

/// A single shimmering placeholder block, themed to the warm palette.
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    this.width,
    this.height,
    this.radius = Radii.chip,
    this.shape = BoxShape.rectangle,
  });

  final double? width;
  final double? height;
  final double radius;
  final BoxShape shape;

  @override
  Widget build(BuildContext context) {
    final bake = context.bake;
    return Shimmer.fromColors(
      baseColor: bake.shimmerBase,
      highlightColor: bake.shimmerHighlight,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: bake.shimmerBase,
          shape: shape,
          borderRadius:
              shape == BoxShape.circle ? null : BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// Skeleton matching the product card footprint, used while a rail loads.
class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key, this.width = 168});
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerBox(width: width, height: width * 0.75, radius: Radii.card),
          const SizedBox(height: Insets.md),
          const ShimmerBox(width: 120, height: 12),
          const SizedBox(height: Insets.sm),
          const ShimmerBox(width: 80, height: 10),
        ],
      ),
    );
  }
}

/// Skeleton matching the baker card footprint.
class BakerCardSkeleton extends StatelessWidget {
  const BakerCardSkeleton({super.key, this.width = 260});
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerBox(width: width, height: 120, radius: Radii.card),
          const SizedBox(height: Insets.md),
          const ShimmerBox(width: 140, height: 12),
          const SizedBox(height: Insets.sm),
          const ShimmerBox(width: 90, height: 10),
        ],
      ),
    );
  }
}

/// A horizontal strip of skeletons, shown while a whole rail loads.
class RailSkeleton extends StatelessWidget {
  const RailSkeleton({
    super.key,
    required this.height,
    this.itemBuilder,
    this.count = 4,
  });

  final double height;
  final IndexedWidgetBuilder? itemBuilder;
  final int count;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: Insets.screenH),
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(width: Insets.lg),
        itemBuilder: itemBuilder ?? (_, __) => const ProductCardSkeleton(),
      ),
    );
  }
}
