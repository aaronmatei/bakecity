import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_tokens.dart';
import 'skeletons.dart';

/// The app's image primitive. Images are the hero of BakeCity, so this always
/// reserves a fixed box (no layout shift on load), shows a shimmer placeholder,
/// fades the real image in, and falls back to an art-directed gradient tile
/// when there's no URL or it fails. Rounds corners to match cards.
class NetworkPhoto extends StatelessWidget {
  const NetworkPhoto({
    super.key,
    required this.url,
    this.aspectRatio,
    this.height,
    this.width,
    this.radius = Radii.card,
    this.fit = BoxFit.cover,
    this.fallbackIcon = Icons.bakery_dining_outlined,
  });

  final String? url;
  final double? aspectRatio;
  final double? height;
  final double? width;
  final double radius;
  final BoxFit fit;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final hasUrl = url != null && url!.isNotEmpty;
    Widget image = hasUrl
        ? CachedNetworkImage(
            imageUrl: url!,
            fit: fit,
            width: width,
            height: height,
            fadeInDuration: Motion.base,
            placeholder: (_, __) => ShimmerBox(radius: radius),
            errorWidget: (_, __, ___) => _fallback(context),
          )
        : _fallback(context);

    if (aspectRatio != null) {
      image = AspectRatio(aspectRatio: aspectRatio!, child: image);
    } else if (height != null || width != null) {
      image = SizedBox(width: width, height: height, child: image);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: image,
    );
  }

  /// A soft warm-gradient tile with a muted bakery glyph — reads as intentional,
  /// never as a broken image.
  Widget _fallback(BuildContext context) {
    final cs = context.cs;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primary.withValues(alpha: 0.18),
            cs.secondary.withValues(alpha: 0.12),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          fallbackIcon,
          size: 34,
          color: cs.onSurfaceVariant.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}
