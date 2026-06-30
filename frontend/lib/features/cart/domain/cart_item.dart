/// A line in the shopping cart (fixed products only — one baker per cart).
class CartItem {
  const CartItem({
    required this.productId,
    required this.bakerId,
    required this.title,
    required this.unitPriceCents,
    this.imageUrl,
    this.sizeId,
    this.sizeLabel,
    this.qty = 1,
  });

  final String productId;
  final String bakerId;
  final String title;
  final int unitPriceCents;
  final String? imageUrl;
  final String? sizeId;
  final String? sizeLabel;
  final int qty;

  /// Identity for dedup: a product + chosen size is one line.
  String get key => '$productId|${sizeId ?? ''}';
  int get lineCents => unitPriceCents * qty;

  CartItem copyWith({int? qty}) => CartItem(
        productId: productId,
        bakerId: bakerId,
        title: title,
        unitPriceCents: unitPriceCents,
        imageUrl: imageUrl,
        sizeId: sizeId,
        sizeLabel: sizeLabel,
        qty: qty ?? this.qty,
      );

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'bakerId': bakerId,
        'title': title,
        'unitPriceCents': unitPriceCents,
        'imageUrl': imageUrl,
        'sizeId': sizeId,
        'sizeLabel': sizeLabel,
        'qty': qty,
      };

  factory CartItem.fromJson(Map<String, dynamic> j) => CartItem(
        productId: j['productId'] as String,
        bakerId: j['bakerId'] as String,
        title: j['title'] as String,
        unitPriceCents: (j['unitPriceCents'] as num).toInt(),
        imageUrl: j['imageUrl'] as String?,
        sizeId: j['sizeId'] as String?,
        sizeLabel: j['sizeLabel'] as String?,
        qty: (j['qty'] as num?)?.toInt() ?? 1,
      );
}
