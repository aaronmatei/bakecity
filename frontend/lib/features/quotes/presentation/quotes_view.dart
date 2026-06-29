import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/helpers/formatters.dart';
import '../../../widgets/app_error_view.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading_indicator.dart';
import '../../auth/application/auth_controller.dart';
import '../../orders/application/orders_controller.dart';
import '../domain/quote.dart';
import '../application/quotes_controller.dart';

/// Lists quotes for an order and lets the customer review and accept one.
class QuotesView extends ConsumerStatefulWidget {
  const QuotesView({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<QuotesView> createState() => _QuotesViewState();
}

class _QuotesViewState extends ConsumerState<QuotesView> {
  String? _acceptingId;

  bool get _isCustomer =>
      ref.read(authControllerProvider).user?.isCustomer ?? false;

  Future<void> _accept(Quote quote) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Accept this quote?'),
        content: Text(
          'You’ll pay a deposit of '
          '${Formatters.currencyFromCents(quote.depositCents)} to confirm your '
          'order. The ${Formatters.currencyFromCents(quote.balanceCents)} '
          'balance is due after delivery.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _acceptingId = quote.id);
    try {
      await ref.read(quotesControllerProvider).acceptQuote(
            orderId: widget.orderId,
            quoteId: quote.id,
          );
      // The order advances to APPROVED and a deposit becomes due — refresh both.
      ref.invalidate(orderQuotesProvider(widget.orderId));
      ref.invalidate(orderDetailProvider(widget.orderId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quote accepted — pay your deposit to confirm.'),
          ),
        );
      }
    } on AppException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _acceptingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final quotes = ref.watch(orderQuotesProvider(widget.orderId));
    return quotes.when(
      loading: () => const LoadingIndicator(),
      error: (e, _) => AppErrorView(
        message: e is AppException ? e.message : e.toString(),
        onRetry: () => ref.invalidate(orderQuotesProvider(widget.orderId)),
      ),
      data: (list) {
        if (list.isEmpty) {
          return const EmptyState(
            icon: Icons.request_quote_outlined,
            message: 'No quotes yet. The baker will send one shortly.',
          );
        }
        final anyAccepted = list.any((q) => q.status == QuoteStatus.accepted);
        return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(orderQuotesProvider(widget.orderId)),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final quote = list[i];
              return _QuoteCard(
                quote: quote,
                // The newest quote is first; only it is actionable, and only
                // while nothing else has been accepted yet.
                isLatest: i == 0,
                anyAccepted: anyAccepted,
                isCustomer: _isCustomer,
                accepting: _acceptingId == quote.id,
                busy: _acceptingId != null,
                onAccept: () => _accept(quote),
              );
            },
          ),
        );
      },
    );
  }
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({
    required this.quote,
    required this.isLatest,
    required this.anyAccepted,
    required this.isCustomer,
    required this.accepting,
    required this.busy,
    required this.onAccept,
  });

  final Quote quote;
  final bool isLatest;
  final bool anyAccepted;
  final bool isCustomer;
  final bool accepting;
  final bool busy;
  final VoidCallback onAccept;

  bool get _isExpired =>
      quote.status == QuoteStatus.expired ||
      (quote.expiresAt != null && quote.expiresAt!.isBefore(DateTime.now()));

  bool get _canAccept =>
      isCustomer &&
      isLatest &&
      !anyAccepted &&
      quote.status == QuoteStatus.pending &&
      !_isExpired;

  int get _depositPct => quote.totalCents > 0
      ? (quote.depositCents * 100 / quote.totalCents).round()
      : 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Formatters.currencyFromCents(quote.totalCents),
                  style: theme.textTheme.headlineSmall,
                ),
                _StatusChip(status: quote.status, expired: _isExpired),
              ],
            ),
            const SizedBox(height: 12),
            _Line(
              label: 'Deposit due now',
              value: '${Formatters.currencyFromCents(quote.depositCents)}'
                  '${_depositPct > 0 ? ' ($_depositPct%)' : ''}',
              emphasize: true,
            ),
            _Line(
              label: 'Balance after delivery',
              value: Formatters.currencyFromCents(quote.balanceCents),
            ),
            if (quote.leadTimeDays != null)
              _Line(label: 'Lead time', value: '${quote.leadTimeDays} day(s)'),
            if (quote.expiresAt != null)
              _Line(
                label: _isExpired ? 'Expired' : 'Valid until',
                value: Formatters.eventDate(quote.expiresAt!),
              ),
            if (quote.notes != null && quote.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(quote.notes!, style: theme.textTheme.bodyMedium),
            ],
            if (_canAccept) ...[
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: busy ? null : onAccept,
                  icon: accepting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: const Text('Accept quote'),
                ),
              ),
            ] else if (quote.status == QuoteStatus.accepted) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.check_circle,
                      size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Accepted — pay your deposit on the Payment tab.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ] else if (isCustomer && !anyAccepted && _isExpired) ...[
              const SizedBox(height: 8),
              Text(
                'This quote is no longer valid. Ask the baker for an updated one.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              )),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.expired});

  final QuoteStatus status;
  final bool expired;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (String label, Color bg, Color fg) = switch (status) {
      QuoteStatus.accepted => (
          'Accepted',
          Colors.green.withValues(alpha: 0.15),
          Colors.green.shade800,
        ),
      QuoteStatus.pending when !expired => (
          'New',
          theme.colorScheme.primaryContainer,
          theme.colorScheme.onPrimaryContainer,
        ),
      QuoteStatus.declined => (
          'Declined',
          theme.colorScheme.surfaceContainerHighest,
          theme.colorScheme.onSurfaceVariant,
        ),
      _ => (
          'Expired',
          theme.colorScheme.surfaceContainerHighest,
          theme.colorScheme.onSurfaceVariant,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
