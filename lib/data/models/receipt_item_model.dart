import '../../domain/entities/receipt_item.dart';

/// Maps ReceiptItemDto.
class ReceiptItemModel {
  const ReceiptItemModel({
    required this.id,
    required this.sku,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  factory ReceiptItemModel.fromJson(Map<String, dynamic> json) {
    return ReceiptItemModel(
      id: json['id'] as String,
      sku: json['sku'] as String?,
      name: json['name'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unitPrice: (json['unitPrice'] as num).toDouble(),
      totalPrice: (json['totalPrice'] as num).toDouble(),
    );
  }

  final String id;
  final String? sku;
  final String name;
  final double quantity;
  final double unitPrice;
  final double totalPrice;

  ReceiptItem toEntity() {
    return ReceiptItem(
      id: id,
      sku: sku,
      name: name,
      quantity: quantity,
      unitPrice: unitPrice,
      totalPrice: totalPrice,
    );
  }
}
