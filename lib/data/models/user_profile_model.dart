import '../../domain/entities/user_profile.dart';

/// Maps `public.customers` (reference-schema.sql). This app has read-only
/// RLS access to this table - see AuthRepository.fetchCustomerProfile for
/// why there is no insert/upsert mapping here.
class UserProfileModel {
  const UserProfileModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.phone,
    required this.createdAt,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      id: json['id'] as String,
      email: json['email'] as String?,
      fullName: json['full_name'] as String?,
      phone: json['phone'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final String? email;
  final String? fullName;
  final String? phone;
  final DateTime createdAt;

  UserProfile toEntity() {
    return UserProfile(id: id, email: email, fullName: fullName, phone: phone, createdAt: createdAt);
  }
}
