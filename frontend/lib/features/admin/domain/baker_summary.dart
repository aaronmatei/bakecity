/// Admin-facing view of a baker profile awaiting approval.
class BakerSummary {
  const BakerSummary({
    required this.id,
    required this.userId,
    required this.businessName,
    required this.status,
    required this.kycStatus,
    required this.phone,
    required this.createdAt,
    this.email,
  });

  final String id;
  final String userId;
  final String businessName;
  final String status;
  final String kycStatus;
  final String phone;
  final String? email;
  final DateTime createdAt;

  factory BakerSummary.fromJson(Map<String, dynamic> json) {
    return BakerSummary(
      id: json['id'].toString(),
      userId: json['user_id'].toString(),
      businessName: json['business_name'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      kycStatus: json['kyc_status'] as String? ?? 'pending',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String?,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
