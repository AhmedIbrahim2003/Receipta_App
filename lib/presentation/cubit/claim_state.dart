import 'package:equatable/equatable.dart';

import '../../domain/entities/claim_failure_reason.dart';
import '../../domain/entities/receipt.dart';

enum ClaimStatus {
  /// Nothing armed yet - "Ready to tap" and the QR scanner are both available.
  initial,

  /// POST /api/claims in flight.
  arming,

  /// HCE armed with a code; QR scanner also active. Polling
  /// GET /api/customers/me/receipts for NFC completion in the background.
  waitingForCustomer,

  /// The ESP32 read the NFC tag locally, but that only means the tap
  /// reached the ESP32 - the Agent still has to call the backend to finish
  /// assignment. Polling continues at a faster interval with a bounded
  /// timeout while this is shown.
  tapDetected,

  /// A QR scan is being validated against POST /api/claims/{code}/scan.
  completingViaQr,

  /// The ~60s claim token expired with no completion (before any tap was
  /// detected). Distinct from tapDetected timing out.
  nfcExpired,

  /// A tap was detected but the backend never confirmed assignment within
  /// the bounded follow-up window.
  completionTimedOut,

  success,

  /// A QR scan came back as a distinguishable claim failure (not found /
  /// expired / already consumed / wrong type / forbidden).
  claimFailed,

  /// A connectivity failure (request never reached the server).
  networkError,

  /// An unexpected API error not covered by the specific states above.
  failed,
}

class ClaimState extends Equatable {
  const ClaimState({
    this.status = ClaimStatus.initial,
    this.code,
    this.expiresAt,
    this.receipt,
    this.failureReason,
    this.errorMessage,
  });

  final ClaimStatus status;
  final String? code;
  final DateTime? expiresAt;
  final Receipt? receipt;
  final ClaimFailureReason? failureReason;
  final String? errorMessage;

  ClaimState copyWith({
    ClaimStatus? status,
    String? code,
    DateTime? expiresAt,
    Receipt? receipt,
    ClaimFailureReason? failureReason,
    String? errorMessage,
  }) {
    return ClaimState(
      status: status ?? this.status,
      code: code ?? this.code,
      expiresAt: expiresAt ?? this.expiresAt,
      receipt: receipt ?? this.receipt,
      failureReason: failureReason ?? this.failureReason,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, code, expiresAt, receipt, failureReason, errorMessage];
}
