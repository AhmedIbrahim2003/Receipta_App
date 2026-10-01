/// Distinguishable claim-scan outcomes, mapped from the backend's
/// machine-readable `code` field (see ClaimOutcomeMapper.cs) - kept separate
/// from generic network/API errors so the UI can show a different message
/// for each rather than one generic "error" state.
enum ClaimFailureReason {
  notFound,
  expired,
  alreadyConsumed,
  wrongType,
  forbidden,

  /// Backend responded with an error but not one of the known claim codes
  /// above (e.g. a 500, or a future error code this app doesn't know yet).
  unknown,
}
