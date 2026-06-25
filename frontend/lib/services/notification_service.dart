import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../core/constants/api_endpoints.dart';
import '../core/errors/app_exception.dart';
import 'api_client.dart';

/// Provides the [NotificationService].
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(
    api: ref.watch(apiClientProvider),
    logger: ref.watch(loggerProvider),
  );
});

/// Wraps Firebase Cloud Messaging setup and device-token registration.
///
/// FCM is initialised lazily; the heavy lifting (requesting permissions,
/// fetching the token, wiring foreground/background handlers) is stubbed so
/// the app compiles without Firebase being configured yet.
class NotificationService {
  NotificationService({
    required ApiClient api,
    required Logger logger,
  })  : _api = api,
        _logger = logger;

  final ApiClient _api;
  final Logger _logger;

  /// Initialises messaging: request permission, get token, register handlers.
  Future<void> init() async {
    // TODO: Initialise Firebase + FirebaseMessaging, request permission,
    // listen to onMessage / onMessageOpenedApp, and call registerDeviceToken
    // with the FCM token (and on token refresh).
    _logger.d('NotificationService.init() — TODO: wire FirebaseMessaging');
  }

  /// Registers (or refreshes) the device's push token with the backend.
  Future<void> registerDeviceToken(String token) async {
    try {
      await _api.post<void>(
        ApiEndpoints.notificationDeviceTokens,
        data: {'token': token, 'platform': 'flutter'},
      );
    } on AppException catch (e) {
      _logger.w('Failed to register device token: ${e.message}');
    }
  }

  /// Removes the device token (e.g. on logout).
  Future<void> unregisterDeviceToken(String token) async {
    try {
      await _api.delete<void>(
        ApiEndpoints.notificationDeviceTokens,
        data: {'token': token},
      );
    } on AppException catch (e) {
      _logger.w('Failed to unregister device token: ${e.message}');
    }
  }
}
