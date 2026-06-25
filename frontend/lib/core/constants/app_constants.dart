/// Application-wide constant values.
class AppConstants {
  const AppConstants._();

  /// Human-readable app name.
  static const String appName = 'BakeCity';

  /// Tagline shown on splash / login screens.
  static const String tagline = 'Custom bakes, delivered.';

  /// Default page size for paginated lists.
  static const int defaultPageSize = 20;

  /// Maximum page size accepted by the backend.
  static const int maxPageSize = 100;

  /// Default network timeout in seconds.
  static const int networkTimeoutSeconds = 30;

  /// Default search radius (in kilometres) for nearby bakers.
  static const double defaultSearchRadiusKm = 10;

  /// Currency code used throughout the app.
  static const String currencyCode = 'KES';

  /// Locale used for formatting currency and dates.
  static const String defaultLocale = 'en_KE';

  /// Maximum number of images allowed per product / order reference.
  static const int maxImagesPerUpload = 8;
}

/// User roles supported by the platform.
enum UserRole { customer, baker, admin }

/// Lifecycle status of an order.
enum OrderStatus {
  draft,
  pendingQuote,
  quoted,
  accepted,
  depositPaid,
  inProduction,
  ready,
  dispatched,
  delivered,
  completed,
  cancelled,
  disputed,
}
