import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Locally-persisted set of favorited product ids. There's no backend wishlist
/// yet, so favorites live on-device via shared_preferences — enough to drive the
/// heart toggles and a Favorites grid.
final favoritesProvider =
    StateNotifierProvider<FavoritesController, Set<String>>((ref) {
  return FavoritesController();
});

class FavoritesController extends StateNotifier<Set<String>> {
  FavoritesController() : super(const <String>{}) {
    _load();
  }

  static const _key = 'favorite_product_ids';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = (prefs.getStringList(_key) ?? const []).toSet();
  }

  bool contains(String id) => state.contains(id);

  Future<void> toggle(String id) async {
    final next = Set<String>.from(state);
    if (!next.add(id)) next.remove(id);
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, next.toList());
  }
}
