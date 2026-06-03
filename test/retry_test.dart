import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_image_x/smart_image_x.dart';
import 'package:smart_image_x/src/retry/retry_engine.dart';

void main() {
  group('RetryConfig.delayForAttempt', () {
    test('applies exponential backoff', () {
      const config = RetryConfig(
        delay: Duration(milliseconds: 100),
        backoffMultiplier: 2,
        useJitter: false,
      );
      expect(config.delayForAttempt(1).inMilliseconds, 100);
      expect(config.delayForAttempt(2).inMilliseconds, 200);
      expect(config.delayForAttempt(3).inMilliseconds, 400);
    });

    test('caps at maxDelay', () {
      const config = RetryConfig(
        delay: Duration(seconds: 1),
        backoffMultiplier: 10,
        maxDelay: Duration(seconds: 5),
        useJitter: false,
      );
      expect(config.delayForAttempt(5).inSeconds, 5);
    });

    test('jitter never reduces below the base delay', () {
      const config = RetryConfig(
        delay: Duration(milliseconds: 100),
        backoffMultiplier: 1,
      );
      final delay = config.delayForAttempt(1, randomFactor: 1.0);
      expect(delay.inMilliseconds, greaterThanOrEqualTo(100));
      expect(delay.inMilliseconds, lessThanOrEqualTo(125));
    });

    test('disabled config performs no retries', () {
      expect(RetryConfig.disabled.isEnabled, isFalse);
    });
  });

  group('RetryEngine', () {
    test('returns immediately on success', () async {
      final engine = RetryEngine(const RetryConfig(maxAttempts: 3));
      var calls = 0;
      final result = await engine.execute(() async {
        calls++;
        return 'ok';
      });
      expect(result, 'ok');
      expect(calls, 1);
    });

    test('retries retryable failures then succeeds', () async {
      final engine = RetryEngine(
        const RetryConfig(
          maxAttempts: 3,
          delay: Duration(milliseconds: 1),
          useJitter: false,
        ),
        random: Random(0),
      );
      var calls = 0;
      final retries = <int>[];
      final result = await engine.execute(
        () async {
          calls++;
          if (calls < 3) {
            throw const SmartImageException(
              SmartImageErrorType.network,
              'flaky',
            );
          }
          return 'recovered';
        },
        onRetry: (attempt, _) => retries.add(attempt),
      );
      expect(result, 'recovered');
      expect(calls, 3);
      expect(retries, [1, 2]);
    });

    test('does not retry non-retryable failures', () async {
      final engine = RetryEngine(
        const RetryConfig(maxAttempts: 5, delay: Duration(milliseconds: 1)),
      );
      var calls = 0;
      await expectLater(
        engine.execute(() async {
          calls++;
          throw const SmartImageException(
            SmartImageErrorType.notFound,
            'gone',
          );
        }),
        throwsA(isA<SmartImageException>()),
      );
      expect(calls, 1);
    });

    test('gives up after maxAttempts and rethrows', () async {
      final engine = RetryEngine(
        const RetryConfig(
          maxAttempts: 2,
          delay: Duration(milliseconds: 1),
          useJitter: false,
        ),
      );
      var calls = 0;
      await expectLater(
        engine.execute(() async {
          calls++;
          throw const SmartImageException(
            SmartImageErrorType.network,
            'always fails',
          );
        }),
        throwsA(isA<SmartImageException>()),
      );
      expect(calls, 3); // 1 initial + 2 retries
    });

    test('stops retrying when cancelled', () async {
      final engine = RetryEngine(
        const RetryConfig(maxAttempts: 5, delay: Duration(milliseconds: 1)),
      );
      var calls = 0;
      await expectLater(
        engine.execute(
          () async {
            calls++;
            throw const SmartImageException(
              SmartImageErrorType.network,
              'fails',
            );
          },
          isCancelled: () => calls >= 1,
        ),
        throwsA(isA<SmartImageException>()),
      );
      expect(calls, 1);
    });
  });
}
