/// Status of a dispute raised against an order.
enum DisputeStatus { open, underReview, resolved, rejected }

/// A dispute raised by a customer or baker over an order.
class Dispute {
  const Dispute({
    required this.id,
    required this.orderId,
    required this.raisedById,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.description,
    this.evidenceUrls = const [],
    this.resolutionNote,
  });

  final String id;
  final String orderId;
  final String raisedById;
  final String reason;
  final String? description;
  final List<String> evidenceUrls;
  final DisputeStatus status;
  final String? resolutionNote;
  final DateTime createdAt;

  factory Dispute.fromJson(Map<String, dynamic> json) {
    return Dispute(
      id: json['id'].toString(),
      orderId: json['order_id'].toString(),
      raisedById: (json['raised_by'] ?? json['raised_by_id']).toString(),
      reason: json['reason'] as String? ?? '',
      description: json['description'] as String?,
      evidenceUrls: (json['evidence_urls'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      status: _parseStatus(json['status'] as String?),
      resolutionNote:
          json['resolution'] as String? ?? json['resolution_note'] as String?,
      createdAt: _date(json['created_at']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'order_id': orderId,
        'raised_by_id': raisedById,
        'reason': reason,
        'description': description,
        'evidence_urls': evidenceUrls,
        'status': status.name,
        'resolution_note': resolutionNote,
        'created_at': createdAt.toIso8601String(),
      };

  static DisputeStatus _parseStatus(String? value) {
    switch (value) {
      case 'under_review':
        return DisputeStatus.underReview;
      case 'resolved':
        return DisputeStatus.resolved;
      case 'rejected':
        return DisputeStatus.rejected;
      default:
        return DisputeStatus.open;
    }
  }

  static DateTime? _date(Object? value) =>
      value is String && value.isNotEmpty ? DateTime.tryParse(value) : null;
}
