import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/helpers/formatters.dart';
import '../../../widgets/app_error_view.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading_indicator.dart';
import '../../auth/application/auth_controller.dart';
import '../../disputes/domain/dispute.dart';
import '../application/admin_controller.dart';

/// Admin/ops console: platform overview, baker approvals, and dispute
/// resolution.
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin console'),
          actions: [
            IconButton(
              tooltip: 'Sign out',
              icon: const Icon(Icons.logout),
              onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Bakers'),
              Tab(text: 'Disputes'),
              Tab(text: 'Refund'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_OverviewTab(), _BakersTab(), _DisputesTab(), _RefundTab()],
        ),
      ),
    );
  }
}

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(adminAnalyticsProvider);
    return stats.when(
      loading: () => const LoadingIndicator(),
      error: (e, _) => AppErrorView(
        message: e.toString(),
        onRetry: () => ref.invalidate(adminAnalyticsProvider),
      ),
      data: (s) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(adminAnalyticsProvider),
        child: GridView.count(
          padding: const EdgeInsets.all(16),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: [
            _StatTile(label: 'Total orders', value: '${s.totalOrders}'),
            _StatTile(label: 'Completed', value: '${s.completedOrders}'),
            _StatTile(label: 'GMV', value: Formatters.currency(s.gmv)),
            _StatTile(
              label: 'Platform revenue',
              value: Formatters.currency(s.platformRevenue),
            ),
            _StatTile(label: 'Active bakers', value: '${s.activeBakers}'),
            _StatTile(label: 'Open disputes', value: '${s.openDisputes}'),
          ],
        ),
      ),
    );
  }
}

class _BakersTab extends ConsumerWidget {
  const _BakersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bakers = ref.watch(pendingBakersProvider);
    return bakers.when(
      loading: () => const LoadingIndicator(),
      error: (e, _) => AppErrorView(
        message: e.toString(),
        onRetry: () => ref.invalidate(pendingBakersProvider),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const EmptyState(
            icon: Icons.verified_outlined,
            message: 'No bakers awaiting approval.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(pendingBakersProvider),
          child: ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final b = items[i];
              return ListTile(
                title: Text(b.businessName),
                subtitle: Text('${b.phone} • KYC: ${b.kycStatus}'),
                trailing: FilledButton(
                  onPressed: () => _approve(context, ref, b.id),
                  child: const Text('Approve'),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _approve(BuildContext context, WidgetRef ref, String id) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(adminControllerProvider).approveBaker(id);
      messenger.showSnackBar(const SnackBar(content: Text('Baker approved.')));
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

class _DisputesTab extends ConsumerWidget {
  const _DisputesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final disputes = ref.watch(adminDisputesProvider);
    return disputes.when(
      loading: () => const LoadingIndicator(),
      error: (e, _) => AppErrorView(
        message: e.toString(),
        onRetry: () => ref.invalidate(adminDisputesProvider),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const EmptyState(
            icon: Icons.gavel_outlined,
            message: 'No open disputes.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(adminDisputesProvider),
          child: ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final d = items[i];
              return ListTile(
                title: Text(d.reason),
                subtitle: Text(
                  'Order ${d.orderId} • ${Formatters.relativeTime(d.createdAt)}',
                ),
                trailing: TextButton(
                  onPressed: () => _resolve(context, ref, d),
                  child: const Text('Resolve'),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _resolve(BuildContext context, WidgetRef ref, Dispute d) async {
    final resolutionCtrl = TextEditingController();
    final refundCtrl = TextEditingController(text: '0');
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Resolve dispute'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: resolutionCtrl,
              decoration: const InputDecoration(labelText: 'Resolution note'),
            ),
            TextField(
              controller: refundCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Refund to customer (KES)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Resolve'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(adminControllerProvider).resolveDispute(
              d.id,
              resolution: resolutionCtrl.text.trim(),
              refundAmount: double.tryParse(refundCtrl.text.trim()) ?? 0,
            );
        messenger.showSnackBar(const SnackBar(content: Text('Dispute resolved.')));
      } on AppException catch (e) {
        messenger.showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
    resolutionCtrl.dispose();
    refundCtrl.dispose();
  }
}

class _RefundTab extends ConsumerStatefulWidget {
  const _RefundTab();

  @override
  ConsumerState<_RefundTab> createState() => _RefundTabState();
}

class _RefundTabState extends ConsumerState<_RefundTab> {
  final _orderIdController = TextEditingController();
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _orderIdController.dispose();
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final orderId = _orderIdController.text.trim();
    final amount = double.tryParse(_amountController.text.trim());
    final messenger = ScaffoldMessenger.of(context);
    if (orderId.isEmpty || amount == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Enter an order id and amount.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(adminControllerProvider).refundOrder(
            orderId,
            amount: amount,
            reason: _reasonController.text.trim(),
          );
      _orderIdController.clear();
      _amountController.clear();
      _reasonController.clear();
      messenger.showSnackBar(const SnackBar(content: Text('Refund processed.')));
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Refund a cancelled order',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Returns the held deposit to the customer and marks the order '
          'refunded. Disputed orders are settled from the Disputes tab.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _orderIdController,
          decoration: const InputDecoration(labelText: 'Order ID'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Refund amount (KES)'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _reasonController,
          decoration: const InputDecoration(labelText: 'Reason (optional)'),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _submitting ? null : _submit,
          icon: const Icon(Icons.payments_outlined),
          label: Text(_submitting ? 'Processing…' : 'Process refund'),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.labelMedium),
            const SizedBox(height: 6),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
