import 'dart:async';
import 'dart:math';

import '../callbacks/image_callbacks.dart';
import '../models/retry_config.dart';
import '../models/smart_image_exception.dart';
import '../utils/logger.dart';

/// Executes an asynchronous operation with automatic retries, exponential
/// backoff and jitter, as configured by a [RetryConfig].
///
/// Only failures the pipeline considers transient are retried: a thrown
/// [SmartImageException] is consulted via [SmartImageException.isRetryable], so
/// a 404 or a decode error fails fast while a 503 or a dropped connection is
/// retried. Non-`SmartImageException` errors are treated as retryable on the
/// assumption they originate from the transport layer.
class RetryEngine {
  /// Creates an engine bound to [config]. A [Random] can be injected so jitter
  /// is deterministic in tests.
  RetryEngine(this.config, {Random? random}) : _random = random ?? Random();

  /// The retry policy.
  final RetryConfig config;
  final Random _random;

  /// Runs [action], retrying on retryable failures up to
  /// [RetryConfig.maxAttempts] times.
  ///
  /// [onRetry] fires before each retry with the 1-based attempt number and the
  /// triggering error. [isCancelled], when supplied and returning `true`,
  /// aborts further retries — used to stop work for a disposed widget.
  ///
  /// Rethrows the last [SmartImageException] when all attempts are exhausted.
  Future<T> execute<T>(
    Future<T> Function() action, {
    OnRetry? onRetry,
    bool Function()? isCancelled,
  }) async {
    var attempt = 0;
    while (true) {
      try {
        return await action();
      } catch (error, stack) {
        final exception = _asException(error, stack);

        final exhausted = attempt >= config.maxAttempts;
        final cancelled = isCancelled?.call() ?? false;
        if (!exception.isRetryable || exhausted || cancelled) {
          rethrow;
        }

        attempt++;
        final delay = config.delayForAttempt(
          attempt,
          randomFactor: _random.nextDouble(),
        );
        SmartLogger.info(
          'Retry $attempt/${config.maxAttempts} in ${delay.inMilliseconds}ms '
          '(${exception.type.name})',
        );
        onRetry?.call(attempt, exception);

        await Future<void>.delayed(delay);
        if (isCancelled?.call() ?? false) rethrow;
      }
    }
  }

  SmartImageException _asException(Object error, StackTrace stack) {
    if (error is SmartImageException) return error;
    return SmartImageException(
      SmartImageErrorType.network,
      error.toString(),
      cause: error,
      stackTrace: stack,
    );
  }
}
