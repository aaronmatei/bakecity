import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../services/api_client.dart';
import '../domain/quote.dart';

/// Loads the quotes attached to an order.
final orderQuotesProvider =
    FutureProvider.family<List<Quote>, String>((ref, orderId) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.get<Map<String, dynamic>>(
    ApiEndpoints.orderQuotes(orderId),
  );
  final items =
      (response.data?['data'] ?? response.data?['quotes'] ?? []) as List;
  return items.map((e) => Quote.fromJson(e as Map<String, dynamic>)).toList();
});

/// Mutations on quotes (baker submits, customer accepts).
final quotesControllerProvider = Provider<QuotesController>((ref) {
  return QuotesController(ref.read(apiClientProvider));
});

class QuotesController {
  QuotesController(this._api);

  final ApiClient _api;

  /// Baker submits a quote for an order.
  Future<Quote> submitQuote({
    required String orderId,
    required int totalCents,
    required int depositCents,
    String? notes,
    int? leadTimeDays,
    List<QuoteLineItem> lineItems = const [],
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.orderQuotes(orderId),
      data: {
        'total_cents': totalCents,
        'deposit_cents': depositCents,
        if (notes != null) 'notes': notes,
        if (leadTimeDays != null) 'lead_time_days': leadTimeDays,
        'line_items': lineItems.map((e) => e.toJson()).toList(),
      },
    );
    return Quote.fromJson(response.data!);
  }

  /// Customer accepts a quote (moves the order toward deposit payment).
  Future<void> acceptQuote({
    required String orderId,
    required String quoteId,
  }) async {
    await _api.post<void>(
      ApiEndpoints.orderQuoteAccept(orderId, quoteId),
    );
  }
}
