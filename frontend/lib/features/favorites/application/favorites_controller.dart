import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../services/api_client.dart';
import '../../auth/application/auth_controller.dart';
import '../../products/application/products_controller.dart';
import '../../products/domain/product.dart';

/// The signed-in user's favorited product ids. Server-backed (so a wishlist
/// syncs across devices) with an on-device cache for instant/offline reads.
/// Scoped to the auth user id so it resets when the account changes.
final favoritesProvider =
    StateNotifierProvider<FavoritesController, Set<String>>((ref) {
  final userId = ref.watch(authControllerProvider.select((s) => s.user?.id));
  return FavoritesController(ref, userId);
});

/// The favorited products, loaded by id (so all favorites show, not just those
/// on the first products page).
final favoriteProductsProvider = FutureProvider<List<Product>>((ref) async {
  final ids = ref.watch(favoritesProvider);
  if (ids.isEmpty) return const [];
  final products = await Future.wait(ids.map((id) async {
    try {
      return await ref.read(productDetailProvider(id).future);
    } catch (_) {
      return null; // skip a product that failed to load (e.g. removed)
    }
  }));
  return products.whereType<Product>().toList();
});

class FavoritesController extends StateNotifier<Set<String>> {
  FavoritesController(this._ref, this._userId) : super(const <String>{}) {
    _init();
  }

  final Ref _ref;
  final String? _userId;

  String get _key => 'favorite_product_ids_${_userId ?? 'anon'}';

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    state = (prefs.getStringList(_key) ?? const []).toSet();
    if (_userId == null) return;
    // Reconcile with the server (source of truth); keep local cache on failure.
    try {
      final res = await _ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>(ApiEndpoints.favorites);
      final ids = ((res.data?['product_ids'] ?? res.data?['data'] ?? const [])
              as List)
          .map((e) => e.toString())
          .toSet();
      if (!mounted) return;
      state = ids;
      await prefs.setStringList(_key, ids.toList());
    } catch (_) {
      // Offline / error: the cached set stays.
    }
  }

  bool contains(String id) => state.contains(id);

  Future<void> toggle(String id) async {
    final adding = !state.contains(id);
    final next = Set<String>.from(state);
    adding ? next.add(id) : next.remove(id);
    state = next; // optimistic

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, next.toList());
    if (_userId == null) return;
    try {
      final api = _ref.read(apiClientProvider);
      if (adding) {
        await api.put<dynamic>(ApiEndpoints.favorite(id));
      } else {
        await api.delete<dynamic>(ApiEndpoints.favorite(id));
      }
    } catch (_) {
      // Offline: local cache holds; the next _init() reconciles with server.
    }
  }
}
