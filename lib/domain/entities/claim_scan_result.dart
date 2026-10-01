import 'claim_failure_reason.dart';
import 'receipt.dart';

/// Outcome of POST /api/claims/{code}/scan - mirrors the backend's own
/// ClaimConsumptionResult so a scan failure is a distinguishable result,
/// not a generic thrown error.
class ClaimScanResult {
  const ClaimScanResult._({this.receipt, this.failureReason});

  factory ClaimScanResult.success(Receipt receipt) => ClaimScanResult._(receipt: receipt);

  factory ClaimScanResult.failure(ClaimFailureReason reason) => ClaimScanResult._(failureReason: reason);

  final Receipt? receipt;
  final ClaimFailureReason? failureReason;

  bool get isSuccess => receipt != null;
}
