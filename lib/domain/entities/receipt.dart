import 'receipt_item.dart';

enum ReceiptStatus {
  unassigned,
  assigned,
  expired,
  void_,
  unknown;

  static ReceiptStatus fromApi(String value) {
    switch (value.toLowerCase()) {
      case 'unassigned':
        return ReceiptStatus.unassigned;
      case 'assigned':
        return ReceiptStatus.assigned;
      case 'expired':
        return ReceiptStatus.expired;
      case 'void':
        return ReceiptStatus.void_;
      default:
        return ReceiptStatus.unknown;
    }
  }
}

extension ReceiptStatusDisplay on ReceiptStatus {
  String get displayName => this == ReceiptStatus.void_ ? 'void' : name;
}

enum ClaimAssignmentMethod {
  qr,
  nfc,
  unknown;

  static ClaimAssignmentMethod fromApi(String? value) {
    switch (value?.toLowerCase()) {
      case 'qr':
        return ClaimAssignmentMethod.qr;
      case 'nfc':
        return ClaimAssignmentMethod.nfc;
      default:
        return ClaimAssignmentMethod.unknown;
    }
  }
}

/// Mirrors ReceiptDto from the backend (GET /api/customers/me/receipts,
/// POST /api/claims/{code}/scan). Fields not present on that DTO (e.g. the
/// old EF-era `MerchantName`) are intentionally not carried over.
class Receipt {
  const Receipt({
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

  final String id;
  final String storeId;
  final String? receiptNumber;
  final double totalAmount;
  final String currency;
  final ReceiptStatus status;
  final ClaimAssignmentMethod? assignmentMethod;
  final DateTime? assignedAt;
  final DateTime createdAt;
  final List<ReceiptItem> items;
}
