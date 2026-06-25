import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/helpers/validators.dart';
import '../../../widgets/primary_button.dart';
import '../application/disputes_controller.dart';

/// Lets a user raise a dispute against an order.
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
    try {
      await ref.read(disputesControllerProvider).raiseDispute(
            orderId: widget.orderId,
            reason: _reasonController.text.trim(),
            description: _descriptionController.text.trim(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dispute submitted for review.')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
