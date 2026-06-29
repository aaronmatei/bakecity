import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/helpers/formatters.dart';
import '../../../routes/app_routes.dart';
import '../../../widgets/app_error_view.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading_indicator.dart';
import '../../products/application/products_controller.dart';
import '../../products/domain/product.dart';
import '../application/baker_storefront_controller.dart';
import '../domain/my_baker_profile.dart';

/// A baker's public storefront: profile header plus their catalog, each item
/// leading into the custom-order request flow.
class BakerStorefrontScreen extends ConsumerWidget {
  const BakerStorefrontScreen({super.key, required this.bakerId});

  final String bakerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(bakerProfileProvider(bakerId));

    return Scaffold(
      appBar: AppBar(title: const Text('Bakery')),
      body: SafeArea(
        child: profile.when(
          loading: () => const LoadingIndicator(),
          error: (e, _) => AppErrorView(
            message: e is AppException ? e.message : e.toString(),
            onRetry: () => ref.invalidate(bakerProfileProvider(bakerId)),
          ),
          data: (baker) => RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(bakerProfileProvider(bakerId));
              ref.invalidate(productsProvider(bakerId));
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _Header(baker: baker),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => context.pushNamed(
                    AppRoutes.bakerReviewsName,
                    pathParameters: {'bakerId': bakerId},
                  ),
                  icon: const Icon(Icons.star_outline),
                  label: const Text('View reviews'),
                ),
                const SizedBox(height: 24),
                Text('Menu', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                _Menu(bakerId: bakerId),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.baker});

  final MyBakerProfile baker;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const CircleAvatar(
              radius: 28,
              child: Icon(Icons.storefront_outlined),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          baker.businessName,
                          style: theme.textTheme.headlineSmall,
                        ),
                      ),
                      if (baker.isApproved) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.verified,
                            size: 20, color: theme.colorScheme.primary),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        if (baker.bio.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(baker.bio, style: theme.textTheme.bodyMedium),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _InfoChip(
              icon: Icons.schedule_outlined,
              label: '${baker.leadTimeDays} day lead time',
            ),
            _InfoChip(
              icon: Icons.delivery_dining_outlined,
              label: 'Delivers ~${baker.deliveryRadiusKm.toStringAsFixed(0)} km',
            ),
          ],
        ),
      ],
    );
  }
}

class _Menu extends ConsumerWidget {
  const _Menu({required this.bakerId});

  final String bakerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productsProvider(bakerId));
    return products.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: LoadingIndicator(),
      ),
      error: (e, _) => AppErrorView(
        message: e is AppException ? e.message : e.toString(),
        onRetry: () => ref.invalidate(productsProvider(bakerId)),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const EmptyState(
            icon: Icons.cake_outlined,
            message: 'This baker hasn’t published any products yet.',
          );
        }
        return Column(
          children: [
            for (final product in items) _ProductTile(product: product),
          ],
        );
      },
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: product.imageUrls.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: product.imageUrls.first,
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => const SizedBox(
                    width: 52,
                    height: 52,
                    child: Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                  errorWidget: (_, __, ___) =>
                      const CircleAvatar(child: Icon(Icons.cake_outlined)),
                ),
              )
            : const CircleAvatar(child: Icon(Icons.cake_outlined)),
        title: Text(product.name),
        subtitle: Text(
          'From ${Formatters.currencyFromCents(product.basePriceCents)}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.pushNamed(
          AppRoutes.productDetailName,
          pathParameters: {'productId': product.id},
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}
