import '../enums/image_source_type.dart';

/// Categories of failure surfaced by the image pipeline.
enum SmartImageErrorType {
  /// The source value could not be classified.
  invalidSource,

  /// The host domain was rejected by the `allowedDomains` whitelist.
  blockedDomain,

  /// A network request failed (DNS, timeout, transport error).
  network,

  /// The server responded with a non-2xx status code.
  httpStatus,

  /// The bytes could not be decoded into an image.
  decode,

  /// A referenced asset or file did not exist.
  notFound,

  /// An unexpected, uncategorised error.
  unknown,
}

/// The error type passed to `errorBuilder` and `onLoadError`.
///
/// Carries enough context for callers to render a meaningful message or branch
/// their retry logic, while remaining a plain [Exception] so it can be thrown
/// and caught conventionally.
class SmartImageException implements Exception {
  /// Creates an exception describing an image-pipeline failure.
  const SmartImageException(
    this.type,
    this.message, {
    this.sourceType,
    this.statusCode,
    this.cause,
    this.stackTrace,
  });

  /// The failure category.
  final SmartImageErrorType type;

  /// A human-readable description.
  final String message;

  /// The kind of source being loaded when the error occurred, if known.
  final ImageSourceType? sourceType;

  /// The HTTP status code for [SmartImageErrorType.httpStatus] failures.
  final int? statusCode;

  /// The underlying error, if this wraps another exception.
  final Object? cause;

  /// The stack trace captured at the failure site, if available.
  final StackTrace? stackTrace;

  /// Whether retrying the operation could plausibly succeed.
  bool get isRetryable {
    switch (type) {
      case SmartImageErrorType.network:
        return true;
      case SmartImageErrorType.httpStatus:
        // Retry transient server errors and rate limits, not client errors.
        final code = statusCode ?? 0;
        return code >= 500 || code == 408 || code == 429;
      case SmartImageErrorType.invalidSource:
      case SmartImageErrorType.blockedDomain:
      case SmartImageErrorType.decode:
      case SmartImageErrorType.notFound:
      case SmartImageErrorType.unknown:
        return false;
    }
  }

  @override
  String toString() {
    final buffer = StringBuffer('SmartImageException(${type.name}): $message');
    if (statusCode != null) buffer.write(' [HTTP $statusCode]');
    if (cause != null) buffer.write(' caused by: $cause');
    return buffer.toString();
  }
}
