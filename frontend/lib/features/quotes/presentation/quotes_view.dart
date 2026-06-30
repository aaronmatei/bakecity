import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/helpers/formatters.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../widgets/app_error_view.dart';
import '../../../widgets/loading_indicator.dart';
import '../../auth/application/auth_controller.dart';
import '../../orders/application/orders_controller.dart';
import '../../orders/presentation/order_request_details.dart';
import '../../products/application/products_controller.dart';
import '../domain/quote.dart';
import '../application/quotes_controller.dart';

/// The order's price negotiation: the customer can suggest an offer, the baker
/// quotes, the customer can counter, and the baker can send a best & final
/// offer the customer accepts.
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

  /// Both parties can negotiate while the order is still pre-acceptance.
  bool _negotiable(OrderStatus? s) =>
      s == OrderStatus.pendingQuote || s == OrderStatus.quoted;

  void _refresh() {
    ref.invalidate(orderQuotesProvider(widget.orderId));
    ref.invalidate(orderDetailProvider(widget.orderId));
  }

  // ---- Baker: send / revise a quote -------------------------------------

  /// Pre-fill the quote with the catalog price of the size the customer chose
  /// (from the order's `size` spec), so the baker starts from the right number.
  Future<double?> _suggestedAmount() async {
    final order = ref.read(orderDetailProvider(widget.orderId)).valueOrNull;
    if (order == null || order.productId == null) return null;
    String? sizeLabel;
    for (final s in order.specs) {
      if (s.key == 'size') {
        sizeLabel = s.value;
        break;
      }
    }
    if (sizeLabel == null) return null;
    try {
      final product =
          await ref.read(productDetailProvider(order.productId!).future);
      for (final sz in product.sizes) {
        if (sz.label == sizeLabel) return sz.priceCents / 100;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _openQuoteForm({required bool isUpdate}) async {
    final suggested = await _suggestedAmount();
    if (!mounted) return;
    final isDelivery =
        ref.read(orderDetailProvider(widget.orderId)).valueOrNull?.isPickup !=
            true;
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _QuoteForm(
          isUpdate: isUpdate,
          initialAmount: suggested,
          isDelivery: isDelivery,
          onSubmit: (amount, depositPct, deliveryFee, validUntil, isFinal) async {
            await ref.read(quotesControllerProvider).submitQuote(
                  orderId: widget.orderId,
                  amount: amount,
                  depositPct: depositPct,
                  deliveryFee: deliveryFee,
                  validUntil: validUntil,
                  isFinal: isFinal,
                );
            _refresh();
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

  // ---- Customer: suggest / counter an offer -----------------------------

  Future<void> _openOfferForm({required bool isCounter}) async {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _OfferForm(
          isCounter: isCounter,
          onSubmit: (amount) async {
            await ref.read(quotesControllerProvider).suggestOffer(
                  orderId: widget.orderId,
                  amount: amount,
                );
            _refresh();
          },
        ),
      ),
    );
    if (sent == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offer sent to the baker.')),
      );
    }
  }

  Future<void> _accept(Quote quote) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Accept this quote?'),
        content: Text(
          'You\'ll pay a deposit of '
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
      _refresh();
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
    final status =
        ref.watch(orderDetailProvider(widget.orderId)).valueOrNull?.status;

    return quotes.when(
      loading: () => const LoadingIndicator(),
      error: (e, _) => AppErrorView(
        message: e is AppException ? e.message : e.toString(),
        onRetry: () => ref.invalidate(orderQuotesProvider(widget.orderId)),
      ),
      data: (list) {
        final anyAccepted = list.any((q) => q.status == QuoteStatus.accepted);
        final negotiable = _negotiable(status) && !anyAccepted;
        final hasBakerQuote = list.any((q) => !q.isCustomerOffer);

        return RefreshIndicator(
          color: context.cs.primary,
          onRefresh: () async => _refresh(),
          child: ListView(
            padding: const EdgeInsets.all(Insets.screenH),
            children: [
              OrderRequestDetails(orderId: widget.orderId),
              const SizedBox(height: Insets.lg),

              // Role-specific action.
              if (_isBaker && negotiable) ...[
                FilledButton.icon(
                  onPressed: () => _openQuoteForm(isUpdate: hasBakerQuote),
                  icon: const Icon(Icons.request_quote_outlined),
                  label: Text(hasBakerQuote
                      ? 'Send an updated quote'
                      : 'Send a quote'),
                ),
                const SizedBox(height: Insets.lg),
              ],
              if (_isCustomer && negotiable) ...[
                OutlinedButton.icon(
                  onPressed: () => _openOfferForm(isCounter: hasBakerQuote),
                  icon: const Icon(Icons.handshake_outlined),
                  label: Text(hasBakerQuote
                      ? 'Counter-offer'
                      : 'Suggest your price'),
                ),
                const SizedBox(height: Insets.lg),
              ],

              if (list.isEmpty)
                _NoQuotesYet(isBaker: _isBaker)
              else
                for (final q in list) ...[
                  if (q.isCustomerOffer)
                    _OfferCard(quote: q, mine: _isCustomer)
                  else
                    _QuoteCard(
                      quote: q,
                      isLatest: q == list.first,
                      anyAccepted: anyAccepted,
                      isCustomer: _isCustomer,
                      accepting: _acceptingId == q.id,
                      busy: _acceptingId != null,
                      onAccept: () => _accept(q),
                    ),
                  const SizedBox(height: Insets.lg),
                ],
            ],
          ),
        );
      },
    );
  }
}

/// A customer's suggested price during negotiation.
class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.quote, required this.mine});
  final Quote quote;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final active = quote.status == QuoteStatus.pending;
    return Container(
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: Radii.cardBorder,
        border: active ? Border.all(color: cs.primary.withValues(alpha: 0.4)) : null,
      ),
      child: Row(
        children: [
          Icon(Icons.handshake_outlined,
              color: active ? cs.primary : cs.onSurfaceVariant),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(mine ? 'Your suggested price' : 'Customer suggested',
                    style: context.tt.labelMedium
                        ?.copyWith(color: cs.onSurfaceVariant)),
                Text(Formatters.currencyFromCents(quote.totalCents),
                    style: context.tt.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          if (!active)
            Text('Previous',
                style: context.tt.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
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
    final cs = context.cs;
    return Container(
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: Radii.cardBorder,
        boxShadow: context.bake.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                Formatters.currencyFromCents(quote.grandTotalCents),
                style: context.tt.headlineSmall,
              ),
              _StatusChip(status: quote.status, expired: _isExpired),
            ],
          ),
          if (quote.isFinal) ...[
            const SizedBox(height: Insets.sm),
            Row(
              children: [
                Icon(Icons.verified_outlined, size: 16, color: context.bake.berry),
                const SizedBox(width: 4),
                Text('Baker\'s best & final offer',
                    style: context.tt.labelMedium?.copyWith(
                        color: context.bake.berry,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ],
          const SizedBox(height: Insets.md),
          if (quote.deliveryFeeCents > 0) ...[
            _Line(
              label: 'Cake',
              value: Formatters.currencyFromCents(quote.totalCents),
            ),
            _Line(
              label: 'Delivery (courier)',
              value: Formatters.currencyFromCents(quote.deliveryFeeCents),
            ),
          ],
          _Line(
            label: 'Deposit due now',
            value: '${Formatters.currencyFromCents(quote.depositCents)}'
                '${_depositPct > 0 ? ' ($_depositPct%)' : ''}',
            emphasize: true,
          ),
          _Line(
            label: 'Balance ${quote.deliveryFeeCents > 0 ? '(incl. delivery)' : 'after delivery'}',
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
            const SizedBox(height: Insets.sm),
            Text(quote.notes!, style: context.tt.bodyMedium),
          ],
          if (_canAccept) ...[
            const SizedBox(height: Insets.lg),
            SizedBox(
              width: double.infinity,
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
            const SizedBox(height: Insets.md),
            Row(
              children: [
                Icon(Icons.check_circle, size: 18, color: context.bake.success),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Accepted — pay your deposit on the Payment tab.',
                    style: context.tt.bodySmall,
                  ),
                ),
              ],
            ),
          ] else if (isCustomer && !anyAccepted && _isExpired) ...[
            const SizedBox(height: Insets.sm),
            Text(
              'This quote is no longer valid. Ask the baker for an updated one.',
              style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ],
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: context.tt.bodyMedium
                  ?.copyWith(color: context.cs.onSurfaceVariant)),
          Text(
            value,
            style: context.tt.bodyMedium?.copyWith(
              fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Customer's simple amount-only offer form.
class _OfferForm extends StatefulWidget {
  const _OfferForm({required this.isCounter, required this.onSubmit});

  final bool isCounter;
  final Future<void> Function(double amount) onSubmit;

  @override
  State<_OfferForm> createState() => _OfferFormState();
}

class _OfferFormState extends State<_OfferForm> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(double.parse(_amount.text.trim()));
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Insets.xl),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.isCounter ? 'Counter-offer' : 'Suggest your price',
                  style: context.tt.titleLarge),
              const SizedBox(height: Insets.xs),
              Text(
                'Tell the baker the price you have in mind. They\'ll respond '
                'with a quote you can accept.',
                style: context.tt.bodySmall
                    ?.copyWith(color: context.cs.onSurfaceVariant),
              ),
              const SizedBox(height: Insets.xl),
              TextFormField(
                controller: _amount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Your price (KES)',
                  prefixIcon: Icon(Icons.handshake_outlined),
                ),
                validator: (v) {
                  final n = double.tryParse((v ?? '').trim());
                  if (n == null || n <= 0) return 'Enter a price above 0';
                  return null;
                },
              ),
              const SizedBox(height: Insets.xl),
              FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: const Text('Send offer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom-sheet form the baker uses to propose (or revise) a quote.
class _QuoteForm extends StatefulWidget {
  const _QuoteForm({
    required this.isUpdate,
    required this.onSubmit,
    this.initialAmount,
    this.isDelivery = true,
  });

  final bool isUpdate;

  /// Suggested total (KES) from the customer's chosen size, if any.
  final double? initialAmount;

  /// Whether this order is for delivery (show the courier-fee field).
  final bool isDelivery;
  final Future<void> Function(
    double amount,
    double depositPct,
    double deliveryFee,
    DateTime? validUntil,
    bool isFinal,
  ) onSubmit;

  @override
  State<_QuoteForm> createState() => _QuoteFormState();
}

class _QuoteFormState extends State<_QuoteForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount = TextEditingController(
    text: widget.initialAmount != null
        ? widget.initialAmount!.toStringAsFixed(0)
        : '',
  );
  final _depositPct = TextEditingController(text: '50');
  final _deliveryFee = TextEditingController();
  DateTime? _validUntil;
  bool _isFinal = false;
  bool _submitting = false;

  @override
  void dispose() {
    _amount.dispose();
    _depositPct.dispose();
    _deliveryFee.dispose();
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
        widget.isDelivery
            ? (double.tryParse(_deliveryFee.text.trim()) ?? 0)
            : 0,
        _validUntil,
        _isFinal,
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
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Insets.xl),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.isUpdate ? 'Send an updated quote' : 'Send a quote',
                style: context.tt.titleLarge,
              ),
              const SizedBox(height: Insets.xs),
              Text(
                'The customer reviews and accepts before paying a deposit.',
                style: context.tt.bodySmall
                    ?.copyWith(color: context.cs.onSurfaceVariant),
              ),
              const SizedBox(height: Insets.xl),
              TextFormField(
                controller: _amount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: InputDecoration(
                  labelText: 'Cake price (KES)',
                  prefixIcon: const Icon(Icons.sell_outlined),
                  helperText: widget.initialAmount != null
                      ? 'Suggested from the customer\'s chosen size — adjust as needed'
                      : null,
                ),
                validator: _validateAmount,
              ),
              const SizedBox(height: Insets.lg),
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
              if (widget.isDelivery) ...[
                const SizedBox(height: Insets.lg),
                TextFormField(
                  controller: _deliveryFee,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Delivery fee (KES)',
                    helperText: 'Courier charge added to the customer\'s balance',
                    prefixIcon: Icon(Icons.delivery_dining_outlined),
                  ),
                ),
              ],
              const SizedBox(height: Insets.sm),
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
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _isFinal,
                onChanged: (v) => setState(() => _isFinal = v),
                secondary: const Icon(Icons.verified_outlined),
                title: const Text('Best & final offer'),
                subtitle:
                    const Text('Signals to the customer that this is your last price'),
              ),
              const SizedBox(height: Insets.lg),
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

class _NoQuotesYet extends StatelessWidget {
  const _NoQuotesYet({required this.isBaker});
  final bool isBaker;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.xl),
      child: Column(
        children: [
          Icon(Icons.request_quote_outlined,
              size: 40, color: cs.onSurfaceVariant),
          const SizedBox(height: Insets.md),
          Text('No prices yet', style: context.tt.titleMedium),
          const SizedBox(height: Insets.xs),
          Text(
            isBaker
                ? 'Review the request above and send the customer a price.'
                : 'Wait for the baker\'s quote, or suggest your price above.',
            textAlign: TextAlign.center,
            style: context.tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
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
    final cs = context.cs;
    final bake = context.bake;
    final (String label, Color color) = switch (status) {
      QuoteStatus.accepted => ('Accepted', bake.success),
      QuoteStatus.pending when !expired => ('New', cs.primary),
      QuoteStatus.declined => ('Declined', cs.onSurfaceVariant),
      _ => ('Expired', cs.onSurfaceVariant),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: Radii.chipBorder,
      ),
      child: Text(
        label,
        style: context.tt.labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}
