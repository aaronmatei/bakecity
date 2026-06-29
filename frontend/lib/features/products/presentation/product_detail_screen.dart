import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/helpers/formatters.dart';
import '../../../routes/app_routes.dart';
import '../../../widgets/app_error_view.dart';
import '../../../widgets/loading_indicator.dart';
import '../../../widgets/primary_button.dart';
import '../application/products_controller.dart';

class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = ref.watch(productDetailProvider(productId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Product')),
      body: product.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => AppErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(productDetailProvider(productId)),
        ),
        data: (p) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: p.imageUrls.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: p.imageUrls.first,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        height: 200,
                        color: theme.colorScheme.surfaceContainerHighest,
                        alignment: Alignment.center,
                        child: const CircularProgressIndicator(),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        height: 200,
                        color: theme.colorScheme.surfaceContainerHighest,
                        alignment: Alignment.center,
                        child: const Icon(Icons.image_outlined, size: 48),
                      ),
                    )
                  : Container(
                      height: 200,
                      color: theme.colorScheme.surfaceContainerHighest,
                      alignment: Alignment.center,
                      child: const Icon(Icons.image_outlined, size: 48),
                    ),
            ),
            const SizedBox(height: 16),
            Text(p.name, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'From ${Formatters.currencyFromCents(p.basePriceCents)}',
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 16),
            if (p.description != null) Text(p.description!),
            const SizedBox(height: 8),
            Text('Lead time: ${p.leadTimeDays} day(s)'),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Request a custom order',
              icon: Icons.add_shopping_cart_outlined,
              onPressed: () => context.pushNamed(
                AppRoutes.productOrderRequestName,
                pathParameters: {'productId': p.id},
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => context.pushNamed(
                AppRoutes.bakerReviewsName,
                pathParameters: {'bakerId': p.bakerId},
              ),
              icon: const Icon(Icons.star_outline),
              label: const Text('View baker reviews'),
            ),
          ],
        ),
      ),
    );
  }
}
