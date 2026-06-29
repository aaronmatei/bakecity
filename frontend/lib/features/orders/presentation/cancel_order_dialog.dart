import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/helpers/formatters.dart';
import '../application/orders_controller.dart';
import '../domain/order.dart';

/// Order states a cancel affordance is offered in, per role. Mirrors the
/// backend §7 rules: a customer may cancel through IN_PRODUCTION; a baker (who
/// can't fulfil) may cancel any pre-delivery stage. Later states require a
/// dispute instead, so we don't offer a cancel there.
const _customerCancellable = {
  OrderStatus.draft,
  OrderStatus.pendingQuote,
  OrderStatus.quoted,
  OrderStatus.accepted,
  OrderStatus.depositPaid,
  OrderStatus.inProduction,
};
const _bakerCancellable = {
  ..._customerCancellable,
  OrderStatus.ready,
  OrderStatus.dispatched,
};

/// Whether to show a cancel affordance for [status] given the caller's role.
bool orderCancellable(OrderStatus status, {required bool isCustomer}) =>
    (isCustomer ? _customerCancellable : _bakerCancellable).contains(status);

/// Estimated refund to the customer (in cents) for cancelling [order] now,
/// given the caller's role. The backend's refund matrix is the source of
/// truth; this is only a preview so the customer isn't surprised. Returns null
/// when no escrow is held yet (cancelling is free).
int? estimatedRefundCents(Order order, {required bool isCustomer}) {
  const held = {
    OrderStatus.depositPaid,
    OrderStatus.inProduction,
    OrderStatus.ready,
    OrderStatus.dispatched,
  };
  final deposit = order.depositCents;
  if (deposit == null || deposit <= 0 || !held.contains(order.status)) {
    return null; // no escrow held — nothing to refund
  }
  if (!isCustomer) return deposit; // baker/admin cancel → customer made whole
  if (order.status == OrderStatus.inProduction) {
    return (deposit * 0.5).round(); // production started — 50% forfeited
  }
  return (deposit * 0.9).round(); // before production — 10% processing fee
}

/// Confirms and performs an order cancellation, explaining the refund up front
/// and surfacing the result via a snackbar.
Future<void> showCancelOrderDialog(
  BuildContext context,
  WidgetRef ref,
  Order order, {
  required bool isCustomer,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final refund = estimatedRefundCents(order, isCustomer: isCustomer);
  final deposit = order.depositCents ?? 0;

  final String explanation;
  if (refund == null) {
    explanation = isCustomer
        ? 'No deposit has been paid yet, so cancelling costs you nothing.'
        : 'No deposit is held yet, so cancelling costs nothing.';
  } else if (!isCustomer) {
    explanation =
        'The customer will be fully refunded ${Formatters.currencyFromCents(refund)}.';
  } else if (order.status == OrderStatus.inProduction) {
    explanation =
        'Production has started, so half of your ${Formatters.currencyFromCents(deposit)} '
        'deposit is kept for work done. You\'ll be refunded about '
        '${Formatters.currencyFromCents(refund)}.';
  } else {
    explanation =
        'You\'ll be refunded about ${Formatters.currencyFromCents(refund)} of your '
        '${Formatters.currencyFromCents(deposit)} deposit (a 10% processing fee applies).';
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Cancel this order?'),
      content: Text('$explanation\n\nThis can\'t be undone.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Keep order'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(ctx).colorScheme.error,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Cancel order'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;

  try {
    await ref.read(ordersControllerProvider.notifier).cancelOrder(order.id);
    messenger.showSnackBar(const SnackBar(content: Text('Order cancelled.')));
  } on AppException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Could not cancel the order.')),
    );
  }
}
