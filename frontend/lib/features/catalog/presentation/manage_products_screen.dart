import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/helpers/formatters.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../widgets/app_error_view.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading_indicator.dart';
import '../../../widgets/network_photo.dart';
import '../../onboarding/application/onboarding_controller.dart';
import '../../products/application/products_controller.dart';
import '../../products/domain/product.dart';

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

  Future<void> _editPrice(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final controller = TextEditingController(
        text: (product.basePriceCents / 100).toStringAsFixed(0));
    final newPrice = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit starting price'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          decoration: const InputDecoration(
            labelText: 'Starting price (KES)',
            prefixIcon: Icon(Icons.sell_outlined),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, double.tryParse(controller.text.trim())),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newPrice != null && newPrice > 0) {
      await _update(ref, messenger, basePriceCents: (newPrice * 100).round());
    }
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
                GestureDetector(
                  onTap: () => _editPrice(context, ref),
                  child: Row(
                    children: [
                      Text(
                        'From ${Formatters.currencyFromCents(product.basePriceCents)}',
                        style: context.tt.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.edit_outlined,
                          size: 14, color: cs.onSurfaceVariant),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
