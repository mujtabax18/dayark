enum AiErrorCode {
  invalidRequest,
  providerUnavailable,
  unsupportedCapability,
  permissionDenied,
  authentication,
  rateLimited,
  network,
  timeout,
  cancelled,
  invalidResponse,
  internal,
}

/// Safe to present to callers. Never retains raw provider bodies or credentials.
class AiException implements Exception {
  const AiException(this.code, this.message, {this.retryable = false});
  final AiErrorCode code;
  final String message;
  final bool retryable;
  @override
  String toString() => 'AiException(${code.name}): $message';
}
