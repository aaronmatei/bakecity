import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
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

  bool get _isBaker => ref.read(authControllerProvider).user?.isBaker ?? false;

  /// The baker may quote only while the order is still in negotiation.
  bool _canQuote(OrderStatus? status) =>
      _isBaker &&
      (status == OrderStatus.pendingQuote || status == OrderStatus.quoted);

  Future<void> _openQuoteForm({required bool isUpdate}) async {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _QuoteForm(
          isUpdate: isUpdate,
          onSubmit: (amount, depositPct, validUntil) async {
            await ref.read(quotesControllerProvider).submitQuote(
                  orderId: widget.orderId,
                  amount: amount,
                  depositPct: depositPct,
                  validUntil: validUntil,
                );
            ref.invalidate(orderQuotesProvider(widget.orderId));
            ref.invalidate(orderDetailProvider(widget.orderId));
          },
        ),
      ),
    );
    if (sent == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quote sent to the customer.')),
      );
    }
  }

  Widget _sendQuoteButton({required bool isUpdate}) {
    return FilledButton.icon(
      onPressed: () => _openQuoteForm(isUpdate: isUpdate),
      icon: const Icon(Icons.request_quote_outlined),
      label: Text(isUpdate ? 'Send an updated quote' : 'Send a quote'),
    );
  }

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
    final orderStatus =
        ref.watch(orderDetailProvider(widget.orderId)).valueOrNull?.status;
    final canQuote = _canQuote(orderStatus);

    return quotes.when(
      loading: () => const LoadingIndicator(),
      error: (e, _) => AppErrorView(
        message: e is AppException ? e.message : e.toString(),
        onRetry: () => ref.invalidate(orderQuotesProvider(widget.orderId)),
      ),
      data: (list) {
        final anyAccepted = list.any((q) => q.status == QuoteStatus.accepted);

        if (list.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (canQuote)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _sendQuoteButton(isUpdate: false),
                ),
              const Expanded(
                child: EmptyState(
                  icon: Icons.request_quote_outlined,
                  message: 'No quotes yet. The baker will send one shortly.',
                ),
              ),
            ],
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(orderQuotesProvider(widget.orderId));
            ref.invalidate(orderDetailProvider(widget.orderId));
          },
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length + (canQuote ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              if (canQuote && i == 0) {
                return _sendQuoteButton(isUpdate: true);
              }
              final quote = list[i - (canQuote ? 1 : 0)];
              return _QuoteCard(
                quote: quote,
                // The newest quote is first; only it is actionable, and only
                // while nothing else has been accepted yet.
                isLatest: quote == list.first,
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

/// Bottom-sheet form the baker uses to propose (or revise) a quote.
class _QuoteForm extends StatefulWidget {
  const _QuoteForm({required this.isUpdate, required this.onSubmit});

  final bool isUpdate;
  final Future<void> Function(
    double amount,
    double depositPct,
    DateTime? validUntil,
  ) onSubmit;

  @override
  State<_QuoteForm> createState() => _QuoteFormState();
}

class _QuoteFormState extends State<_QuoteForm> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _depositPct = TextEditingController(text: '50');
  DateTime? _validUntil;
  bool _submitting = false;

  @override
  void dispose() {
    _amount.dispose();
    _depositPct.dispose();
    super.dispose();
  }

  Future<void> _pickValidUntil() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _validUntil ?? now.add(const Duration(days: 7)),
      firstDate: now.add(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 90)),
      helpText: 'Quote valid until',
    );
    if (picked != null) {
      // Hold the quote open until the end of the chosen day.
      setState(() =>
          _validUntil = DateTime(picked.year, picked.month, picked.day, 23, 59));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(
        double.parse(_amount.text.trim()),
        double.parse(_depositPct.text.trim()),
        _validUntil,
      );
      if (mounted) Navigator.pop(context, true);
    } on AppException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String? _validateAmount(String? value) {
    final n = double.tryParse((value ?? '').trim());
    if (n == null || n <= 0) return 'Enter a total above 0';
    return null;
  }

  String? _validatePct(String? value) {
    final n = double.tryParse((value ?? '').trim());
    if (n == null || n <= 0 || n > 100) return 'Enter 1–100';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.isUpdate ? 'Send an updated quote' : 'Send a quote',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'The customer reviews and accepts before paying a deposit.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _amount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Total price (KES)',
                  prefixIcon: Icon(Icons.sell_outlined),
                ),
                validator: _validateAmount,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _depositPct,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Deposit (%)',
                  helperText: 'Share due up front to confirm the order',
                  prefixIcon: Icon(Icons.percent_outlined),
                ),
                validator: _validatePct,
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: Text(
                  _validUntil == null
                      ? 'Valid until (optional)'
                      : 'Valid until ${Formatters.eventDate(_validUntil!)}',
                ),
                trailing: _validUntil == null
                    ? const Icon(Icons.chevron_right)
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _validUntil = null),
                      ),
                onTap: _pickValidUntil,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: const Text('Send quote'),
              ),
            ],
          ),
        ),
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
