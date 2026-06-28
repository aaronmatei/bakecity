import '../../../core/constants/app_constants.dart';

/// A custom-bake order moving through the escrow lifecycle.
class Order {
  const Order({
    required this.id,
    required this.customerId,
    required this.bakerId,
    required this.status,
    required this.createdAt,
    this.productId,
    this.title,
    this.description,
    this.referenceImageUrls = const [],
    this.eventDate,
    this.deliveryAddress,
    this.totalCents,
    this.depositCents,
    this.balanceCents,
  });

  final String id;
  final String customerId;
  final String bakerId;
  final String? productId;
  final OrderStatus status;
  final String? title;
  final String? description;
  final List<String> referenceImageUrls;
  final DateTime? eventDate;
  final String? deliveryAddress;
  final int? totalCents;
  final int? depositCents;
  final int? balanceCents;
  final DateTime createdAt;

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'].toString(),
      customerId: json['customer_id'].toString(),
      bakerId: json['baker_id'].toString(),
      productId: json['product_id']?.toString(),
      status: parseOrderStatus(json['status'] as String?),
      title: json['title'] as String?,
      description: json['description'] as String?,
      referenceImageUrls: (json['reference_image_urls'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      eventDate: _parseDate(json['event_date']),
      deliveryAddress: json['delivery_address'] as String?,
      // Backend sends decimal KES amounts (total_amount, …); the app models
      // money in minor units (cents), so convert here.
      totalCents: _cents(json['total_amount']) ??
          (json['total_cents'] as num?)?.toInt(),
      depositCents: _cents(json['deposit_amount']) ??
          (json['deposit_cents'] as num?)?.toInt(),
      balanceCents: _cents(json['balance_amount']) ??
          (json['balance_cents'] as num?)?.toInt(),
      createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'customer_id': customerId,
        'baker_id': bakerId,
        'product_id': productId,
        'status': status.name,
        'title': title,
        'description': description,
        'reference_image_urls': referenceImageUrls,
        'event_date': eventDate?.toIso8601String(),
        'delivery_address': deliveryAddress,
        'total_cents': totalCents,
        'deposit_cents': depositCents,
        'balance_cents': balanceCents,
        'created_at': createdAt.toIso8601String(),
      };

  static DateTime? _parseDate(Object? value) {
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    return null;
  }

  /// Converts a decimal KES amount to integer cents, or null if absent.
  static int? _cents(Object? value) =>
      value is num ? (value * 100).round() : null;
}

/// Maps the backend's order statuses (UPPER_SNAKE, see the Go state machine) to
/// the app's [OrderStatus] enum. The backend has a few states the enum folds
/// together (e.g. NEGOTIATING -> pendingQuote, REFUNDED -> cancelled).
const Map<String, OrderStatus> _backendStatus = {
  'DRAFT': OrderStatus.draft,
  'QUOTE_REQUESTED': OrderStatus.pendingQuote,
  'NEGOTIATING': OrderStatus.pendingQuote,
  'QUOTED': OrderStatus.quoted,
  'APPROVED': OrderStatus.accepted,
  'DEPOSIT_PENDING': OrderStatus.accepted,
  'DEPOSIT_PAID': OrderStatus.depositPaid,
  'IN_PRODUCTION': OrderStatus.inProduction,
  'READY': OrderStatus.ready,
  'OUT_FOR_DELIVERY': OrderStatus.dispatched,
  'DELIVERED': OrderStatus.delivered,
  'COMPLETED': OrderStatus.completed,
  'CANCELLED': OrderStatus.cancelled,
  'DISPUTED': OrderStatus.disputed,
  'REFUNDED': OrderStatus.cancelled,
};

/// Parses a server status string into an [OrderStatus], defaulting to draft.
OrderStatus parseOrderStatus(String? value) {
  if (value == null) return OrderStatus.draft;
  final mapped = _backendStatus[value.toUpperCase()];
  if (mapped != null) return mapped;
  for (final status in OrderStatus.values) {
    if (status.name == value || _snake(status.name) == value) return status;
  }
  return OrderStatus.draft;
}

String _snake(String camel) {
  return camel
      .replaceAllMapped(
        RegExp('[A-Z]'),
        (m) => '_${m.group(0)!.toLowerCase()}',
      )
      .replaceFirst(RegExp('^_'), '');
}
