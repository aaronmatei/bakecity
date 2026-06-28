/// A single entry in an order's production timeline.
class ProductionUpdate {
  const ProductionUpdate({
    required this.id,
    required this.stage,
    required this.progressPct,
    required this.createdAt,
    this.notes,
    this.mediaId,
  });

  final String id;
  final String stage;
  final int progressPct;
  final String? notes;
  final String? mediaId;
  final DateTime createdAt;

  factory ProductionUpdate.fromJson(Map<String, dynamic> json) {
    return ProductionUpdate(
      id: json['id'].toString(),
      stage: json['stage'] as String? ?? '',
      progressPct: (json['progress_pct'] as num?)?.toInt() ?? 0,
      notes: json['notes'] as String?,
      mediaId: json['media_id'] as String?,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
