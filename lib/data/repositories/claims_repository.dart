import '../../core/network/api_client.dart';
import '../../core/network/api_exceptions.dart';
import '../../domain/entities/claim_failure_reason.dart';
import '../../domain/entities/claim_scan_result.dart';
import '../../domain/entities/claim_token.dart';
import '../models/claim_token_model.dart';
import '../models/receipt_model.dart';

/// Talks to the claim-token endpoints (POST /api/claims, POST
/// /api/claims/{code}/scan). [NetworkException]s propagate as-is so callers
/// can distinguish connectivity failures from claim-specific outcomes
/// (mapped into [ClaimScanResult.failureReason] instead of being thrown).
class ClaimsRepository {
  ClaimsRepository({required this._apiClient});

  final ApiClient _apiClient;

  /// POST /api/claims (type=nfc). Requests a short-lived token to arm HCE with.
  Future<ClaimToken> createNfcClaim() async {
    final response = await _apiClient.post('/api/claims');
    return ClaimTokenModel.fromJson(response.data as Map<String, dynamic>).toEntity();
  }

  /// POST /api/claims/{code}/scan. Never throws for expected claim-business
  /// failures (not found / expired / already consumed / wrong type /
  /// forbidden) - those come back as [ClaimScanResult.failureReason].
  /// [NetworkException] still propagates for connectivity failures.
  Future<ClaimScanResult> scanQrClaim(String code) async {
    try {
      final response = await _apiClient.post('/api/claims/$code/scan');
      final receipt = ReceiptModel.fromJson(response.data as Map<String, dynamic>).toEntity();
      return ClaimScanResult.success(receipt);
    } on ApiErrorException catch (e) {
      return ClaimScanResult.failure(_mapFailureReason(e.code));
    }
  }

  ClaimFailureReason _mapFailureReason(String? code) {
    switch (code) {
      case 'TOKEN_NOT_FOUND':
        return ClaimFailureReason.notFound;
      case 'TOKEN_EXPIRED':
        return ClaimFailureReason.expired;
      case 'TOKEN_ALREADY_CONSUMED':
        return ClaimFailureReason.alreadyConsumed;
      case 'TOKEN_WRONG_TYPE':
        return ClaimFailureReason.wrongType;
      case 'FORBIDDEN':
        return ClaimFailureReason.forbidden;
      default:
        return ClaimFailureReason.unknown;
    }
  }
}
