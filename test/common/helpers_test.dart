import 'package:flutter_test/flutter_test.dart';
import 'package:gnrllybttr_pacer/src/common/helpers.dart';
import 'package:gnrllybttr_pacer/src/common/common.dart';
import 'package:gnrllybttr_pacer/src/debouncer/models.dart';
import 'package:gnrllybttr_pacer/src/throttler/models.dart';
import 'package:gnrllybttr_pacer/src/rate_limiter/models.dart';
import 'package:gnrllybttr_pacer/src/queuer/models.dart';
import 'package:gnrllybttr_pacer/src/batcher/models.dart';
import 'package:gnrllybttr_pacer/src/retryer/models.dart';

void main() {
  test('can import classes', () {
    // Just test that we can create the option classes
    final debounceOptions = DebouncerOptions<String>(wait: Duration(milliseconds: 50));
    expect(debounceOptions, isA<DebouncerOptions<String>>());

    final throttleOptions = ThrottlerOptions<int>(wait: Duration(milliseconds: 100));
    expect(throttleOptions, isA<ThrottlerOptions<int>>());

    final rateLimitOptions = RateLimiterOptions<String>(limit: 5, window: Duration(seconds: 60));
    expect(rateLimitOptions, isA<RateLimiterOptions<String>>());

    final queueOptions = QueuerOptions<String>(maxSize: 10);
    expect(queueOptions, isA<QueuerOptions<String>>());

    final batchOptions = BatcherOptions<String>(maxSize: 5);
    expect(batchOptions, isA<BatcherOptions<String>>());

    final retryOptions = AsyncRetryerOptions<String>(maxAttempts: 3);
    expect(retryOptions, isA<AsyncRetryerOptions<String>>());
  });

  group('isFunction', () {
    test('isFunction identifies functions', () {
      expect(isFunction(() {}), true);
      expect(isFunction((x) => x), true);
      expect(isFunction(isFunction), true);

      expect(isFunction('string'), false);
      expect(isFunction(42), false);
      expect(isFunction(null), false);
      expect(isFunction([]), false);
    });
  });

  group('parseFunctionOrValue', () {
    test('parseFunctionOrValue handles static values', () {
      expect(parseFunctionOrValue('static'), 'static');
      expect(parseFunctionOrValue(42), 42);
      expect(parseFunctionOrValue(null), null);
    });

    test('parseFunctionOrValue calls functions', () {
      expect(parseFunctionOrValue((args) => 'computed from ${args[0]}', args: ['input']), 'computed from input');
      expect(parseFunctionOrValue((args) => args[0], args: ['param']), 'param');
      expect(parseFunctionOrValue((args) => 42, args: []), 42);
    });

    test('parseFunctionOrValue handles empty args', () {
      expect(parseFunctionOrValue((args) => 'no args', args: []), 'no args');
    });
  });
}