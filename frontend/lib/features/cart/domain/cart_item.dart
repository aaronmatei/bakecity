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
}
