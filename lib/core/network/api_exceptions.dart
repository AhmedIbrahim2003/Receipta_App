/// Base type for every error an [ApiClient] call can throw. Lets callers
/// distinguish "the request never reached the server" from "the server
/// responded with an error" without inspecting Dio internals.
sealed class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// No connectivity, DNS failure, connection refused, or a timeout - the
/// request never got a response from the server.
class NetworkException extends ApiException {
  const NetworkException([super.message = 'Could not reach the server. Check your connection.']);
}

/// The server responded with an error status. [code] is the backend's
/// machine-readable error code (e.g. "TOKEN_EXPIRED", "TOKEN_NOT_FOUND")
/// when the response body included one - see ClaimOutcomeMapper on the
/// backend for the full set used by the claim endpoints.
class ApiErrorException extends ApiException {
  const ApiErrorException({
    required this.statusCode,
    required String message,
    this.code,
  }) : super(message);

  final int statusCode;
  final String? code;
}
