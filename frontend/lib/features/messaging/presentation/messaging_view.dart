import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../widgets/app_error_view.dart';
import '../../../widgets/loading_indicator.dart';
import '../../auth/application/auth_controller.dart';
import '../../bakers/application/baker_storefront_controller.dart';
import '../../orders/application/orders_controller.dart';
import '../application/messaging_controller.dart';
import '../domain/message.dart';

/// In-order chat thread between customer and baker, styled as a proper
/// messenger: sent messages on the right, received on the left, with the
/// counterparty's name, timestamps, day separators and read receipts.
class MessagingView extends ConsumerStatefulWidget {
  const MessagingView({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<MessagingView> createState() => _MessagingViewState();
}

class _MessagingViewState extends ConsumerState<MessagingView> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;
  int _lastCount = 0;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
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
    final myId = ref.watch(authControllerProvider).user?.id;
    final counterparty = _counterparty(myId);

    return Column(
      children: [
        _ChatHeader(name: counterparty.name, role: counterparty.role),
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
                return _EmptyConversation(name: counterparty.name);
              }
              // Auto-scroll to the newest message after layout.
              if (list.length != _lastCount) {
                _lastCount = list.length;
                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _scrollToBottom());
              }
              return ListView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
                children: _buildThread(list, myId, counterparty.name),
              );
            },
          ),
        ),
        _Composer(
          controller: _controller,
          sending: _sending,
          onSend: _send,
        ),
      ],
    );
  }

  /// Builds bubbles interleaved with day separators.
  List<Widget> _buildThread(List<Message> list, String? myId, String name) {
    final widgets = <Widget>[];
    DateTime? lastDay;
    for (final m in list) {
      final day = DateTime(m.createdAt.year, m.createdAt.month, m.createdAt.day);
      if (lastDay == null || day != lastDay) {
        widgets.add(_DaySeparator(label: _dayLabel(m.createdAt)));
        lastDay = day;
      }
      widgets.add(_MessageBubble(
        message: m,
        mine: myId != null && m.senderId == myId,
        counterpartyName: name,
      ));
    }
    return widgets;
  }

  /// Resolves who the current user is talking to. Customers see the baker's
  /// business name; bakers see "Customer" (no customer-name lookup yet).
  _Counterparty _counterparty(String? myId) {
    final order = ref.watch(orderDetailProvider(widget.orderId)).valueOrNull;
    if (order == null) return const _Counterparty('Conversation', '');
    final amCustomer = myId != null && order.customerId == myId;
    if (amCustomer) {
      final baker =
          ref.watch(bakerProfileProvider(order.bakerId)).valueOrNull;
      return _Counterparty(baker?.businessName ?? 'Baker', 'Baker');
    }
    return const _Counterparty('Customer', 'Customer');
  }

  String _dayLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(d.year, d.month, d.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('MMMM d, y').format(d);
  }
}

class _Counterparty {
  const _Counterparty(this.name, this.role);
  final String name;
  final String role;
}

/// A slim header showing who the conversation is with.
class _ChatHeader extends StatelessWidget {
  const _ChatHeader({required this.name, required this.role});

  final String name;
  final String role;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Text(
              _initial(name),
              style: TextStyle(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                if (role.isNotEmpty)
                  Text(role,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DaySeparator extends StatelessWidget {
  const _DaySeparator({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label,
            style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant)),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.mine,
    required this.counterpartyName,
  });

  final Message message;
  final bool mine;
  final String counterpartyName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bubbleColor = mine
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceContainerHighest;
    final textColor =
        mine ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface;
    const radius = Radius.circular(18);
    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.72,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.only(
          topLeft: radius,
          topRight: radius,
          bottomLeft: mine ? radius : const Radius.circular(4),
          bottomRight: mine ? const Radius.circular(4) : radius,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message.body, style: TextStyle(color: textColor, fontSize: 15)),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                DateFormat.jm().format(message.createdAt),
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.7),
                  fontSize: 11,
                ),
              ),
              if (mine) ...[
                const SizedBox(width: 4),
                Icon(
                  message.isRead ? Icons.done_all : Icons.done,
                  size: 15,
                  color: message.isRead
                      ? const Color(0xFF7FE0FF)
                      : textColor.withValues(alpha: 0.7),
                ),
              ],
            ],
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!mine) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: theme.colorScheme.secondaryContainer,
              child: Text(
                _initial(counterpartyName),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(child: bubble),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'Message…',
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: theme.colorScheme.primary,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: sending ? null : onSend,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: sending
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.onPrimary,
                          ),
                        )
                      : Icon(Icons.send,
                          size: 20, color: theme.colorScheme.onPrimary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyConversation extends StatelessWidget {
  const _EmptyConversation({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline,
                size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('No messages yet',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Say hello to $name to get started.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

String _initial(String name) {
  final t = name.trim();
  return t.isEmpty ? '?' : t.characters.first.toUpperCase();
}
