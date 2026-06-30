import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralised definition of backend API paths.
///
/// Paths are relative to [baseUrl]; parameterised paths are exposed as
/// functions so call-sites stay type-safe. These mirror the Go backend's
/// router (see backend/internal/server/router.go).
class ApiEndpoints {
  const ApiEndpoints._();

  /// Base URL for the API. Read from `.env` (`API_BASE_URL`); falls back to
  /// localhost for development when the key is absent.
  static String get baseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'http://localhost:8080/api/v1';

  /// WebSocket base, derived from [baseUrl] (http->ws, https->wss).
  static String get wsBaseUrl => baseUrl.replaceFirst('http', 'ws');

  // ---- Auth (no refresh/logout endpoints; logout is local) ----
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String me = '/me';

  // ---- Bakers & onboarding ----
  /// The authenticated user's own baker profile (onboarding / dashboard).
  static const String myBaker = '/me/baker';
  static const String bakers = '/bakers';
  static String baker(String id) => '/bakers/$id';
  static String bakerVerify(String id) => '/bakers/$id/verify'; // KYC submission
  /// A baker's submitted KYC identity documents (owner or admin).
  static String bakerKyc(String id) => '/bakers/$id/kyc';
  static String bakerAvailability(String id) => '/bakers/$id/availability';
  static String bakerReviews(String id) => '/bakers/$id/reviews';

  // ---- Discovery / search ----
  static const String searchBakers = '/search/bakers';
  static const String searchProducts = '/search/products';

  // ---- Catalog ----
  static const String products = '/products';
  static String product(String id) => '/products/$id';
  static const String categories = '/categories';

  // ---- Favorites (wishlist) ----
  static const String favorites = '/favorites';
  static String favorite(String productId) => '/favorites/$productId';
  static const String favoriteBakers = '/favorites/bakers';
  static String favoriteBaker(String bakerId) => '/favorites/bakers/$bakerId';

  // ---- Orders ----
  static const String orders = '/orders';
  static const String orderInsights = '/orders/insights';
  static String order(String id) => '/orders/$id';
  static String orderCancel(String id) => '/orders/$id/cancel';

  // Quotes & offers (per order)
  static String orderQuotes(String id) => '/orders/$id/quotes';
  /// Customer's suggested price (negotiation).
  static String orderOffers(String id) => '/orders/$id/offers';
  static String orderQuoteAccept(String orderId, String quoteId) =>
      '/orders/$orderId/quotes/$quoteId/accept';

  // Messaging (per order)
  static String orderMessages(String id) => '/orders/$id/messages';
  /// Marks the counterparty's messages as read (call when they render on screen).
  static String orderMessagesRead(String id) => '/orders/$id/messages/read';

  // Production timeline (per order) — GET list + POST update share the path
  static String orderProduction(String id) => '/orders/$id/production';

  // Delivery (per order)
  static String orderDelivery(String id) => '/orders/$id/delivery';
  static String orderDeliveryDispatch(String id) =>
      '/orders/$id/delivery/dispatch';
  static String orderDeliveryConfirm(String id) =>
      '/orders/$id/delivery/confirm';

  // Payments (per order)
  static String orderPaymentDeposit(String id) =>
      '/orders/$id/payments/deposit';
  static String orderPaymentBalance(String id) =>
      '/orders/$id/payments/balance';

  // Payouts (baker self-service)
  static const String payouts = '/payouts';
  static const String payoutsBalance = '/payouts/balance';

  // Disputes (per order)
  static String orderDisputes(String id) => '/orders/$id/disputes';

  // ---- Media (presigned uploads) ----
  static const String mediaPresign = '/media/presign';
  static String mediaComplete(String id) => '/media/$id/complete';

  /// Media attached to an order (e.g. `?kind=reference`).
  static String orderMedia(String id) => '/orders/$id/media';

  // ---- Reviews / ratings ----
  static const String reviews = '/reviews';
  static String orderReview(String id) => '/orders/$id/review';

  // ---- Notifications ----
  static const String notifications = '/notifications';
  static const String notificationsUnreadCount = '/notifications/unread-count';
  static const String notificationsReadAll = '/notifications/read-all';
  static String notificationRead(String id) => '/notifications/$id/read';

  /// Register/unregister this device's FCM push token (POST to add, DELETE to
  /// remove). Body: `{ "token": ..., "platform": ... }`.
  static const String notificationDevices = '/notifications/devices';

  /// WebSocket for realtime notifications. Auth is via the `token` query param
  /// (browsers can't set the Authorization header on a WS handshake).
  static String wsNotifications(String token) =>
      '$wsBaseUrl/ws/notifications?token=$token';

  // ---- Admin ----
  static const String adminBakersPending = '/admin/bakers/pending';
  static String adminBakerApprove(String id) => '/admin/bakers/$id/approve';
  static const String adminDisputes = '/admin/disputes';
  static String adminDisputeResolve(String id) => '/admin/disputes/$id/resolve';
  static String adminOrderRefund(String id) => '/admin/orders/$id/refund';
  static const String analyticsOverview = '/analytics/overview';
}
