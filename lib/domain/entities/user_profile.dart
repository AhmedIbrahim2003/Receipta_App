/// Domain representation of the signed-in user's `customers` row.
///
/// May be absent even when authenticated: the backend creates this row
/// lazily (CustomerRepository.EnsureExistsAsync) the first time the
/// customer requests an NFC claim or scans a QR code - not at sign-up/in.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    required this.phone,
    required this.createdAt,
  });

  final String id;
  final String? email;
  final String? fullName;
  final String? phone;
  final DateTime createdAt;
}
