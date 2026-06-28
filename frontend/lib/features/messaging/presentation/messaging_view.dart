import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../widgets/app_error_view.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading_indicator.dart';
import '../application/messaging_controller.dart';

/// In-order chat thread between customer and baker.
class MessagingView extends ConsumerStatefulWidget {
  const MessagingView({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<MessagingView> createState() => _MessagingViewState();
}

class _MessagingViewState extends ConsumerState<MessagingView> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref.read(messagingControllerProvider).sendMessage(
            orderId: widget.orderId,
            body: text,
          );
      _controller.clear();
      ref.invalidate(orderMessagesProvider(widget.orderId));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(orderMessagesProvider(widget.orderId));
    return Column(
      children: [
        Expanded(
          child: messages.when(
            loading: () => const LoadingIndicator(),
            error: (e, _) => AppErrorView(
              message: e.toString(),
              onRetry: () =>
                  ref.invalidate(orderMessagesProvider(widget.orderId)),
            ),
            data: (list) {
              if (list.isEmpty) {
                return const EmptyState(
                  icon: Icons.chat_bubble_outline,
                  message: 'No messages yet. Start the conversation.',
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final m = list[i];
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(m.body),
                    ),
                  );
                },
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Type a message…',
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _sending ? null : _send,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
