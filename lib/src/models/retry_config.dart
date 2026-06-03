/// Configuration for the retry engine that guards remote image fetches.
///
/// Backoff is computed as `delay * backoffMultiplier^attempt`, optionally
/// capped at [maxDelay], with a small random jitter to avoid thundering-herd
/// retries across many widgets failing at once.
class RetryConfig {
  /// Creates a retry policy.
  const RetryConfig({
    this.maxAttempts = 3,
    this.delay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
    this.backoffMultiplier = 2.0,
    this.useJitter = true,
  })  : assert(maxAttempts >= 0, 'maxAttempts must be non-negative'),
        assert(backoffMultiplier >= 1.0, 'backoffMultiplier must be >= 1.0');

  /// A policy that performs no automatic retries.
  static const RetryConfig disabled = RetryConfig(maxAttempts: 0);

  /// Number of retries attempted after the initial request fails.
  final int maxAttempts;

  /// Base delay before the first retry.
  final Duration delay;

  /// Upper bound for any single computed backoff delay.
  final Duration maxDelay;

  /// Exponential growth factor applied per attempt.
  final double backoffMultiplier;

  /// Whether to apply randomised jitter (0–25%) to each delay.
  final bool useJitter;

  /// Whether this policy permits any retries at all.
  bool get isEnabled => maxAttempts > 0;

  /// Computes the delay before the retry numbered [attempt] (1-based).
  ///
  /// [randomFactor] is an injectable `0.0..1.0` source so the calculation is
  /// deterministic under test; production callers pass a real random value.
  Duration delayForAttempt(int attempt, {double randomFactor = 0.0}) {
    if (attempt <= 0) return Duration.zero;
    final exponential =
        delay.inMilliseconds * _pow(backoffMultiplier, attempt - 1);
    var millis = exponential.clamp(0, maxDelay.inMilliseconds.toDouble());
    if (useJitter) {
      // Apply up to +25% jitter.
      millis = millis * (1.0 + 0.25 * randomFactor);
    }
    return Duration(milliseconds: millis.round());
  }

  static double _pow(double base, int exp) {
    var result = 1.0;
    for (var i = 0; i < exp; i++) {
      result *= base;
    }
    return result;
  }

  /// Returns a copy with selected fields overridden.
  RetryConfig copyWith({
    int? maxAttempts,
    Duration? delay,
    Duration? maxDelay,
    double? backoffMultiplier,
    bool? useJitter,
  }) =>
      RetryConfig(
        maxAttempts: maxAttempts ?? this.maxAttempts,
        delay: delay ?? this.delay,
        maxDelay: maxDelay ?? this.maxDelay,
        backoffMultiplier: backoffMultiplier ?? this.backoffMultiplier,
        useJitter: useJitter ?? this.useJitter,
      );
}
