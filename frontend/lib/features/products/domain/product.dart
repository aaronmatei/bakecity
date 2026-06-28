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
    this.leadTimeDays = 1,
    this.isCustomizable = true,
    this.isAvailable = true,
  });

  final String id;
  final String bakerId;
  final String name;
  final String? description;
  final String? categoryId;

  /// Starting price in minor units (cents).
  final int basePriceCents;
  final List<String> imageUrls;
  final int leadTimeDays;
  final bool isCustomizable;
  final bool isAvailable;

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
      imageUrls:
          (json['image_urls'] as List?)?.map((e) => e.toString()).toList() ??
              const [],
      leadTimeDays: (json['lead_time_days'] as num?)?.toInt() ?? 1,
      isCustomizable: json['is_customizable'] as bool? ?? true,
      isAvailable:
          json['active'] as bool? ?? json['is_available'] as bool? ?? true,
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

/// A product category for filtering / discovery.
class Category {
  const Category({required this.id, required this.name, this.iconUrl});

  final String id;
  final String name;
  final String? iconUrl;

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'].toString(),
      name: json['name'] as String? ?? '',
      iconUrl: json['icon_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon_url': iconUrl,
      };
}
