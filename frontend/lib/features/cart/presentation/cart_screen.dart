import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/helpers/formatters.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../routes/app_routes.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/network_photo.dart';
import '../../../widgets/primary_button.dart';
import '../../orders/application/orders_controller.dart';
import '../application/cart_controller.dart';
import '../domain/cart_item.dart';

/// The shopping cart for fixed products: review lines, then check out into a
/// single prepaid (escrow) order.
class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  DateTime? _date;
  String _fulfillment = 'delivery';
  final _address = TextEditingController();
  bool _placing = false;

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now.add(const Duration(days: 1)),
      firstDate: now.add(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 120)),
      helpText: 'When do you want it?',
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _checkout() async {
    final cart = ref.read(cartProvider);
    final ctrl = ref.read(cartProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    if (cart.isEmpty) return;
    if (_date == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Pick a date.')));
      return;
    }
    if (_fulfillment == 'delivery' && _address.text.trim().isEmpty) {
      messenger
          .showSnackBar(const SnackBar(content: Text('Enter a delivery address.')));
      return;
    }
    setState(() => _placing = true);
    try {
      final order = await ref.read(ordersControllerProvider.notifier).createOrder(
            bakerId: ctrl.bakerId!,
            eventDate: _date!,
            fulfillment: _fulfillment,
            deliveryAddress:
                _fulfillment == 'delivery' ? _address.text.trim() : '',
            items: [
              for (final i in cart)
                {
                  'product_id': i.productId,
                  if (i.sizeId != null) 'size_id': i.sizeId,
                  'qty': i.qty,
                },
            ],
          );
      ctrl.clear();
      messenger.showSnackBar(
        const SnackBar(content: Text('Order placed — pay to confirm.')),
      );
      if (mounted) {
        context.pushReplacementNamed(
          AppRoutes.orderDetailName,
          pathParameters: {'orderId': order.id},
        );
      }
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final ctrl = ref.read(cartProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cart'),
        actions: [
          if (cart.isNotEmpty)
            TextButton(
              onPressed: () => ctrl.clear(),
              child: const Text('Clear'),
            ),
        ],
      ),
      body: cart.isEmpty
          ? const EmptyState(
              icon: Icons.shopping_cart_outlined,
              title: 'Your cart is empty',
              message: 'Add a ready-made treat to get started.',
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(Insets.screenH),
                    itemCount: cart.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: Insets.md),
                    itemBuilder: (context, i) {
                      final item = cart[i];
                      return _CartTile(
                        item: item,
                        onDec: () =>
                            ctrl.setQty(item.key, item.qty - 1),
                        onInc: () =>
                            ctrl.setQty(item.key, item.qty + 1),
                        onRemove: () => ctrl.remove(item.key),
                      );
                    },
                  ),
                ),
                _checkoutBar(context, ctrl),
              ],
            ),
    );
  }

  Widget _checkoutBar(BuildContext context, CartController ctrl) {
    final cs = context.cs;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        boxShadow: context.bake.cardShadow,
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.all(Insets.screenH),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                    value: 'delivery',
                    label: Text('Delivery'),
                    icon: Icon(Icons.delivery_dining_outlined)),
                ButtonSegment(
                    value: 'pickup',
                    label: Text('Pickup'),
                    icon: Icon(Icons.storefront_outlined)),
              ],
              selected: {_fulfillment},
              onSelectionChanged: (s) =>
                  setState(() => _fulfillment = s.first),
            ),
            if (_fulfillment == 'delivery') ...[
              const SizedBox(height: Insets.sm),
              TextField(
                controller: _address,
                decoration: const InputDecoration(
                  labelText: 'Delivery address',
                  isDense: true,
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
            ],
            const SizedBox(height: Insets.sm),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.event_outlined),
              label: Text(_date == null
                  ? 'Pick a date'
                  : 'For ${Formatters.shortDate(_date!)}'),
            ),
            const SizedBox(height: Insets.md),
            PrimaryButton(
              label:
                  'Place order · ${Formatters.currencyFromCents(ctrl.totalCents)}',
              icon: Icons.lock_outline,
              isLoading: _placing,
              onPressed: _placing ? null : _checkout,
            ),
            const SizedBox(height: 4),
            Text(
              'Paid in full upfront, held securely, and released to the baker '
              'when you receive your order.',
              textAlign: TextAlign.center,
              style: context.tt.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartTile extends StatelessWidget {
  const _CartTile({
    required this.item,
    required this.onDec,
    required this.onInc,
    required this.onRemove,
  });
  final CartItem item;
  final VoidCallback onDec, onInc, onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Container(
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: Radii.cardBorder,
        boxShadow: context.bake.cardShadow,
      ),
      child: Row(
        children: [
          NetworkPhoto(
              url: item.imageUrl, width: 52, height: 52, radius: Radii.chip),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.tt.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                if (item.sizeLabel != null)
                  Text(item.sizeLabel!,
                      style: context.tt.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant)),
                Text(Formatters.currencyFromCents(item.lineCents),
                    style: context.tt.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          IconButton(
              icon: const Icon(Icons.remove_circle_outline), onPressed: onDec),
          Text('${item.qty}', style: context.tt.titleSmall),
          IconButton(
              icon: const Icon(Icons.add_circle_outline), onPressed: onInc),
          IconButton(
              icon: Icon(Icons.delete_outline, color: cs.onSurfaceVariant),
              onPressed: onRemove),
        ],
      ),
    );
  }
}
