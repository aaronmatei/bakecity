import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../domain/cart_item.dart';

/// The shopping cart, scoped to the signed-in user (resets on account change)
/// and to a single baker at a time (adding from another baker starts fresh).
final cartProvider =
    StateNotifierProvider<CartController, List<CartItem>>((ref) {
  ref.watch(authControllerProvider.select((s) => s.user?.id));
  return CartController();
});

class CartController extends StateNotifier<List<CartItem>> {
  CartController() : super(const []);

  String? get bakerId => state.isEmpty ? null : state.first.bakerId;
  int get count => state.fold(0, (s, i) => s + i.qty);
  int get totalCents => state.fold(0, (s, i) => s + i.lineCents);

  /// Adds an item, merging with a matching line. Switching bakers starts a new
  /// cart (you check out one bakery at a time).
  void add(CartItem item) {
    if (state.isNotEmpty && state.first.bakerId != item.bakerId) {
      state = [item];
      return;
    }
    final i = state.indexWhere((e) => e.key == item.key);
    if (i >= 0) {
      final next = [...state];
      next[i] = next[i].copyWith(qty: next[i].qty + item.qty);
      state = next;
    } else {
      state = [...state, item];
    }
  }

  void setQty(String key, int qty) {
    if (qty <= 0) {
      remove(key);
      return;
    }
    state = [
      for (final e in state) e.key == key ? e.copyWith(qty: qty) : e,
    ];
  }

  void remove(String key) =>
      state = state.where((e) => e.key != key).toList();

  void clear() => state = const [];
}
