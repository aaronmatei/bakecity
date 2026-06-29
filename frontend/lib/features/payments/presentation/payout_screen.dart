import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/helpers/formatters.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../widgets/app_error_view.dart';
import '../../../widgets/loading_indicator.dart';
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
        error: (e, _) =>
            AppErrorView(message: e.toString(), onRetry: controller.refresh),
        data: (balance) => RefreshIndicator(
          color: context.cs.primary,
          onRefresh: controller.refresh,
          child: ListView(
            padding: const EdgeInsets.all(Insets.screenH),
            children: [
              _EarningsHero(
                available: balance.available,
                canWithdraw: balance.available > 0,
                onWithdraw: () => _withdraw(context, ref),
              ),
              const SizedBox(height: Insets.lg),
              Row(
                children: [
                  Expanded(
                    child: _MiniStat(
                      icon: Icons.lock_clock_outlined,
                      label: 'Held in escrow',
                      value: Formatters.currency(balance.pending),
                    ),
                  ),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: _MiniStat(
                      icon: Icons.history,
                      label: 'Paid out to date',
                      value: Formatters.currency(balance.paidOut),
                    ),
                  ),
                ],
              ),
              if (balance.available <= 0)
                Padding(
                  padding: const EdgeInsets.only(top: Insets.lg),
                  child: Text(
                    'No funds available yet. Earnings are released once an '
                    'order is completed.',
                    textAlign: TextAlign.center,
                    style: context.tt.bodySmall
                        ?.copyWith(color: context.cs.onSurfaceVariant),
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
              'Payout ${res.status}: ${Formatters.currency(res.amount)}'),
        ),
      );
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

class _EarningsHero extends StatelessWidget {
  const _EarningsHero({
    required this.available,
    required this.canWithdraw,
    required this.onWithdraw,
  });

  final double available;
  final bool canWithdraw;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final onCol = cs.onPrimary;
    return Container(
      padding: const EdgeInsets.all(Insets.xl),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.cardLg),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cs.primary, cs.primary.withValues(alpha: 0.78)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined,
                  color: onCol, size: 18),
              const SizedBox(width: 6),
              Text('Available to withdraw',
                  style: context.tt.bodyMedium
                      ?.copyWith(color: onCol.withValues(alpha: 0.9))),
            ],
          ),
          const SizedBox(height: Insets.sm),
          Text(
            Formatters.currency(available),
            style: context.tt.displaySmall
                ?.copyWith(color: onCol, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: Insets.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: canWithdraw ? onWithdraw : null,
              style: FilledButton.styleFrom(
                backgroundColor: onCol,
                foregroundColor: cs.primary,
                disabledBackgroundColor: onCol.withValues(alpha: 0.4),
              ),
              icon: const Icon(Icons.payments_outlined),
              label: const Text('Withdraw available'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

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
          Icon(icon, size: 20, color: cs.onSurfaceVariant),
          const SizedBox(height: Insets.md),
          Text(value,
              style: context.tt.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          Text(label,
              style: context.tt.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}
