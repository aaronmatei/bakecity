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

  /// Baker proposes a quote for an order. [amount] is the total in KES and
  /// [depositPct] the deposit percentage (1–100); [validUntil] is optional.
  /// Matches the backend contract (POST /orders/:id/quotes).
  Future<Quote> submitQuote({
    required String orderId,
    required double amount,
    required double depositPct,
    DateTime? validUntil,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.orderQuotes(orderId),
      data: {
        'amount': amount,
        'deposit_pct': depositPct,
        if (validUntil != null)
          'valid_until': validUntil.toUtc().toIso8601String(),
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
