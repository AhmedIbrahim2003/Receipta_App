import '../../domain/entities/claim_token.dart';

/// Maps CreateClaimResponseDto (POST /api/claims).
class ClaimTokenModel {
  const ClaimTokenModel({required this.code, required this.expiresAt});

  factory ClaimTokenModel.fromJson(Map<String, dynamic> json) {
    return ClaimTokenModel(
      code: json['code'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
    );
  }

  final String code;
  final DateTime expiresAt;

  ClaimToken toEntity() => ClaimToken(code: code, expiresAt: expiresAt);
}
