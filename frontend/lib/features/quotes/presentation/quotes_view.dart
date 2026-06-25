import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/helpers/formatters.dart';
import '../../../widgets/app_error_view.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading_indicator.dart';
import '../application/quotes_controller.dart';

/// Lists quotes for an order and lets the customer accept one.
class QuotesView extends ConsumerWidget {
  const QuotesView({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quotes = ref.watch(orderQuotesProvider(orderId));
    return quotes.when(
      loading: () => const LoadingIndicator(),
      error: (e, _) => AppErrorView(
        message: e.toString(),
        onRetry: () => ref.invalidate(orderQuotesProvider(orderId)),
      ),
      data: (list) {
        if (list.isEmpty) {
          return const EmptyState(
            icon: Icons.request_quote_outlined,
            message: 'No quotes yet. The baker will send one shortly.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final quote = list[i];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Formatters.currencyFromCents(quote.totalCents),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Deposit: '
                      '${Formatters.currencyFromCents(quote.depositCents)}',
                    ),
                    if (quote.notes != null) ...[
                      const SizedBox(height: 8),
                      Text(quote.notes!),
                    ],
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: () async {
                          await ref.read(quotesControllerProvider).acceptQuote(
                                orderId: orderId,
                                quoteId: quote.id,
                              );
                          ref.invalidate(orderQuotesProvider(orderId));
                        },
                        child: const Text('Accept'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
