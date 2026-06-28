import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/helpers/formatters.dart';
import '../../../core/helpers/validators.dart';
import '../../../widgets/primary_button.dart';
import '../application/disputes_controller.dart';
import '../domain/dispute.dart';

/// Shows an order's disputes and lets a participant raise a new one.
class DisputeView extends ConsumerStatefulWidget {
  const DisputeView({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<DisputeView> createState() => _DisputeViewState();
}

class _DisputeViewState extends ConsumerState<DisputeView> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(disputesControllerProvider).raiseDispute(
            orderId: widget.orderId,
            reason: _reasonController.text.trim(),
            description: _descriptionController.text.trim(),
          );
      _reasonController.clear();
      _descriptionController.clear();
      messenger.showSnackBar(
        const SnackBar(content: Text('Dispute submitted for review.')),
      );
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final disputes = ref.watch(orderDisputesProvider(widget.orderId));

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          disputes.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(8),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => const SizedBox.shrink(),
            data: (items) => Column(
              children: [for (final d in items) _DisputeCard(dispute: d)],
            ),
          ),
          const SizedBox(height: 8),
          Text('Raise a dispute', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextFormField(
            controller: _reasonController,
            decoration: const InputDecoration(labelText: 'Reason'),
            validator: (v) => Validators.required(v, field: 'Reason'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descriptionController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Describe the issue',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Submit dispute',
            isLoading: _submitting,
            onPressed: _submitting ? null : _submit,
          ),
        ],
      ),
    );
  }
}

class _DisputeCard extends StatelessWidget {
  const _DisputeCard({required this.dispute});

  final Dispute dispute;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.gavel_outlined),
        title: Text(dispute.reason),
        subtitle: Text(
          [
            if (dispute.resolutionNote != null) 'Resolution: ${dispute.resolutionNote}',
            Formatters.relativeTime(dispute.createdAt),
          ].join('\n'),
        ),
        isThreeLine: dispute.resolutionNote != null,
        trailing: Chip(label: Text(_statusLabel(dispute.status))),
      ),
    );
  }

  String _statusLabel(DisputeStatus s) {
    switch (s) {
      case DisputeStatus.open:
        return 'Open';
      case DisputeStatus.underReview:
        return 'Under review';
      case DisputeStatus.resolved:
        return 'Resolved';
      case DisputeStatus.rejected:
        return 'Rejected';
    }
  }
}
