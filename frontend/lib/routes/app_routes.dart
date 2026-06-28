/// Named route paths and names used by the GoRouter configuration.
class AppRoutes {
  const AppRoutes._();

  // Top-level paths.
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String onboarding = '/onboarding';

  static const String customerHome = '/home';
  static const String bakerHome = '/baker';
  static const String adminHome = '/admin';
  static const String discovery = '/discovery';
  static const String notifications = '/notifications';
  static const String payouts = '/payouts';
  static const String profile = '/profile';

  // Parameterised.
  static const String productDetail = '/products/:productId';
  static const String orders = '/orders';
  static const String orderDetail = '/orders/:orderId';

  // Route names (for `goNamed`).
  static const String splashName = 'splash';
  static const String loginName = 'login';
  static const String registerName = 'register';
  static const String onboardingName = 'onboarding';
  static const String customerHomeName = 'customerHome';
  static const String bakerHomeName = 'bakerHome';
  static const String adminHomeName = 'adminHome';
  static const String discoveryName = 'discovery';
  static const String notificationsName = 'notifications';
  static const String payoutsName = 'payouts';
  static const String profileName = 'profile';
  static const String productDetailName = 'productDetail';
  static const String ordersName = 'orders';
  static const String orderDetailName = 'orderDetail';

  // Order sub-tabs (query/segment for the order detail screen).
  static const String orderTabMessages = 'messages';
  static const String orderTabQuotes = 'quotes';
  static const String orderTabProduction = 'production';
  static const String orderTabDelivery = 'delivery';
  static const String orderTabPayment = 'payment';
  static const String orderTabDispute = 'dispute';

  static String productDetailPath(String productId) => '/products/$productId';
  static String orderDetailPath(String orderId) => '/orders/$orderId';
}
