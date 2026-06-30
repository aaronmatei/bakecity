/// Named route paths and names used by the GoRouter configuration.
class AppRoutes {
  const AppRoutes._();

  // Top-level paths.
  static const String splash = '/';
  static const String welcome = '/welcome';
  static const String login = '/login';
  static const String register = '/register';
  static const String onboarding = '/onboarding';

  static const String customerHome = '/home';
  static const String bakerHome = '/baker';
  static const String adminHome = '/admin';
  static const String discovery = '/discovery';
  static const String search = '/search';
  static const String catalog = '/catalog';
  static const String manageProducts = '/me/products';
  static const String insights = '/me/insights';
  static const String cart = '/cart';
  static const String favorites = '/favorites';
  static const String notifications = '/notifications';
  static const String payouts = '/payouts';
  static const String profile = '/profile';

  // Parameterised.
  static const String bakerStorefront = '/bakers/:bakerId';
  static const String productDetail = '/products/:productId';
  static const String productOrderRequest = '/products/:productId/order';
  static const String bakerReviews = '/bakers/:bakerId/reviews';
  static const String orders = '/orders';
  static const String orderDetail = '/orders/:orderId';
  static const String orderReview = '/orders/:orderId/review';

  // Route names (for `goNamed`).
  static const String splashName = 'splash';
  static const String welcomeName = 'welcome';
  static const String loginName = 'login';
  static const String registerName = 'register';
  static const String onboardingName = 'onboarding';
  static const String customerHomeName = 'customerHome';
  static const String bakerHomeName = 'bakerHome';
  static const String adminHomeName = 'adminHome';
  static const String discoveryName = 'discovery';
  static const String searchName = 'search';
  static const String catalogName = 'catalog';
  static const String manageProductsName = 'manageProducts';
  static const String insightsName = 'insights';
  static const String cartName = 'cart';
  static const String favoritesName = 'favorites';
  static const String notificationsName = 'notifications';
  static const String payoutsName = 'payouts';
  static const String profileName = 'profile';
  static const String bakerStorefrontName = 'bakerStorefront';
  static const String productDetailName = 'productDetail';
  static const String productOrderRequestName = 'productOrderRequest';
  static const String bakerReviewsName = 'bakerReviews';
  static const String ordersName = 'orders';
  static const String orderDetailName = 'orderDetail';
  static const String orderReviewName = 'orderReview';

  // Order sub-tabs (query/segment for the order detail screen).
  static const String orderTabMessages = 'messages';
  static const String orderTabQuotes = 'quotes';
  static const String orderTabProduction = 'production';
  static const String orderTabDelivery = 'delivery';
  static const String orderTabPayment = 'payment';
  static const String orderTabDispute = 'dispute';

  static String bakerStorefrontPath(String bakerId) => '/bakers/$bakerId';
  static String productDetailPath(String productId) => '/products/$productId';
  static String productOrderRequestPath(String productId) =>
      '/products/$productId/order';
  static String orderDetailPath(String orderId) => '/orders/$orderId';
  static String orderReviewPath(String orderId) => '/orders/$orderId/review';
}
