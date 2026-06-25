/// Status of a baker's quote on an order.
enum QuoteStatus { pending, accepted, declined, expired }

/// A single line item within a quote.
class QuoteLineItem {
  const QuoteLineItem({
    required this.label,
    required this.amountCents,
  });

  final String label;
  final int amountCents;

  factory QuoteLineItem.fromJson(Map<String, dynamic> json) {
    return QuoteLineItem(
      label: json['label'] as String? ?? '',
      amountCents: (json['amount_cents'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'label': label,
        'amount_cents': amountCents,
      };
}

/// A baker's price quote for a custom order.
class Quote {
  const Quote({
    required this.id,
    required this.orderId,
    required this.totalCents,
    required this.depositCents,
    required this.status,
    required this.createdAt,
    this.notes,
    this.leadTimeDays,
    this.lineItems = const [],
    this.expiresAt,
  });

  final String id;
  final String orderId;
  final int totalCents;
  final int depositCents;
  final QuoteStatus status;
  final String? notes;
  final int? leadTimeDays;
  final List<QuoteLineItem> lineItems;
  final DateTime? expiresAt;
  final DateTime createdAt;

  int get balanceCents => totalCents - depositCents;

  factory Quote.fromJson(Map<String, dynamic> json) {
    return Quote(
      id: json['id'].toString(),
      orderId: json['order_id'].toString(),
      totalCents: (json['total_cents'] as num?)?.toInt() ?? 0,
      depositCents: (json['deposit_cents'] as num?)?.toInt() ?? 0,
      status: _parseStatus(json['status'] as String?),
      notes: json['notes'] as String?,
      leadTimeDays: (json['lead_time_days'] as num?)?.toInt(),
      lineItems: (json['line_items'] as List?)
              ?.map((e) => QuoteLineItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      expiresAt: _date(json['expires_at']),
      createdAt: _date(json['created_at']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'order_id': orderId,
        'total_cents': totalCents,
        'deposit_cents': depositCents,
        'status': status.name,
        'notes': notes,
        'lead_time_days': leadTimeDays,
        'line_items': lineItems.map((e) => e.toJson()).toList(),
        'expires_at': expiresAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };

  static QuoteStatus _parseStatus(String? value) {
    return QuoteStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => QuoteStatus.pending,
    );
  }

  static DateTime? _date(Object? value) =>
      value is String && value.isNotEmpty ? DateTime.tryParse(value) : null;
}
