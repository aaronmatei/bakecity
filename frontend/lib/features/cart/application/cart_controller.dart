import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/application/auth_controller.dart';
import '../domain/cart_item.dart';

/// The shopping cart, scoped to the signed-in user (resets on account change),
/// to a single baker at a time, and persisted across restarts.
final cartProvider =
    StateNotifierProvider<CartController, List<CartItem>>((ref) {
  final userId = ref.watch(authControllerProvider.select((s) => s.user?.id));
  return CartController(userId);
});

class CartController extends StateNotifier<List<CartItem>> {
  CartController(this._userId) : super(const []) {
    _load();
  }

  final String? _userId;
  String get _key => 'cart_${_userId ?? 'anon'}';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => CartItem.fromJson(e as Map<String, dynamic>))
          .toList();
      if (mounted) state = list;
    } catch (_) {
      // Corrupt/old payload — ignore and start empty.
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode([for (final i in state) i.toJson()]));
  }

  /// Sets state and persists it.
  void _set(List<CartItem> next) {
    state = next;
    _persist();
  }

  String? get bakerId => state.isEmpty ? null : state.first.bakerId;
  int get count => state.fold(0, (s, i) => s + i.qty);
  int get totalCents => state.fold(0, (s, i) => s + i.lineCents);

  /// Adds an item, merging with a matching line. Switching bakers starts a new
  /// cart (you check out one bakery at a time).
  void add(CartItem item) {
    if (state.isNotEmpty && state.first.bakerId != item.bakerId) {
      _set([item]);
      return;
    }
    final i = state.indexWhere((e) => e.key == item.key);
    if (i >= 0) {
      final next = [...state];
      next[i] = next[i].copyWith(qty: next[i].qty + item.qty);
      _set(next);
    } else {
      _set([...state, item]);
    }
  }

  void setQty(String key, int qty) {
    if (qty <= 0) {
      remove(key);
      return;
    }
    _set([
      for (final e in state) e.key == key ? e.copyWith(qty: qty) : e,
    ]);
  }

  void remove(String key) =>
      _set(state.where((e) => e.key != key).toList());

  void clear() => _set(const []);
}
