/// Result of GET /api/receipts/{id}/file. While R2 is disabled backend-side
/// this still comes back with this exact shape, just carrying a placeholder
/// URL instead of a real signed one - handled the same either way.
class ReceiptFile {
  const ReceiptFile({required this.url, required this.expiresAt});

  final String url;
  final DateTime expiresAt;
}
