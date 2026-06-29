import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/helpers/formatters.dart';
import '../../../routes/app_routes.dart';
import '../../../widgets/dashboard_widgets.dart';
import '../../auth/application/auth_controller.dart';
import '../../onboarding/application/onboarding_controller.dart';
import '../../orders/application/orders_controller.dart';
import '../../orders/domain/order.dart';
import '../../payments/application/payout_controller.dart';

/// Baker dashboard landing screen.
class BakerHomeScreen extends ConsumerStatefulWidget {
  const BakerHomeScreen({super.key});

  @override
  ConsumerState<BakerHomeScreen> createState() => _BakerHomeScreenState();
}

class _BakerHomeScreenState extends ConsumerState<BakerHomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.pushNamed(AppRoutes.notificationsName),
          ),
        ],
      ),
      body: const _BakerDashboard(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) async {
          if (i == 0) return;
          // Sections are pushed (not go) so each keeps a back button to home.
          // Highlight the tapped tab while its screen is on top, then restore
          // Dashboard when it's popped, so the bar reflects the current section.
          setState(() => _index = i);
          switch (i) {
            case 1:
              await context.pushNamed(AppRoutes.ordersName);
            case 2:
              await context.pushNamed(AppRoutes.payoutsName);
            case 3:
              await context.pushNamed(AppRoutes.profileName);
          }
          if (mounted) setState(() => _index = 0);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Earnings',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

/// Orders that need the baker to act next.
const _attentionStatuses = {
  OrderStatus.pendingQuote,
  OrderStatus.depositPaid,
  OrderStatus.inProduction,
  OrderStatus.ready,
};

class _BakerDashboard extends ConsumerWidget {
  const _BakerDashboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(onboardingControllerProvider).valueOrNull;
    final user = ref.watch(authControllerProvider).user;
    final balanceAsync = ref.watch(payoutControllerProvider);
    final ordersAsync = ref.watch(ordersControllerProvider);

    final name = (profile?.businessName.isNotEmpty ?? false)
        ? profile!.businessName
        : (user?.displayName ?? 'Your bakery');

    // Only orders placed WITH this baker — never the ones they placed as a
    // customer themselves (the list also carries those).
    final orders = (ordersAsync.valueOrNull ?? const <Order>[])
        .where((o) => o.customerId != user?.id)
        .toList();
    int countOf(OrderStatus s) => orders.where((o) => o.status == s).length;
    final attention =
        orders.where((o) => _attentionStatuses.contains(o.status)).toList();

    return RefreshIndicator(
      onRefresh: () async {
        ref.read(ordersControllerProvider.notifier).refresh();
        ref.read(payoutControllerProvider.notifier).refresh();
        ref.invalidate(onboardingControllerProvider);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _BakerGreeting(name: name, approved: profile?.isApproved ?? false),
          const SizedBox(height: 20),
          _EarningsCard(
            balance: balanceAsync,
            onWithdraw: () => context.pushNamed(AppRoutes.payoutsName),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              DashStatTile(
                value: '${countOf(OrderStatus.pendingQuote)}',
                label: 'New requests',
                icon: Icons.request_quote_outlined,
                color: const Color(0xFFEF6C00),
                onTap: () => context.pushNamed(AppRoutes.ordersName),
              ),
              const SizedBox(width: 12),
              DashStatTile(
                value: '${countOf(OrderStatus.inProduction)}',
                label: 'In production',
                icon: Icons.bakery_dining_outlined,
                color: const Color(0xFF5E35B1),
                onTap: () => context.pushNamed(AppRoutes.ordersName),
              ),
              const SizedBox(width: 12),
              DashStatTile(
                value: '${countOf(OrderStatus.completed)}',
                label: 'Completed',
                icon: Icons.check_circle_outline,
                color: const Color(0xFF2E7D32),
                onTap: () => context.pushNamed(AppRoutes.ordersName),
              ),
            ],
          ),
          const SizedBox(height: 24),
          DashSectionHeader(
            title: 'Needs your attention',
            actionLabel: orders.isEmpty ? null : 'All orders',
            onAction: () => context.pushNamed(AppRoutes.ordersName),
          ),
          const SizedBox(height: 8),
          ordersAsync.when(
            loading: () => const DashLoading(),
            error: (e, _) => DashError(
              onRetry: () =>
                  ref.read(ordersControllerProvider.notifier).refresh(),
            ),
            data: (_) {
              if (attention.isEmpty) {
                return const DashHint(
                  icon: Icons.task_alt_outlined,
                  text: 'You’re all caught up. New quote requests and orders '
                      'will appear here.',
                );
              }
              return Column(
                children: [
                  for (final o in attention.take(5))
                    OrderSummaryTile(
                      order: o,
                      onTap: () => context.pushNamed(
                        AppRoutes.orderDetailName,
                        pathParameters: {'orderId': o.id},
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BakerGreeting extends StatelessWidget {
  const _BakerGreeting({required this.name, required this.approved});

  final String name;
  final bool approved;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(Icons.storefront,
              color: theme.colorScheme.onPrimaryContainer),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              _VerificationChip(approved: approved),
            ],
          ),
        ),
      ],
    );
  }
}

class _VerificationChip extends StatelessWidget {
  const _VerificationChip({required this.approved});

  final bool approved;

  @override
  Widget build(BuildContext context) {
    final color = approved ? const Color(0xFF2E7D32) : const Color(0xFFEF6C00);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(approved ? Icons.verified : Icons.hourglass_top,
              size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            approved ? 'Verified baker' : 'Verification pending',
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _EarningsCard extends StatelessWidget {
  const _EarningsCard({required this.balance, required this.onWithdraw});

  final AsyncValue balance;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onCol = theme.colorScheme.onPrimary;
    final available = balance.valueOrNull?.available ?? 0.0;
    final pending = balance.valueOrNull?.pending ?? 0.0;
    final paidOut = balance.valueOrNull?.paidOut ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withValues(alpha: 0.78),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined, color: onCol, size: 18),
              const SizedBox(width: 6),
              Text('Available to withdraw',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: onCol.withValues(alpha: 0.9))),
            ],
          ),
          const SizedBox(height: 6),
          balance.isLoading
              ? SizedBox(
                  height: 36,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child:
                          CircularProgressIndicator(strokeWidth: 2, color: onCol),
                    ),
                  ),
                )
              : Text(
                  Formatters.currency(available),
                  style: theme.textTheme.headlineMedium
                      ?.copyWith(color: onCol, fontWeight: FontWeight.bold),
                ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                    label: 'In escrow',
                    value: Formatters.currency(pending),
                    onColor: onCol),
              ),
              Expanded(
                child: _MiniStat(
                    label: 'Paid out',
                    value: Formatters.currency(paidOut),
                    onColor: onCol),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: onWithdraw,
              style: FilledButton.styleFrom(
                backgroundColor: onCol,
                foregroundColor: theme.colorScheme.primary,
              ),
              icon: const Icon(Icons.payments_outlined),
              label: const Text('Withdraw earnings'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.onColor,
  });

  final String label;
  final String value;
  final Color onColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: onColor.withValues(alpha: 0.85))),
        const SizedBox(height: 2),
        Text(value,
            style: theme.textTheme.titleMedium
                ?.copyWith(color: onColor, fontWeight: FontWeight.w700)),
      ],
    );
  }
}
