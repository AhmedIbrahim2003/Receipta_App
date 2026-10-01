import '../../core/network/api_client.dart';
import '../../domain/entities/receipt_file.dart';
import '../../domain/entities/receipts_page.dart';
import '../models/paged_receipts_model.dart';
import '../models/receipt_file_model.dart';

/// Talks to the customer-facing receipt read endpoints. Deliberately does
/// NOT read the `receipts` table directly via Supabase even though RLS
/// permits it (see reference-schema.sql) - the design doc lists
/// GET /api/customers/me/receipts as the intended path for "my receipts",
/// and going through the backend keeps this app's data access consistent
/// with the claim endpoints, which must go through the backend regardless.
class ReceiptsRepository {
  ReceiptsRepository({required this._apiClient});

  final ApiClient _apiClient;

  Future<ReceiptsPage> getMyReceipts({int page = 1, int pageSize = 20}) async {
    final response = await _apiClient.get(
      '/api/customers/me/receipts',
      queryParameters: {'page': page, 'pageSize': pageSize},
    );
    final model = PagedReceiptsModel.fromJson(response.data as Map<String, dynamic>);
    return ReceiptsPage(
      items: model.items.map((item) => item.toEntity()).toList(),
      page: model.page,
      pageSize: model.pageSize,
      totalCount: model.totalCount,
    );
  }

  /// GET /api/receipts/{id}/file - returns a signed URL (or, while R2 is
  /// disabled backend-side, a placeholder URL in the same shape).
  Future<ReceiptFile> getReceiptFileUrl(String receiptId) async {
    final response = await _apiClient.get('/api/receipts/$receiptId/file');
    return ReceiptFileModel.fromJson(response.data as Map<String, dynamic>).toEntity();
  }
}
