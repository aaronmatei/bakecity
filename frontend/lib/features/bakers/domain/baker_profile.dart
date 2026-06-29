/// A baker's public storefront profile.
class BakerProfile {
  const BakerProfile({
    required this.id,
    required this.businessName,
    this.bio,
    this.avatarUrl,
    this.coverImageUrl,
    this.rating = 0,
    this.reviewCount = 0,
    this.latitude,
    this.longitude,
    this.distanceKm,
    this.isVerified = false,
    this.specialties = const [],
  });

  final String id;
  final String businessName;
  final String? bio;
  final String? avatarUrl;
  final String? coverImageUrl;
  final double rating;
  final int reviewCount;
  final double? latitude;
  final double? longitude;
  final double? distanceKm;
  final bool isVerified;
  final List<String> specialties;

  factory BakerProfile.fromJson(Map<String, dynamic> json) {
    // The search backend sends `lat`/`lng`/`avg_rating`/`status`; older shapes
    // used `latitude`/`longitude`/`rating`/`is_verified`. Accept both.
    return BakerProfile(
      id: json['id'].toString(),
      businessName: json['business_name'] as String? ?? 'Unnamed bakery',
      bio: json['bio'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
      rating: (json['avg_rating'] as num?)?.toDouble() ??
          (json['rating'] as num?)?.toDouble() ??
          0,
      reviewCount: (json['review_count'] as num?)?.toInt() ?? 0,
      latitude: (json['lat'] as num?)?.toDouble() ??
          (json['latitude'] as num?)?.toDouble(),
      longitude: (json['lng'] as num?)?.toDouble() ??
          (json['longitude'] as num?)?.toDouble(),
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      isVerified: json['is_verified'] as bool? ?? json['status'] == 'approved',
      specialties: (json['specialties'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'business_name': businessName,
        'bio': bio,
        'avatar_url': avatarUrl,
        'cover_image_url': coverImageUrl,
        'rating': rating,
        'review_count': reviewCount,
        'latitude': latitude,
        'longitude': longitude,
        'distance_km': distanceKm,
        'is_verified': isVerified,
        'specialties': specialties,
      };
}
