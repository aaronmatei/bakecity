import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/helpers/formatters.dart';
import '../../../core/helpers/validators.dart';
import '../../../services/payment_service.dart';
import '../../../widgets/app_error_view.dart';
import '../../../widgets/loading_indicator.dart';
import '../../../widgets/primary_button.dart';
import '../../auth/application/auth_controller.dart';
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
        final settled = next.result!.status == PaymentInitStatus.sent;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              settled
                  ? 'Payment received — your order is updated.'
                  : 'STK push sent. Check your phone to approve.',
            ),
          ),
        );
        // The order advances (deposit paid / completed); refresh to reflect it.
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
        // Only the customer pays. Bakers see a read-only escrow status instead
        // of payment actions (the backend also rejects baker payments).
        final isCustomer =
            ref.watch(authControllerProvider).user?.isCustomer ?? false;
        final depositDue = o.status == OrderStatus.accepted;
        final balanceDue = o.status == OrderStatus.delivered;
        final canPay = isCustomer && (depositDue || balanceDue);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AmountsCard(order: o),
                const SizedBox(height: 16),
                if (canPay) ...[
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
                ] else if (isCustomer)
                  _StatusNote(status: o.status)
                else
                  _BakerEscrowNote(status: o.status),
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

  /// The deposit is paid once the order has advanced past acceptance.
  bool get _depositPaid => const {
        OrderStatus.depositPaid,
        OrderStatus.inProduction,
        OrderStatus.ready,
        OrderStatus.dispatched,
        OrderStatus.delivered,
        OrderStatus.completed,
      }.contains(order.status);

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
              _AmountRow(
                label: 'Deposit',
                cents: order.depositCents,
                paid: _depositPaid,
              ),
              _AmountRow(
                label: 'Balance',
                cents: order.balanceCents,
                paid: order.status == OrderStatus.completed,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({required this.label, required this.cents, this.paid = false});

  final String label;
  final int? cents;
  final bool paid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (paid) ...[
                Icon(Icons.check_circle,
                    size: 16, color: Colors.green.shade600),
                const SizedBox(width: 4),
                Text(
                  'Paid',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                cents != null ? Formatters.currencyFromCents(cents!) : '—',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Read-only escrow status shown to the baker (who never pays). Frames the same
/// order state from the baker's side: what they're waiting on or have earned.
class _BakerEscrowNote extends StatelessWidget {
  const _BakerEscrowNote({required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (IconData icon, String message) = switch (status) {
      OrderStatus.draft ||
      OrderStatus.pendingQuote ||
      OrderStatus.quoted =>
        (Icons.request_quote_outlined,
            'Send a quote and, once the customer accepts, they pay the deposit here.'),
      OrderStatus.accepted =>
        (Icons.hourglass_top_outlined,
            'Quote accepted. Waiting for the customer to pay the deposit.'),
      OrderStatus.depositPaid ||
      OrderStatus.inProduction ||
      OrderStatus.ready ||
      OrderStatus.dispatched =>
        (Icons.lock_outline,
            'Deposit secured in escrow. The balance is released to you after delivery.'),
      OrderStatus.delivered =>
        (Icons.hourglass_bottom_outlined,
            'Delivered. Waiting for the customer to pay the balance.'),
      OrderStatus.completed =>
        (Icons.check_circle_outline,
            'Paid in full. Your funds are available on the Payouts screen.'),
      OrderStatus.cancelled ||
      OrderStatus.disputed =>
        (Icons.info_outline, 'No payment is due on this order.'),
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
