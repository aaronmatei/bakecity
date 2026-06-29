import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../services/api_client.dart';
import '../domain/product.dart';

/// Loads products, optionally scoped to a baker. Baker scoping is done via the
/// `baker_id` filter on GET /products (the backend has no /bakers/:id/products).
final productsProvider =
    FutureProvider.family<List<Product>, String?>((ref, bakerId) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.get<Map<String, dynamic>>(
    ApiEndpoints.products,
    queryParameters: {
      if (bakerId != null) 'baker_id': bakerId,
    },
  );
  final items =
      (response.data?['data'] ?? response.data?['products'] ?? []) as List;
  return items
      .map((e) => Product.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// A composable catalog filter for GET /search/products. All set fields apply
/// together (AND). [sort] is one of: top_rated, best_selling, nearest,
/// price_asc, price_desc, newest.
class ProductFilter {
  const ProductFilter({
    this.category,
    this.occasion,
    this.flavor,
    this.format,
    this.dietary = const [],
    this.minPrice,
    this.maxPrice,
    this.minRating,
    this.onOffer,
    this.bakerId,
    this.sort,
    this.query,
    this.limit = 20,
  });

  final String? category;
  final String? occasion;
  final String? flavor;
  final String? format;
  final List<String> dietary;
  final double? minPrice;
  final double? maxPrice;
  final double? minRating;
  final bool? onOffer;
  final String? bakerId;
  final String? sort;
  final String? query;
  final int limit;

  ProductFilter copyWith({
    String? category,
    String? occasion,
    String? flavor,
    String? format,
    List<String>? dietary,
    double? minPrice,
    double? maxPrice,
    double? minRating,
    bool? onOffer,
    String? sort,
    String? query,
    bool clearCategory = false,
    bool clearCakeAxes = false,
    bool clearPrice = false,
    bool clearRating = false,
    bool clearOffer = false,
  }) {
    return ProductFilter(
      category: clearCategory ? null : (category ?? this.category),
      occasion: clearCakeAxes ? null : (occasion ?? this.occasion),
      flavor: clearCakeAxes ? null : (flavor ?? this.flavor),
      format: clearCakeAxes ? null : (format ?? this.format),
      dietary: dietary ?? this.dietary,
      minPrice: clearPrice ? null : (minPrice ?? this.minPrice),
      maxPrice: clearPrice ? null : (maxPrice ?? this.maxPrice),
      minRating: clearRating ? null : (minRating ?? this.minRating),
      onOffer: clearOffer ? null : (onOffer ?? this.onOffer),
      bakerId: bakerId,
      sort: sort ?? this.sort,
      query: query ?? this.query,
      limit: limit,
    );
  }

  Map<String, dynamic> toQueryParameters() => {
        if (category != null) 'category': category,
        if (occasion != null) 'occasion': occasion,
        if (flavor != null) 'flavor': flavor,
        if (format != null) 'format': format,
        if (dietary.isNotEmpty) 'dietary': dietary.join(','),
        if (minPrice != null) 'min_price': minPrice,
        if (maxPrice != null) 'max_price': maxPrice,
        if (minRating != null) 'min_rating': minRating,
        if (onOffer == true) 'on_offer': true,
        if (bakerId != null) 'baker_id': bakerId,
        if (sort != null) 'sort': sort,
        if (query != null && query!.isNotEmpty) 'q': query,
        'limit': limit,
      };

  String get _key =>
      '$category|$occasion|$flavor|$format|${dietary.join(",")}|$minPrice|'
      '$maxPrice|$minRating|$onOffer|$bakerId|$sort|$query|$limit';

  @override
  bool operator ==(Object other) =>
      other is ProductFilter && other._key == _key;

  @override
  int get hashCode => _key.hashCode;
}

/// Searches the catalog with a composable [ProductFilter].
final productSearchProvider =
    FutureProvider.family<List<Product>, ProductFilter>((ref, filter) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.get<Map<String, dynamic>>(
    ApiEndpoints.searchProducts,
    queryParameters: filter.toQueryParameters(),
  );
  final items =
      (response.data?['data'] ?? response.data?['products'] ?? []) as List;
  return items
      .map((e) => Product.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Loads a single product by id.
final productDetailProvider =
    FutureProvider.family<Product, String>((ref, productId) async {
  final api = ref.watch(apiClientProvider);
  final response =
      await api.get<Map<String, dynamic>>(ApiEndpoints.product(productId));
  return Product.fromJson(response.data!);
});

/// All of a baker's own products — including inactive ones — for menu
/// management (the public list hides inactive products).
final bakerManageProductsProvider =
    FutureProvider.family<List<Product>, String>((ref, bakerId) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.get<Map<String, dynamic>>(
    ApiEndpoints.products,
    queryParameters: {'baker_id': bakerId, 'active': 'all', 'limit': 100},
  );
  final items =
      (response.data?['data'] ?? response.data?['products'] ?? []) as List;
  return items
      .map((e) => Product.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Mutations a baker makes on their own catalog.
final catalogControllerProvider =
    Provider<CatalogController>((ref) => CatalogController(ref));

class CatalogController {
  CatalogController(this._ref);
  final Ref _ref;

  /// Creates a product for the signed-in baker. [sizes] is a list of
  /// `{label, weight_kg?, serves?, price}` maps (price in KES).
  Future<void> createProduct({
    required String title,
    String? categoryId,
    String? description,
    required int basePriceCents,
    int? leadTimeDays,
    List<String> dietary = const [],
    bool isOnOffer = false,
    int? discountPct,
    String? cakeOccasion,
    String? cakeFlavor,
    String? cakeFormat,
    List<Map<String, dynamic>> sizes = const [],
    List<String> imageMediaIds = const [],
  }) async {
    await _ref.read(apiClientProvider).post<Map<String, dynamic>>(
      ApiEndpoints.products,
      data: {
        'title': title,
        if (categoryId != null) 'category_id': categoryId,
        if (description != null && description.isNotEmpty)
          'description': description,
        'base_price': basePriceCents / 100,
        if (leadTimeDays != null) 'lead_time_days': leadTimeDays,
        'dietary': dietary,
        'is_on_offer': isOnOffer,
        if (discountPct != null) 'discount_pct': discountPct,
        if (cakeOccasion != null) 'cake_occasion': cakeOccasion,
        if (cakeFlavor != null) 'cake_flavor': cakeFlavor,
        if (cakeFormat != null) 'cake_format': cakeFormat,
        'sizes': sizes,
        if (imageMediaIds.isNotEmpty) 'image_media_ids': imageMediaIds,
      },
    );
  }

  /// Patches a product (owner-only on the backend). Pass only what changes;
  /// a non-null [sizes] replaces the product's size set.
  Future<void> updateProduct(
    String id, {
    bool? active,
    int? basePriceCents,
    String? title,
    String? description,
    String? categoryId,
    int? leadTimeDays,
    List<String>? dietary,
    bool? isOnOffer,
    int? discountPct,
    String? cakeOccasion,
    String? cakeFlavor,
    String? cakeFormat,
    List<Map<String, dynamic>>? sizes,
    List<String>? imageMediaIds,
  }) async {
    await _ref.read(apiClientProvider).patch<Map<String, dynamic>>(
      ApiEndpoints.product(id),
      data: {
        if (active != null) 'active': active,
        if (basePriceCents != null) 'base_price': basePriceCents / 100,
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (categoryId != null) 'category_id': categoryId,
        if (leadTimeDays != null) 'lead_time_days': leadTimeDays,
        if (dietary != null) 'dietary': dietary,
        if (isOnOffer != null) 'is_on_offer': isOnOffer,
        if (discountPct != null) 'discount_pct': discountPct,
        if (cakeOccasion != null) 'cake_occasion': cakeOccasion,
        if (cakeFlavor != null) 'cake_flavor': cakeFlavor,
        if (cakeFormat != null) 'cake_format': cakeFormat,
        if (sizes != null) 'sizes': sizes,
        if (imageMediaIds != null) 'image_media_ids': imageMediaIds,
      },
    );
  }
}

/// Loads the product categories.
final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final response =
      await api.get<Map<String, dynamic>>(ApiEndpoints.categories);
  final items =
      (response.data?['data'] ?? response.data?['categories'] ?? []) as List;
  return items
      .map((e) => Category.fromJson(e as Map<String, dynamic>))
      .toList();
});
