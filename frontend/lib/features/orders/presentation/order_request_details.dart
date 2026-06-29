import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/helpers/formatters.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../services/upload_service.dart';
import '../../../widgets/media_thumbnail.dart';
import '../../../widgets/network_photo.dart';
import '../../media/application/media_controller.dart';
import '../../products/application/products_controller.dart';
import '../application/orders_controller.dart';

/// What the customer asked for — the requested product, event date, delivery
/// address, spec attributes (flavor, tiers, message…) and reference photos.
/// Shown at the top of the Quotes tab so the baker can price the order, and so
/// the customer can recall their request.
class OrderRequestDetails extends ConsumerWidget {
  const OrderRequestDetails({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = context.cs;
    final order = ref.watch(orderDetailProvider(orderId)).valueOrNull;
    final media = ref.watch(orderMediaProvider(orderId)).valueOrNull ?? const [];
    final refs = media.where((m) => m.kind == MediaKind.reference).toList();

    if (order == null) return const SizedBox.shrink();

    final hasDescription =
        order.description != null && order.description!.isNotEmpty;
    final hasAddress =
        order.deliveryAddress != null && order.deliveryAddress!.isNotEmpty;
    final anything = order.productId != null ||
        order.eventDate != null ||
        hasAddress ||
        hasDescription ||
        order.specs.isNotEmpty ||
        refs.isNotEmpty;
    if (!anything) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: Radii.cardBorder,
        boxShadow: context.bake.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long_outlined,
                  size: 18, color: cs.onSurfaceVariant),
              const SizedBox(width: Insets.sm),
              Text('Request details', style: context.tt.titleSmall),
            ],
          ),
          const SizedBox(height: Insets.md),
          if (order.productId != null)
            _ProductLine(productId: order.productId!),
          if (order.eventDate != null)
            _IconLine(
              icon: Icons.event_outlined,
              text: 'Needed by ${Formatters.eventDate(order.eventDate!)}',
            ),
          if (hasAddress)
            _IconLine(
              icon: Icons.place_outlined,
              text: order.deliveryAddress!,
            ),
          if (hasDescription) ...[
            const SizedBox(height: Insets.sm),
            Text(order.description!, style: context.tt.bodyMedium),
          ],
          if (order.specs.isNotEmpty) ...[
            const SizedBox(height: Insets.md),
            Divider(height: 1, color: cs.outlineVariant),
            const SizedBox(height: Insets.md),
            for (final s in order.specs)
              Padding(
                padding: const EdgeInsets.only(bottom: Insets.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 104,
                      child: Text(s.label,
                          style: context.tt.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant)),
                    ),
                    Expanded(
                      child: Text(s.value, style: context.tt.bodyMedium),
                    ),
                  ],
                ),
              ),
          ],
          if (refs.isNotEmpty) ...[
            const SizedBox(height: Insets.md),
            Text('Reference photos',
                style: context.tt.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: Insets.sm),
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: refs.length,
                separatorBuilder: (_, __) => const SizedBox(width: Insets.sm),
                itemBuilder: (context, i) =>
                    MediaThumbnail(url: refs[i].displayUrl, size: 72),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _IconLine extends StatelessWidget {
  const _IconLine({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: Insets.sm),
          Expanded(child: Text(text, style: context.tt.bodyMedium)),
        ],
      ),
    );
  }
}

/// The requested catalog product (image + name + base price), if the order was
/// started from one.
class _ProductLine extends ConsumerWidget {
  const _ProductLine({required this.productId});
  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = ref.watch(productDetailProvider(productId)).valueOrNull;
    if (product == null) return const SizedBox.shrink();
    final image =
        product.imageUrls.isNotEmpty ? product.imageUrls.first : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md),
      child: Row(
        children: [
          NetworkPhoto(
              url: image, width: 46, height: 46, radius: Radii.chip),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.tt.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                Text('From ${Formatters.currencyFromCents(product.basePriceCents)}',
                    style: context.tt.bodySmall
                        ?.copyWith(color: context.cs.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
