/// A catalog product offered by a baker.
class Product {
  const Product({
    required this.id,
    required this.bakerId,
    required this.name,
    required this.basePriceCents,
    this.description,
    this.categoryId,
    this.imageUrls = const [],
    this.imageMediaIds = const [],
    this.leadTimeDays = 1,
    this.isCustomizable = true,
    this.isAvailable = true,
    this.ratingAvg = 0,
    this.ratingCount = 0,
    this.isOnOffer = false,
    this.discountPct,
    this.dietary = const [],
    this.cakeOccasion,
    this.cakeFlavor,
    this.cakeFormat,
    this.sizes = const [],
  });

  final String id;
  final String bakerId;
  final String name;
  final String? description;
  final String? categoryId;

  /// Starting price in minor units (cents).
  final int basePriceCents;
  final List<String> imageUrls;

  /// Media ids backing [imageUrls], same order — used when editing the gallery.
  final List<String> imageMediaIds;
  final int leadTimeDays;
  final bool isCustomizable;
  final bool isAvailable;

  // Catalog enrichment.
  final double ratingAvg;
  final int ratingCount;
  final bool isOnOffer;
  final int? discountPct;
  final List<String> dietary;
  final String? cakeOccasion;
  final String? cakeFlavor;
  final String? cakeFormat;

  /// Weight/serving options with their own prices (cakes are priced by weight).
  final List<ProductSize> sizes;

  /// Discounted price in cents when on offer (else the base price).
  int get effectivePriceCents => isOnOffer && discountPct != null
      ? (basePriceCents * (100 - discountPct!) / 100).round()
      : basePriceCents;

  factory Product.fromJson(Map<String, dynamic> json) {
    // Backend product: { title, base_price (KES), active }. Map to the app's
    // field names / cents, with fallbacks to the legacy keys.
    final basePrice = (json['base_price'] as num?)?.toDouble();
    return Product(
      id: json['id'].toString(),
      bakerId: json['baker_id'].toString(),
      name: json['title'] as String? ?? json['name'] as String? ?? '',
      description: json['description'] as String?,
      categoryId: json['category_id']?.toString(),
      basePriceCents: basePrice != null
          ? (basePrice * 100).round()
          : (json['base_price_cents'] as num?)?.toInt() ?? 0,
      imageMediaIds: (json['image_media_ids'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      imageUrls:
          (json['image_urls'] as List?)?.map((e) => e.toString()).toList() ??
              const [],
      leadTimeDays: (json['lead_time_days'] as num?)?.toInt() ?? 1,
      isCustomizable: json['is_custom'] as bool? ??
          json['is_customizable'] as bool? ??
          true,
      isAvailable:
          json['active'] as bool? ?? json['is_available'] as bool? ?? true,
      ratingAvg: (json['rating_avg'] as num?)?.toDouble() ?? 0,
      ratingCount: (json['rating_count'] as num?)?.toInt() ?? 0,
      isOnOffer: json['is_on_offer'] as bool? ?? false,
      discountPct: (json['discount_pct'] as num?)?.toInt(),
      dietary:
          (json['dietary'] as List?)?.map((e) => e.toString()).toList() ??
              const [],
      cakeOccasion: json['cake_occasion'] as String?,
      cakeFlavor: json['cake_flavor'] as String?,
      cakeFormat: json['cake_format'] as String?,
      sizes: (json['sizes'] as List?)
              ?.map((e) => ProductSize.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'baker_id': bakerId,
        'name': name,
        'description': description,
        'category_id': categoryId,
        'base_price_cents': basePriceCents,
        'image_urls': imageUrls,
        'lead_time_days': leadTimeDays,
        'is_customizable': isCustomizable,
        'is_available': isAvailable,
      };
}

/// A weight/serving option for a product, with its own price.
class ProductSize {
  const ProductSize({
    required this.id,
    required this.label,
    required this.priceCents,
    this.weightKg,
    this.serves,
  });

  final String id;
  final String label;
  final int priceCents;
  final double? weightKg;
  final int? serves;

  factory ProductSize.fromJson(Map<String, dynamic> json) {
    final price = (json['price'] as num?)?.toDouble() ?? 0;
    return ProductSize(
      id: json['id'].toString(),
      label: json['label'] as String? ?? '',
      priceCents: (price * 100).round(),
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
      serves: (json['serves'] as num?)?.toInt(),
    );
  }
}

/// A product category for filtering / discovery.
class Category {
  const Category({
    required this.id,
    required this.name,
    this.slug,
    this.iconUrl,
  });

  final String id;
  final String name;

  /// URL-safe key used by discovery search (`?category=<slug>`).
  final String? slug;
  final String? iconUrl;

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'].toString(),
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String?,
      iconUrl: json['icon_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        'icon_url': iconUrl,
      };
}
