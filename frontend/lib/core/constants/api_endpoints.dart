/// Centralised definition of backend API paths.
///
/// Paths are relative to [baseUrl]; parameterised paths are exposed as
/// functions so call-sites stay type-safe.
class ApiEndpoints {
  const ApiEndpoints._();

  /// Base URL for the API. Overridable at build time via `--dart-define`.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080/api/v1',
  );

  // ---- Auth ----
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String me = '/me';

  // ---- Onboarding / KYC (baker verification) ----
  static const String bakerKyc = '/me/kyc';
  static const String bakerKycDocuments = '/me/kyc/documents';

  // ---- Bakers ----
  static const String bakers = '/bakers';
  static String baker(String id) => '/bakers/$id';
  static String bakerProducts(String id) => '/bakers/$id/products';
  static String bakerReviews(String id) => '/bakers/$id/reviews';

  // ---- Discovery / search ----
  static const String searchBakers = '/search/bakers';
  static const String searchProducts = '/search/products';

  // ---- Catalog ----
  static const String products = '/products';
  static String product(String id) => '/products/$id';
  static const String categories = '/categories';

  // ---- Orders ----
  static const String orders = '/orders';
  static String order(String id) => '/orders/$id';

  // Quotes (per order)
  static String orderQuotes(String id) => '/orders/$id/quotes';
  static String orderQuote(String orderId, String quoteId) =>
      '/orders/$orderId/quotes/$quoteId';
  static String orderQuoteAccept(String orderId, String quoteId) =>
      '/orders/$orderId/quotes/$quoteId/accept';

  // Messaging (per order)
  static String orderMessages(String id) => '/orders/$id/messages';

  // Production (per order)
  static String orderProduction(String id) => '/orders/$id/production';
  static String orderProductionUpdate(String orderId, String stageId) =>
      '/orders/$orderId/production/$stageId';

  // Delivery (per order)
  static String orderDeliveryDispatch(String id) =>
      '/orders/$id/delivery/dispatch';
  static String orderDeliveryConfirm(String id) =>
      '/orders/$id/delivery/confirm';

  // Payments (per order)
  static String orderPaymentDeposit(String id) =>
      '/orders/$id/payments/deposit';
  static String orderPaymentBalance(String id) =>
      '/orders/$id/payments/balance';

  // Disputes (per order)
  static String orderDisputes(String id) => '/orders/$id/disputes';

  // ---- Media ----
  static const String mediaPresign = '/media/presign';

  // ---- Reviews / ratings ----
  static const String reviews = '/reviews';
  static String review(String id) => '/reviews/$id';

  // ---- Notifications ----
  static const String notifications = '/notifications';
  static const String notificationDeviceTokens = '/notifications/device-tokens';

  // ---- Admin ----
  static const String adminUsers = '/admin/users';
  static const String adminBakers = '/admin/bakers';
  static const String adminBakerVerifications = '/admin/bakers/verifications';
  static const String adminDisputes = '/admin/disputes';
  static const String adminPayouts = '/admin/payouts';
}
