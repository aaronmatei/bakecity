import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/helpers/formatters.dart';
import '../../../widgets/app_error_view.dart';
import '../../../widgets/loading_indicator.dart';
import '../../../widgets/primary_button.dart';
import '../application/payout_controller.dart';

/// Baker earnings + payout screen (available / held / paid-out balances).
class PayoutScreen extends ConsumerWidget {
  const PayoutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(payoutControllerProvider);
    final controller = ref.read(payoutControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Earnings & payouts')),
      body: async.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => AppErrorView(
          message: e.toString(),
          onRetry: controller.refresh,
        ),
        data: (balance) => RefreshIndicator(
          onRefresh: controller.refresh,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _StatCard(
                label: 'Available to withdraw',
                value: Formatters.currency(balance.available),
                highlight: true,
              ),
              const SizedBox(height: 12),
              _StatCard(
                label: 'Held in escrow',
                value: Formatters.currency(balance.pending),
              ),
              const SizedBox(height: 12),
              _StatCard(
                label: 'Paid out to date',
                value: Formatters.currency(balance.paidOut),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Withdraw available',
                icon: Icons.account_balance_wallet_outlined,
                onPressed: balance.available > 0
                    ? () => _withdraw(context, ref)
                    : null,
              ),
              if (balance.available <= 0)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'No funds available yet. Earnings are released once an '
                    'order is completed.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _withdraw(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final res = await ref.read(payoutControllerProvider.notifier).withdraw();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Payout ${res.status}: ${Formatters.currency(res.amount)}',
          ),
        ),
      );
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: highlight ? theme.colorScheme.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: highlight ? theme.colorScheme.onPrimaryContainer : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
