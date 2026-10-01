import 'receipt_model.dart';

/// Maps PagedResponseDto&lt;ReceiptDto&gt; (GET /api/customers/me/receipts).
/// Specific to Receipt rather than a generic wrapper - this is the only
/// paged endpoint the app calls today.
class PagedReceiptsModel {
  const PagedReceiptsModel({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalCount,
  });

  factory PagedReceiptsModel.fromJson(Map<String, dynamic> json) {
    return PagedReceiptsModel(
      items: (json['items'] as List<dynamic>)
          .map((item) => ReceiptModel.fromJson(item as Map<String, dynamic>))
          .toList(),
      page: json['page'] as int,
      pageSize: json['pageSize'] as int,
      totalCount: json['totalCount'] as int,
    );
  }

  final List<ReceiptModel> items;
  final int page;
  final int pageSize;
  final int totalCount;

  bool get hasMore => page * pageSize < totalCount;
}
