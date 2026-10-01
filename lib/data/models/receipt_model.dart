import '../../domain/entities/receipt.dart';
import 'receipt_item_model.dart';

/// Maps ReceiptDto (GET /api/customers/me/receipts, POST /api/claims/{code}/scan).
class ReceiptModel {
  const ReceiptModel({
    required this.id,
    required this.storeId,
    required this.receiptNumber,
    required this.totalAmount,
    required this.currency,
    required this.status,
    required this.assignmentMethod,
    required this.assignedAt,
    required this.createdAt,
    required this.items,
  });

  factory ReceiptModel.fromJson(Map<String, dynamic> json) {
    return ReceiptModel(
      id: json['id'] as String,
      storeId: json['storeId'] as String,
      receiptNumber: json['receiptNumber'] as String?,
      totalAmount: (json['totalAmount'] as num).toDouble(),
      currency: json['currency'] as String,
      status: json['status'] as String,
      assignmentMethod: json['assignmentMethod'] as String?,
      assignedAt: json['assignedAt'] == null ? null : DateTime.parse(json['assignedAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      items: (json['items'] as List<dynamic>? ?? [])
          .map((item) => ReceiptItemModel.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  final String id;
  final String storeId;
  final String? receiptNumber;
  final double totalAmount;
  final String currency;
  final String status;
  final String? assignmentMethod;
  final DateTime? assignedAt;
  final DateTime createdAt;
  final List<ReceiptItemModel> items;

  Receipt toEntity() {
    return Receipt(
      id: id,
      storeId: storeId,
      receiptNumber: receiptNumber,
      totalAmount: totalAmount,
      currency: currency,
      status: ReceiptStatus.fromApi(status),
      assignmentMethod: assignmentMethod == null ? null : ClaimAssignmentMethod.fromApi(assignmentMethod),
      assignedAt: assignedAt,
      createdAt: createdAt,
      items: items.map((item) => item.toEntity()).toList(),
    );
  }
}
