/// An order's delivery record.
class Delivery {
  const Delivery({
    required this.id,
    required this.method,
    required this.status,
    this.courierRef,
    this.dispatchedAt,
    this.deliveredAt,
    this.confirmedAt,
  });

  final String id;
  final String method; // own | courier | pickup | self
  final String status; // pending | dispatched | delivered
  final String? courierRef;
  final DateTime? dispatchedAt;
  final DateTime? deliveredAt;
  final DateTime? confirmedAt;

  bool get isDispatched => dispatchedAt != null;
  bool get isDelivered => deliveredAt != null;

  factory Delivery.fromJson(Map<String, dynamic> json) {
    return Delivery(
      id: json['id'].toString(),
      method: json['method'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      courierRef: json['courier_ref'] as String?,
      dispatchedAt: _date(json['dispatched_at']),
      deliveredAt: _date(json['delivered_at']),
      confirmedAt: _date(json['confirmed_at']),
    );
  }

  static DateTime? _date(Object? value) =>
      value is String && value.isNotEmpty ? DateTime.tryParse(value) : null;
}
