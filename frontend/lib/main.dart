import 'dart:async';

import 'package:device_preview/device_preview.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/storage/token_storage.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/application/auth_controller.dart';
import 'firebase_options.dart';
import 'routes/app_router.dart';
import 'routes/app_routes.dart';
import 'services/api_client.dart';
import 'services/notification_service.dart';

/// Handles push messages delivered while the app is backgrounded or terminated.
/// Must be a top-level function and re-initialise Firebase, since it runs in its
/// own isolate. Kept minimal — tapping the notification routes via
/// [FirebaseMessaging.onMessageOpenedApp] / `getInitialMessage` once the app
/// resumes.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  // Firebase isn't configured for every platform (e.g. the web/device_preview
  // build), so initialise best-effort and continue if it's unavailable.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );
    }
  } catch (_) {
    // Continue without Firebase (preview / unsupported platform).
  }

  // Token storage requires async initialisation; inject the ready instance.
  final tokenStorage = await TokenStorage.create();

  // device_preview wraps the app in selectable device frames (iPhone, etc.) for
  // previewing on any host. Enabled only with --dart-define=DEVICE_PREVIEW=true,
  // so normal runs are unaffected.
  const devicePreviewEnabled = bool.fromEnvironment('DEVICE_PREVIEW');

  runApp(
    DevicePreview(
      enabled: devicePreviewEnabled,
      builder: (context) => ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(tokenStorage),
        ],
        child: const BakeCityApp(),
      ),
    ),
  );
}

class BakeCityApp extends ConsumerStatefulWidget {
  const BakeCityApp({super.key});

  @override
  ConsumerState<BakeCityApp> createState() => _BakeCityAppState();
}

class _BakeCityAppState extends ConsumerState<BakeCityApp> {
  ProviderSubscription<AuthState>? _authSub;
  StreamSubscription<RemoteMessage>? _tapSub;

  @override
  void initState() {
    super.initState();

    // Initialise / tear down push messaging with the auth session. The token
    // registration call is authed, so it must run only once signed in.
    // `fireImmediately` covers a session restored before the first build.
    _authSub = ref.listenManual<AuthState>(
      authControllerProvider,
      (prev, next) {
        final service = ref.read(notificationServiceProvider);
        final was = prev?.status == AuthStatus.authenticated;
        final now = next.status == AuthStatus.authenticated;
        if (now && !was) {
          service.init().then((_) => _routeInitialMessage());
        } else if (!now && was) {
          service.unregister();
        }
      },
      fireImmediately: true,
    );

    // Route taps on notifications opened while the app was backgrounded.
    _tapSub = ref
        .read(notificationServiceProvider)
        .onNotificationTap
        .listen((_) => _goToNotifications());
  }

  /// Cold-start: if the app was launched by tapping a push, jump to the feed
  /// once the router exists.
  void _routeInitialMessage() {
    final message = ref.read(notificationServiceProvider).consumeInitialMessage();
    if (message != null) {
      _goToNotifications();
    }
  }

  void _goToNotifications() {
    if (!mounted) return;
    ref.read(goRouterProvider).goNamed(AppRoutes.notificationsName);
  }

  @override
  void dispose() {
    _authSub?.close();
    _tapSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      // device_preview hooks (no-ops unless the preview is enabled).
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
