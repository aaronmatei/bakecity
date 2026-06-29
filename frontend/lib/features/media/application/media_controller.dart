import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../services/api_client.dart';
import '../domain/order_media.dart';

/// Loads the media attached to an order (reference + production photos, etc.),
/// each with a presigned display URL.
final orderMediaProvider =
    FutureProvider.family<List<OrderMedia>, String>((ref, orderId) async {
  final api = ref.watch(apiClientProvider);
  final response =
      await api.get<Map<String, dynamic>>(ApiEndpoints.orderMedia(orderId));
  final items = (response.data?['media'] ?? const []) as List;
  return items
      .map((e) => OrderMedia.fromJson(e as Map<String, dynamic>))
      .toList();
});
