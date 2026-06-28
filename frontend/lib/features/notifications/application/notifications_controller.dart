import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/api_client.dart'; // tokenStorageProvider
import '../../../services/notification_service.dart';
import '../../../services/websocket_service.dart';
import '../domain/notification.dart';

/// Loads the in-app notification feed and keeps it live: it opens the realtime
/// WebSocket and refetches whenever the server pushes an event.
final notificationsControllerProvider =
    AsyncNotifierProvider<NotificationsController, List<AppNotification>>(
  NotificationsController.new,
);

class NotificationsController extends AsyncNotifier<List<AppNotification>> {
  NotificationService get _service => ref.read(notificationServiceProvider);

  @override
  Future<List<AppNotification>> build() async {
    final token = await ref.read(tokenStorageProvider).readAccessToken();
    if (token != null && token.isNotEmpty) {
      final ws = ref.read(webSocketServiceProvider);
      await ws.connect(token: token);
      final sub = ws.events.listen((_) => _reload());
      ref.onDispose(sub.cancel);
    }
    return _service.list();
  }

  /// Re-fetches the feed (used by pull-to-refresh and realtime events).
  Future<void> refresh() => _reload();

  Future<void> _reload() async {
    state = await AsyncValue.guard(_service.list);
  }

  Future<void> markRead(String id) async {
    await _service.markRead(id);
    await _reload();
  }

  Future<void> markAllRead() async {
    await _service.markAllRead();
    await _reload();
  }
}

/// Unread badge count; recomputes when the feed changes.
final unreadNotificationsProvider = FutureProvider<int>((ref) async {
  ref.watch(notificationsControllerProvider);
  return ref.read(notificationServiceProvider).unreadCount();
});
