/// An armed NFC claim token (from `POST /api/claims`) - the value broadcast
/// over HCE for the ESP32 to read. Short-lived (~60s, enforced server-side).
class ClaimToken {
  const ClaimToken({required this.code, required this.expiresAt});

  final String code;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
