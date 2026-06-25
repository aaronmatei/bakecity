import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../widgets/empty_state.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      // TODO: Load from ApiEndpoints.notifications and render a list.
      body: const EmptyState(
        icon: Icons.notifications_none,
        message: "You're all caught up.",
      ),
    );
  }
}
