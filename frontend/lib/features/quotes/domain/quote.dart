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

/// A price entry on an order — either the baker's quote (acceptable by the
/// customer) or the customer's suggested offer during negotiation.
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
    this.proposedBy = 'baker',
    this.isFinal = false,
    this.deliveryFeeCents = 0,
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

  /// Who proposed this — `'baker'` (a quote) or `'customer'` (an offer).
  final String proposedBy;

  /// Whether the baker marked this as their best & final offer.
  final bool isFinal;

  /// Courier charge in cents the baker proposed (cake price is [totalCents]).
  final int deliveryFeeCents;

  bool get isCustomerOffer => proposedBy == 'customer';

  /// What the customer pays overall: cake + delivery.
  int get grandTotalCents => totalCents + deliveryFeeCents;

  /// Remaining after the deposit, including the courier charge.
  int get balanceCents => grandTotalCents - depositCents;

  factory Quote.fromJson(Map<String, dynamic> json) {
    // Backend quote: { amount (KES total), deposit_pct, status, version }.
    // The app models money in cents and a deposit amount, so derive them.
    final amount = (json['amount'] as num?)?.toDouble();
    final depositPct = (json['deposit_pct'] as num?)?.toDouble() ?? 0;
    final totalCents = amount != null
        ? (amount * 100).round()
        : (json['total_cents'] as num?)?.toInt() ?? 0;
    final depositCents = amount != null
        ? (amount * depositPct).round() // amount * (pct/100) * 100
        : (json['deposit_cents'] as num?)?.toInt() ?? 0;
    return Quote(
      id: json['id'].toString(),
      orderId: json['order_id'].toString(),
      totalCents: totalCents,
      depositCents: depositCents,
      status: _parseStatus(json['status'] as String?),
      notes: json['notes'] as String?,
      leadTimeDays: (json['lead_time_days'] as num?)?.toInt(),
      lineItems: (json['line_items'] as List?)
              ?.map((e) => QuoteLineItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      expiresAt: _date(json['expires_at'] ?? json['valid_until']),
      createdAt: _date(json['created_at']) ?? DateTime.now(),
      proposedBy: json['proposed_by'] as String? ?? 'baker',
      isFinal: json['is_final'] as bool? ?? false,
      deliveryFeeCents:
          (((json['delivery_fee'] as num?)?.toDouble() ?? 0) * 100).round(),
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
    switch (value) {
      case 'accepted':
        return QuoteStatus.accepted;
      case 'expired':
      case 'superseded': // a revised quote replaced this one
        return QuoteStatus.expired;
      case 'rejected':
      case 'declined':
        return QuoteStatus.declined;
      case 'pending':
      default:
        return QuoteStatus.pending;
    }
  }

  static DateTime? _date(Object? value) =>
      value is String && value.isNotEmpty ? DateTime.tryParse(value) : null;
}
