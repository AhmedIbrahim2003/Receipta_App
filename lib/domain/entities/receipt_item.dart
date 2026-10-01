class ReceiptItem {
  const ReceiptItem({
    required this.id,
    required this.sku,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  final String id;
  final String? sku;
  final String name;
  final double quantity;
  final double unitPrice;
  final double totalPrice;
}
