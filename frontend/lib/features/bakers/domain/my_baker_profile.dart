/// The signed-in baker's own profile, including KYC/verification state. This is
/// the management view (GET /me/baker) — distinct from the public storefront
/// [BakerProfile] used in discovery.
class MyBakerProfile {
  const MyBakerProfile({
    required this.id,
    required this.businessName,
    required this.status,
    required this.kycStatus,
    this.bio = '',
    this.deliveryRadiusKm = 10,
    this.leadTimeDays = 1,
    this.dailyCapacity = 10,
    this.lat,
    this.lng,
    this.followerCount = 0,
    this.coverImageUrl,
  });

  final String id;
  final String businessName;

  /// Account status: pending | approved | suspended.
  final BakerStatus status;

  /// KYC review state: pending | submitted | approved | rejected.
  final KycStatus kycStatus;

  final String bio;
  final double deliveryRadiusKm;
  final int leadTimeDays;
  final int dailyCapacity;
  final double? lat;
  final double? lng;

  /// How many customers have favorited this bakery (public profile reads).
  final int followerCount;

  /// Presigned storefront cover image URL, when the baker has uploaded one.
  final String? coverImageUrl;

  /// Approved bakers may publish products and receive orders.
  bool get isApproved => status == BakerStatus.approved;

  /// KYC has been submitted and is awaiting (or has passed) admin review.
  bool get isUnderReview => kycStatus == KycStatus.submitted;

  bool get isRejected => kycStatus == KycStatus.rejected;

  /// The baker still needs to submit their details for review.
  bool get needsSubmission =>
      kycStatus == KycStatus.pending || kycStatus == KycStatus.rejected;

  factory MyBakerProfile.fromJson(Map<String, dynamic> json) {
    return MyBakerProfile(
      id: json['id'].toString(),
      businessName: json['business_name'] as String? ?? '',
      status: BakerStatus.fromJson(json['status'] as String?),
      kycStatus: KycStatus.fromJson(json['kyc_status'] as String?),
      bio: json['bio'] as String? ?? '',
      deliveryRadiusKm: (json['delivery_radius_km'] as num?)?.toDouble() ?? 10,
      leadTimeDays: (json['lead_time_days'] as num?)?.toInt() ?? 1,
      dailyCapacity: (json['daily_order_capacity'] as num?)?.toInt() ?? 10,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      followerCount: (json['follower_count'] as num?)?.toInt() ?? 0,
      coverImageUrl: json['cover_image_url'] as String?,
    );
  }
}

/// Baker account status (mirrors the backend `baker_profiles.status`).
enum BakerStatus {
  pending,
  approved,
  suspended;

  static BakerStatus fromJson(String? value) {
    switch (value) {
      case 'approved':
        return BakerStatus.approved;
      case 'suspended':
        return BakerStatus.suspended;
      case 'pending':
      default:
        return BakerStatus.pending;
    }
  }
}

/// KYC review state (mirrors the backend `baker_profiles.kyc_status`).
enum KycStatus {
  pending,
  submitted,
  approved,
  rejected;

  static KycStatus fromJson(String? value) {
    switch (value) {
      case 'submitted':
        return KycStatus.submitted;
      case 'approved':
        return KycStatus.approved;
      case 'rejected':
        return KycStatus.rejected;
      case 'pending':
      default:
        return KycStatus.pending;
    }
  }
}
