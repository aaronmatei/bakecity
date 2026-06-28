import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
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

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Emits whenever the user taps a push notification (foreground-opened or
  /// from the background). The app listens and routes to the relevant screen.
  final StreamController<RemoteMessage> _tapController =
      StreamController<RemoteMessage>.broadcast();
  final List<StreamSubscription<dynamic>> _subs = [];

  bool _initialized = false;
  String? _token;
  RemoteMessage? _initialMessage;

  /// Tap events for notifications opened while the app was running/backgrounded.
  Stream<RemoteMessage> get onNotificationTap => _tapController.stream;

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

  /// Initialises push messaging (FCM) for the signed-in user: requests
  /// permission, registers this device's token with the backend, and wires the
  /// foreground / tap handlers. Idempotent — safe to call on every login.
  ///
  /// Realtime in-app delivery still runs over the WebSocket (see
  /// [WebSocketService]); FCM is the out-of-band transport for when the app is
  /// backgrounded or closed.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final settings = await _messaging.requestPermission();
      _logger.d('FCM permission: ${settings.authorizationStatus}');

      // Show heads-up notifications while the app is foregrounded (iOS/web).
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      _token = await _messaging.getToken();
      if (_token != null) {
        await _registerToken(_token!);
      }

      // Token rotation: re-register whenever FCM issues a new token.
      _subs.add(_messaging.onTokenRefresh.listen((token) {
        _token = token;
        _registerToken(token);
      }));

      // Foreground delivery. The WebSocket already refreshes the in-app feed;
      // here we just log so the push path is observable in development.
      _subs.add(FirebaseMessaging.onMessage.listen((message) {
        _logger.d(
          'FCM foreground: ${message.messageId} '
          '${message.notification?.title}',
        );
      }));

      // App opened from background by tapping a notification.
      _subs.add(FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _logger.d('FCM opened from background: ${message.messageId}');
        _tapController.add(message);
      }));

      // Cold start: app launched from terminated by tapping a notification.
      // Stashed for the app to consume once the router is ready.
      _initialMessage = await _messaging.getInitialMessage();
    } catch (e, st) {
      _logger.w('FCM init failed: $e', error: e, stackTrace: st);
      _initialized = false; // allow a later retry
    }
  }

  /// Returns and clears any notification that cold-started the app (the user
  /// tapped a push while the app was terminated). One-shot.
  RemoteMessage? consumeInitialMessage() {
    final message = _initialMessage;
    _initialMessage = null;
    return message;
  }

  /// Tears down FCM handlers and removes this device's token from the backend
  /// (e.g. on logout) so it stops receiving push for the previous user.
  Future<void> unregister() async {
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();
    _initialized = false;

    final token = _token;
    _token = null;
    if (token == null) return;
    try {
      await _api.delete<void>(
        ApiEndpoints.notificationDevices,
        data: {'token': token},
      );
    } catch (e) {
      _logger.w('FCM token unregister failed: $e');
    }
  }

  Future<void> _registerToken(String token) async {
    try {
      await _api.post<void>(
        ApiEndpoints.notificationDevices,
        data: {'token': token, 'platform': _platformName()},
      );
      _logger.d('FCM token registered');
    } catch (e) {
      _logger.w('FCM token registration failed: $e');
    }
  }

  String _platformName() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }
}
