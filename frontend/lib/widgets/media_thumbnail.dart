import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// A square image thumbnail that opens a full-screen, zoomable viewer on tap.
/// Falls back to a placeholder icon when the URL is missing or fails to load
/// (e.g. the dev stub storage, which serves no real bytes).
class MediaThumbnail extends StatelessWidget {
  const MediaThumbnail({super.key, required this.url, this.size = 72});

  final String? url;
  final double size;

  bool get _hasUrl => url != null && url!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget placeholder() => Container(
          width: size,
          height: size,
          color: theme.colorScheme.surfaceContainerHighest,
          alignment: Alignment.center,
          child: Icon(Icons.image_outlined,
              color: theme.colorScheme.onSurfaceVariant),
        );

    return GestureDetector(
      onTap: _hasUrl ? () => _open(context, url!) : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: _hasUrl
            ? CachedNetworkImage(
                imageUrl: url!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                placeholder: (_, __) => placeholder(),
                errorWidget: (_, __, ___) => placeholder(),
              )
            : placeholder(),
      ),
    );
  }

  static void _open(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (_) => _FullScreenImage(url: url),
    );
  }
}

class _FullScreenImage extends StatelessWidget {
  const _FullScreenImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.contain,
                  placeholder: (_, __) =>
                      const Center(child: CircularProgressIndicator()),
                  errorWidget: (_, __, ___) => const Center(
                    child: Icon(Icons.broken_image_outlined,
                        color: Colors.white54, size: 64),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: SafeArea(
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
