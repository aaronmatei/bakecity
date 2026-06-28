import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/app_constants.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/baker/presentation/baker_home_screen.dart';
import '../features/customer/presentation/customer_home_screen.dart';
import '../features/discovery/presentation/discovery_screen.dart';
import '../features/notifications/presentation/notifications_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/orders/presentation/order_detail_screen.dart';
import '../features/orders/presentation/orders_list_screen.dart';
import '../features/payments/presentation/payout_screen.dart';
import '../features/products/presentation/product_detail_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import 'app_routes.dart';

/// A simple [ChangeNotifier] that GoRouter listens to. The provider body wires
/// it up to auth-state changes via `ref.listen`.
class _RouterRefreshNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}

/// Provides the application's [GoRouter].
final goRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefreshNotifier();
  ref.onDispose(refresh.dispose);

  // Re-evaluate the redirect whenever auth state changes. The subscription is
  // tied to this provider's lifetime and disposed automatically.
  ref.listen<AuthState>(
    authControllerProvider,
    (_, __) => refresh.refresh(),
  );

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final location = state.matchedLocation;
      final isAuthRoute = location == AppRoutes.login ||
          location == AppRoutes.register;
      final isSplash = location == AppRoutes.splash;

      switch (auth.status) {
        case AuthStatus.unknown:
          // Stay on splash while the session is being restored.
          return isSplash ? null : AppRoutes.splash;
        case AuthStatus.unauthenticated:
          return isAuthRoute ? null : AppRoutes.login;
        case AuthStatus.authenticated:
          if (isAuthRoute || isSplash) {
            return _homeFor(auth);
          }
          return null;
      }
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        name: AppRoutes.splashName,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        name: AppRoutes.loginName,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        name: AppRoutes.registerName,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        name: AppRoutes.onboardingName,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.customerHome,
        name: AppRoutes.customerHomeName,
        builder: (context, state) => const CustomerHomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.bakerHome,
        name: AppRoutes.bakerHomeName,
        builder: (context, state) => const BakerHomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.discovery,
        name: AppRoutes.discoveryName,
        builder: (context, state) => const DiscoveryScreen(),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        name: AppRoutes.notificationsName,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: AppRoutes.payouts,
        name: AppRoutes.payoutsName,
        builder: (context, state) => const PayoutScreen(),
      ),
      GoRoute(
        path: AppRoutes.profile,
        name: AppRoutes.profileName,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.orders,
        name: AppRoutes.ordersName,
        builder: (context, state) => const OrdersListScreen(),
      ),
      GoRoute(
        path: AppRoutes.orderDetail,
        name: AppRoutes.orderDetailName,
        builder: (context, state) => OrderDetailScreen(
          orderId: state.pathParameters['orderId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.productDetail,
        name: AppRoutes.productDetailName,
        builder: (context, state) => ProductDetailScreen(
          productId: state.pathParameters['productId']!,
        ),
      ),
    ],
  );
});

String _homeFor(AuthState auth) {
  final role = auth.user?.role;
  if (role == UserRole.baker) {
    // Route unverified bakers through onboarding first.
    if (auth.user?.bakerVerified == false) return AppRoutes.onboarding;
    return AppRoutes.bakerHome;
  }
  return AppRoutes.customerHome;
}
