import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/upload_service.dart';
import '../../../widgets/app_error_view.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading_indicator.dart';
import '../../../widgets/media_thumbnail.dart';
import '../application/media_controller.dart';
import '../domain/order_media.dart';

/// A gallery of every photo attached to an order, grouped by kind: the
/// customer's reference photos, the baker's progress photos and the delivery
/// proof. Tapping any thumbnail opens it full-screen. Visible to both parties.
class OrderGalleryView extends ConsumerWidget {
  const OrderGalleryView({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaAsync = ref.watch(orderMediaProvider(orderId));
    return mediaAsync.when(
      loading: () => const LoadingIndicator(),
      error: (e, _) => AppErrorView(
        message: e.toString(),
        onRetry: () => ref.invalidate(orderMediaProvider(orderId)),
      ),
      data: (media) {
        final references =
            media.where((m) => m.kind == MediaKind.reference).toList();
        final production =
            media.where((m) => m.kind == MediaKind.production).toList();
        final proof =
            media.where((m) => m.kind == MediaKind.deliveryProof).toList();

        if (media.isEmpty) {
          return const EmptyState(
            icon: Icons.photo_library_outlined,
            message: 'No photos yet. Reference photos you attach and the '
                'baker\'s progress shots will appear here.',
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(orderMediaProvider(orderId)),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _GallerySection(
                title: 'Reference photos',
                subtitle: 'Shared by the customer',
                items: references,
              ),
              _GallerySection(
                title: 'Progress photos',
                subtitle: 'Posted by the baker during production',
                items: production,
              ),
              _GallerySection(
                title: 'Delivery proof',
                subtitle: 'Captured on delivery',
                items: proof,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A titled grid of thumbnails. Renders nothing when [items] is empty so empty
/// groups don't clutter the gallery.
class _GallerySection extends StatelessWidget {
  const _GallerySection({
    required this.title,
    required this.subtitle,
    required this.items,
  });

  final String title;
  final String subtitle;
  final List<OrderMedia> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        Text(subtitle,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in items)
              MediaThumbnail(url: m.displayUrl, size: 104),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
