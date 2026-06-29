import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/helpers/formatters.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../widgets/app_error_view.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading_indicator.dart';
import '../../../widgets/network_photo.dart';
import '../../../widgets/press_scale.dart';
import '../../onboarding/application/onboarding_controller.dart';
import '../../products/application/products_controller.dart';
import '../../products/domain/product.dart';
import 'product_form_screen.dart';

/// Lets a baker manage their own catalog: toggle each product's availability
/// and edit its starting price. (Uses the existing owner-only PATCH /products.)
class ManageProductsScreen extends ConsumerWidget {
  const ManageProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(onboardingControllerProvider).valueOrNull;
    if (profile == null) {
      return const Scaffold(
        body: LoadingIndicator(label: 'Loading your menu…'),
      );
    }
    final bakerId = profile.id;
    final products = ref.watch(bakerManageProductsProvider(bakerId));

    return Scaffold(
      appBar: AppBar(title: const Text('Manage menu')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ProductFormScreen(bakerId: bakerId),
        )),
        icon: const Icon(Icons.add),
        label: const Text('Add product'),
      ),
      body: products.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => AppErrorView(
          message: e is AppException ? e.message : e.toString(),
          onRetry: () => ref.invalidate(bakerManageProductsProvider(bakerId)),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.cake_outlined,
              title: 'No products yet',
              message: 'Your published treats will appear here to manage.',
            );
          }
          return RefreshIndicator(
            color: context.cs.primary,
            onRefresh: () async =>
                ref.invalidate(bakerManageProductsProvider(bakerId)),
            child: ListView.separated(
              padding: const EdgeInsets.all(Insets.screenH),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: Insets.md),
              itemBuilder: (context, i) =>
                  _ManageTile(product: list[i], bakerId: bakerId),
            ),
          );
        },
      ),
    );
  }
}

class _ManageTile extends ConsumerWidget {
  const _ManageTile({required this.product, required this.bakerId});
  final Product product;
  final String bakerId;

  Future<void> _update(
    WidgetRef ref,
    ScaffoldMessengerState messenger, {
    bool? active,
    int? basePriceCents,
  }) async {
    try {
      await ref.read(catalogControllerProvider).updateProduct(
            product.id,
            active: active,
            basePriceCents: basePriceCents,
          );
      ref.invalidate(bakerManageProductsProvider(bakerId));
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _openEdit(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProductFormScreen(bakerId: bakerId, product: product),
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = context.cs;
    final image =
        product.imageUrls.isNotEmpty ? product.imageUrls.first : null;
    final available = product.isAvailable;

    return Container(
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: Radii.cardBorder,
        boxShadow: context.bake.cardShadow,
      ),
      child: Row(
        children: [
          // Tap the product to open the full edit form.
          Expanded(
            child: PressScale(
              onTap: () => _openEdit(context),
              child: Row(
                children: [
                  Opacity(
                    opacity: available ? 1 : 0.45,
                    child: NetworkPhoto(
                        url: image, width: 56, height: 56, radius: Radii.chip),
                  ),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.tt.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'From ${Formatters.currencyFromCents(product.basePriceCents)}',
                          style: context.tt.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: Insets.sm),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch(
                value: available,
                onChanged: (v) =>
                    _update(ref, ScaffoldMessenger.of(context), active: v),
              ),
              Text(available ? 'Available' : 'Hidden',
                  style: context.tt.labelSmall
                      ?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }
}
