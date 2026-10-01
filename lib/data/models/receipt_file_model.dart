import '../../domain/entities/receipt_file.dart';

/// Maps ReceiptFileResponseDto (GET /api/receipts/{id}/file).
class ReceiptFileModel {
  const ReceiptFileModel({required this.url, required this.expiresAt});

  factory ReceiptFileModel.fromJson(Map<String, dynamic> json) {
    return ReceiptFileModel(
      url: json['url'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
    );
  }

  final String url;
  final DateTime expiresAt;

  ReceiptFile toEntity() => ReceiptFile(url: url, expiresAt: expiresAt);
}
