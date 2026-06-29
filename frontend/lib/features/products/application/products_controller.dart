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

/// Loads a single product by id.
final productDetailProvider =
    FutureProvider.family<Product, String>((ref, productId) async {
  final api = ref.watch(apiClientProvider);
  final response =
      await api.get<Map<String, dynamic>>(ApiEndpoints.product(productId));
  return Product.fromJson(response.data!);
});

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
