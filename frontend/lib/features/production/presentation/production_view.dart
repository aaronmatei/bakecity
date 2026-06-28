import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/helpers/formatters.dart';
import '../../auth/application/auth_controller.dart';
import '../../../widgets/app_error_view.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading_indicator.dart';
import '../../../widgets/primary_button.dart';
import '../application/production_controller.dart';

/// Production timeline for an order. The baker posts stage updates; everyone
/// sees the chronological timeline.
class ProductionView extends ConsumerStatefulWidget {
  const ProductionView({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<ProductionView> createState() => _ProductionViewState();
}

class _ProductionViewState extends ConsumerState<ProductionView> {
  final _stageController = TextEditingController();
  final _notesController = TextEditingController();
  double _progress = 0;
  bool _submitting = false;

  @override
  void dispose() {
    _stageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final stage = _stageController.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    if (stage.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Enter a stage name.')));
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(productionControllerProvider).addUpdate(
            orderId: widget.orderId,
            stage: stage,
            progressPct: _progress.round(),
            notes: _notesController.text.trim(),
          );
      _stageController.clear();
      _notesController.clear();
      setState(() => _progress = 0);
      messenger.showSnackBar(const SnackBar(content: Text('Update posted.')));
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final updates = ref.watch(orderProductionProvider(widget.orderId));
    final isBaker =
        ref.watch(authControllerProvider).user?.role == UserRole.baker;

    return Column(
      children: [
        Expanded(
          child: updates.when(
            loading: () => const LoadingIndicator(),
            error: (e, _) => AppErrorView(
              message: e.toString(),
              onRetry: () =>
                  ref.invalidate(orderProductionProvider(widget.orderId)),
            ),
            data: (items) {
              if (items.isEmpty) {
                return const EmptyState(
                  icon: Icons.timeline_outlined,
                  message: 'Production has not started yet.',
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final u = items[i];
                  final hasNotes = u.notes != null && u.notes!.isNotEmpty;
                  return ListTile(
                    leading: CircleAvatar(child: Text('${u.progressPct}%')),
                    title: Text(u.stage),
                    subtitle: Text(
                      [
                        if (hasNotes) u.notes!,
                        Formatters.relativeTime(u.createdAt),
                      ].join('\n'),
                    ),
                    isThreeLine: hasNotes,
                  );
                },
              );
            },
          ),
        ),
        if (isBaker) _composer(),
      ],
    );
  }

  Widget _composer() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _stageController,
              decoration: const InputDecoration(
                labelText: 'Stage (e.g. Baking, Decorating)',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
            Row(
              children: [
                Text('Progress: ${_progress.round()}%'),
                Expanded(
                  child: Slider(
                    value: _progress,
                    max: 100,
                    divisions: 20,
                    label: '${_progress.round()}%',
                    onChanged: _submitting
                        ? null
                        : (v) => setState(() => _progress = v),
                  ),
                ),
              ],
            ),
            PrimaryButton(
              label: 'Post update',
              icon: Icons.add_outlined,
              isLoading: _submitting,
              onPressed: _submitting ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
