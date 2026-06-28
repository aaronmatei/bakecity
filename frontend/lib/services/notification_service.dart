import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../core/constants/api_endpoints.dart';
import '../features/notifications/domain/notification.dart';
import 'api_client.dart';

/// Provides the [NotificationService].
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(
    api: ref.watch(apiClientProvider),
    logger: ref.watch(loggerProvider),
  );
});

/// Reads the in-app notification feed and manages read state. Realtime delivery
/// arrives over the WebSocket (see [WebSocketService]); push (FCM) is a separate
/// transport that the backend fans out server-side.
class NotificationService {
  NotificationService({
    required ApiClient api,
    required Logger logger,
  })  : _api = api,
        _logger = logger;

  final ApiClient _api;
  final Logger _logger;

  /// Lists the current user's notifications, newest first.
  Future<List<AppNotification>> list({
    bool unreadOnly = false,
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _api.get<Map<String, dynamic>>(
      ApiEndpoints.notifications,
      queryParameters: {
        if (unreadOnly) 'unread': 'true',
        'limit': limit,
        'offset': offset,
      },
    );
    final items = (response.data?['notifications'] ?? const []) as List;
    return items
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Returns the count of unread notifications.
  Future<int> unreadCount() async {
    final response = await _api
        .get<Map<String, dynamic>>(ApiEndpoints.notificationsUnreadCount);
    return (response.data?['unread'] as num?)?.toInt() ?? 0;
  }

  /// Marks a single notification read.
  Future<void> markRead(String id) async {
    await _api.post<void>(ApiEndpoints.notificationRead(id));
  }

  /// Marks all of the user's notifications read; returns the count updated.
  Future<int> markAllRead() async {
    final response = await _api
        .post<Map<String, dynamic>>(ApiEndpoints.notificationsReadAll);
    return (response.data?['marked_read'] as num?)?.toInt() ?? 0;
  }

  /// Initialises push messaging (FCM). Stubbed until Firebase is configured;
  /// the backend already fans push/SMS out server-side, and realtime in-app
  /// delivery runs over the WebSocket.
  Future<void> init() async {
    _logger.d('NotificationService.init() — TODO: wire FirebaseMessaging');
  }
}
