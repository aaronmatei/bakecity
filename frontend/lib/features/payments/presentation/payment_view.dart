import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/helpers/formatters.dart';
import '../../../core/helpers/validators.dart';
import '../../../widgets/app_error_view.dart';
import '../../../widgets/loading_indicator.dart';
import '../../../widgets/primary_button.dart';
import '../../orders/application/orders_controller.dart';
import '../../orders/domain/order.dart';
import '../application/payments_controller.dart';

/// Escrow deposit + balance payment view for an order. Shows what's due, and
/// only enables the action that matches the order's current state (deposit when
/// a quote is accepted; balance after delivery).
class PaymentView extends ConsumerStatefulWidget {
  const PaymentView({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<PaymentView> createState() => _PaymentViewState();
}

class _PaymentViewState extends ConsumerState<PaymentView> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pay(
    Future<void> Function({required String orderId, required String phone}) action,
  ) async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await action(orderId: widget.orderId, phone: _phoneController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final order = ref.watch(orderDetailProvider(widget.orderId));
    final state = ref.watch(paymentsControllerProvider);
    final controller = ref.read(paymentsControllerProvider.notifier);

    ref.listen<PaymentState>(paymentsControllerProvider, (previous, next) {
      if (next.errorMessage != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(next.errorMessage!)));
      } else if (next.result != null && previous?.result != next.result) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('STK push sent. Check your phone to approve.'),
          ),
        );
        // The order advances (e.g. to DEPOSIT_PENDING); refresh to reflect it.
        ref.invalidate(orderDetailProvider(widget.orderId));
      }
    });

    return order.when(
      loading: () => const LoadingIndicator(),
      error: (e, _) => AppErrorView(
        message: e is AppException ? e.message : e.toString(),
        onRetry: () => ref.invalidate(orderDetailProvider(widget.orderId)),
      ),
      data: (o) {
        final depositDue = o.status == OrderStatus.accepted;
        final balanceDue = o.status == OrderStatus.delivered;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AmountsCard(order: o),
                const SizedBox(height: 16),
                if (depositDue || balanceDue) ...[
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'M-Pesa phone number',
                      hintText: '+2547…',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    validator: Validators.phone,
                  ),
                  const SizedBox(height: 16),
                  if (depositDue)
                    PrimaryButton(
                      label: 'Pay deposit'
                          '${_amountSuffix(o.depositCents)}',
                      icon: Icons.lock_outline,
                      isLoading: state.isProcessing,
                      onPressed: () => _pay(controller.payDeposit),
                    ),
                  if (balanceDue)
                    PrimaryButton(
                      label: 'Pay balance'
                          '${_amountSuffix(o.balanceCents)}',
                      icon: Icons.payments_outlined,
                      isLoading: state.isProcessing,
                      onPressed: () => _pay(controller.payBalance),
                    ),
                ] else
                  _StatusNote(status: o.status),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _amountSuffix(int? cents) =>
      cents != null && cents > 0 ? ' — ${Formatters.currencyFromCents(cents)}' : '';
}

/// Summary of the order's escrow amounts. Amounts are populated once a quote is
/// accepted.
class _AmountsCard extends StatelessWidget {
  const _AmountsCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasAmounts = (order.totalCents ?? 0) > 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Payment summary', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            if (!hasAmounts)
              Text(
                'Amounts appear once you accept a quote from the baker.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else ...[
              _AmountRow(label: 'Total', cents: order.totalCents),
              _AmountRow(label: 'Deposit', cents: order.depositCents),
              _AmountRow(label: 'Balance', cents: order.balanceCents),
            ],
          ],
        ),
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({required this.label, required this.cents});

  final String label;
  final int? cents;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            cents != null ? Formatters.currencyFromCents(cents!) : '—',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Explains why no payment action is available in the order's current state.
class _StatusNote extends StatelessWidget {
  const _StatusNote({required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (IconData icon, String message) = switch (status) {
      OrderStatus.draft ||
      OrderStatus.pendingQuote ||
      OrderStatus.quoted =>
        (Icons.request_quote_outlined,
            'Accept a quote from the baker to pay your deposit.'),
      OrderStatus.depositPaid ||
      OrderStatus.inProduction ||
      OrderStatus.ready ||
      OrderStatus.dispatched =>
        (Icons.hourglass_top_outlined,
            'Deposit paid. The balance is due once your order is delivered.'),
      OrderStatus.completed =>
        (Icons.check_circle_outline, 'This order is fully paid. Thank you!'),
      OrderStatus.cancelled ||
      OrderStatus.disputed =>
        (Icons.info_outline, 'No payment is due on this order.'),
      _ => (Icons.info_outline, 'No payment is due right now.'),
    };

    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}
