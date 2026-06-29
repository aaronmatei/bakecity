import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/helpers/formatters.dart';
import '../../../core/helpers/validators.dart';
import '../../../core/theme/app_tokens.dart';
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
        padding: const EdgeInsets.all(Insets.screenH),
        children: [
          disputes.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(Insets.sm),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => const SizedBox.shrink(),
            data: (items) => Column(
              children: [
                for (final d in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Insets.md),
                    child: _DisputeCard(dispute: d),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Insets.sm),
          Text('Raise a dispute', style: context.tt.titleLarge),
          const SizedBox(height: Insets.xs),
          Text(
            'If something went wrong, tell us and our team will review it.',
            style: context.tt.bodySmall
                ?.copyWith(color: context.cs.onSurfaceVariant),
          ),
          const SizedBox(height: Insets.lg),
          TextFormField(
            controller: _reasonController,
            decoration: const InputDecoration(labelText: 'Reason'),
            validator: (v) => Validators.required(v, field: 'Reason'),
          ),
          const SizedBox(height: Insets.lg),
          TextFormField(
            controller: _descriptionController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Describe the issue',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: Insets.xl),
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
            children: [
              Icon(Icons.gavel_outlined, size: 20, color: cs.onSurfaceVariant),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: Text(dispute.reason,
                    style: context.tt.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
              _StatusPill(status: dispute.status),
            ],
          ),
          if (dispute.resolutionNote != null) ...[
            const SizedBox(height: Insets.sm),
            Text('Resolution: ${dispute.resolutionNote}',
                style: context.tt.bodyMedium),
          ],
          const SizedBox(height: Insets.sm),
          Text(
            Formatters.relativeTime(dispute.createdAt),
            style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final DisputeStatus status;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final bake = context.bake;
    final (String label, Color color) = switch (status) {
      DisputeStatus.open => ('Open', bake.berry),
      DisputeStatus.underReview => ('Under review', cs.primary),
      DisputeStatus.resolved => ('Resolved', bake.success),
      DisputeStatus.rejected => ('Rejected', cs.onSurfaceVariant),
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
