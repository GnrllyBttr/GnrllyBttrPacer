import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gnrllybttr_pacer/src/rate_limiter/async_rate_limiter.dart';
import 'package:gnrllybttr_pacer/src/rate_limiter/models.dart';
import 'package:gnrllybttr_pacer/src/common/common.dart';

void main() {
  group('AsyncRateLimiter', () {
    late AsyncRateLimiter<String> limiter;
    late List<String> executedItems;

    setUp(() {
      executedItems = [];
    });

    test('constructor with enabled options', () {
      limiter = AsyncRateLimiter<String>(
        (args) async {
          executedItems.add(args);
          return 'processed_$args';
        },
        AsyncRateLimiterOptions<String>(
          limit: 3,
          window: Duration(seconds: 60),
        ),
      );

      expect(limiter.options.enabled, true);
      expect(limiter.state.status, PacerStatus.idle);
      expect(limiter.state.isExceeded, false);
    });

    test('constructor with disabled options', () {
      limiter = AsyncRateLimiter<String>(
        (args) async {
          executedItems.add(args);
          return 'processed_$args';
        },
        AsyncRateLimiterOptions<String>(
          limit: 3,
          window: Duration(seconds: 60),
          enabled: false,
        ),
      );

      expect(limiter.options.enabled, false);
      expect(limiter.state.status, PacerStatus.disabled);
    });

    test('disabled limiter rejects maybeExecute calls', () async {
      limiter = AsyncRateLimiter<String>(
        (args) async {
          executedItems.add(args);
          return 'processed_$args';
        },
        AsyncRateLimiterOptions<String>(
          limit: 3,
          window: Duration(seconds: 60),
          enabled: false,
        ),
      );

      expect(() => limiter.maybeExecute('test'), throwsException);
      expect(executedItems, isEmpty);
    });

    test('maybeExecute allows execution within limit', () async {
      limiter = AsyncRateLimiter<String>(
        (args) async {
          executedItems.add(args);
          await Future.delayed(Duration(milliseconds: 10));
          return 'processed_$args';
        },
        AsyncRateLimiterOptions<String>(
          limit: 2,
          window: Duration(seconds: 60),
        ),
      );

      final result1 = await limiter.maybeExecute('first');
      final result2 = await limiter.maybeExecute('second');

      expect(result1, 'processed_first');
      expect(result2, 'processed_second');
      expect(executedItems, ['first', 'second']);
      expect(limiter.state.executionCount, 2);
      expect(limiter.state.isExceeded, false);
    });

    test('maybeExecute rejects when limit exceeded', () async {
      limiter = AsyncRateLimiter<String>(
        (args) async {
          executedItems.add(args);
          return 'processed_$args';
        },
        AsyncRateLimiterOptions<String>(
          limit: 2,
          window: Duration(seconds: 60),
        ),
      );

      await limiter.maybeExecute('first');
      await limiter.maybeExecute('second');
      final result3 = await limiter.maybeExecute('third');

      expect(result3, null);
      expect(executedItems, ['first', 'second']);
      expect(limiter.state.rejectionCount, 1);
      expect(limiter.state.isExceeded, true);
    });

    test('getRemainingInWindow returns correct count', () async {
      limiter = AsyncRateLimiter<String>(
        (args) async {
          executedItems.add(args);
          return 'processed_$args';
        },
        AsyncRateLimiterOptions<String>(
          limit: 3,
          window: Duration(seconds: 60),
        ),
      );

      expect(limiter.getRemainingInWindow(), 3);

      await limiter.maybeExecute('first');
      expect(limiter.getRemainingInWindow(), 2);

      await limiter.maybeExecute('second');
      expect(limiter.getRemainingInWindow(), 1);

      await limiter.maybeExecute('third');
      expect(limiter.getRemainingInWindow(), 0);

      final result = await limiter.maybeExecute('fourth'); // rejected
      expect(result, null);
      expect(limiter.getRemainingInWindow(), 0);
    });

    test('getMsUntilNextWindow returns zero when no executions', () {
      limiter = AsyncRateLimiter<String>(
        (args) async {
          executedItems.add(args);
          return 'processed_$args';
        },
        AsyncRateLimiterOptions<String>(
          limit: 3,
          window: Duration(seconds: 60),
        ),
      );

      final waitTime = limiter.getMsUntilNextWindow();
      expect(waitTime, Duration.zero);
    });

    test('getMsUntilNextWindow returns time until window resets', () async {
      limiter = AsyncRateLimiter<String>(
        (args) async {
          executedItems.add(args);
          return 'processed_$args';
        },
        AsyncRateLimiterOptions<String>(
          limit: 2,
          window: Duration(seconds: 10),
        ),
      );

      await limiter.maybeExecute('first');
      final waitTime = limiter.getMsUntilNextWindow();
      expect(waitTime.inSeconds, greaterThan(0));
      expect(waitTime.inSeconds, lessThanOrEqualTo(10));
    });

    test('reset clears execution history', () async {
      limiter = AsyncRateLimiter<String>(
        (args) async {
          executedItems.add(args);
          return 'processed_$args';
        },
        AsyncRateLimiterOptions<String>(
          limit: 2,
          window: Duration(seconds: 60),
        ),
      );

      await limiter.maybeExecute('first');
      await limiter.maybeExecute('second');
      await limiter.maybeExecute('third'); // rejected

      expect(limiter.state.executionCount, 2);
      expect(limiter.state.rejectionCount, 1);
      expect(limiter.state.isExceeded, true);

      limiter.reset();

      expect(limiter.state.executionCount, 0);
      expect(limiter.state.rejectionCount, 0);
      expect(limiter.state.isExceeded, false);
      expect(limiter.state.executionTimes, isEmpty);

      // Should allow execution again
      final result = await limiter.maybeExecute('fourth');
      expect(result, 'processed_fourth');
      expect(executedItems, ['first', 'second', 'fourth']);
    });

    test('setOptions with disabled option', () {
      limiter = AsyncRateLimiter<String>(
        (args) async {
          executedItems.add(args);
          return 'processed_$args';
        },
        AsyncRateLimiterOptions<String>(
          limit: 3,
          window: Duration(seconds: 60),
        ),
      );

      // maybeExecute starts execution
      limiter.maybeExecute('test');
      expect(limiter.state.status, PacerStatus.executing);

      limiter.setOptions(AsyncRateLimiterOptions<String>(
        limit: 3,
        window: Duration(seconds: 60),
        enabled: false,
      ));

      expect(limiter.options.enabled, false);
      expect(limiter.state.status, PacerStatus.disabled);
    });

    test('setOptions with enabled option', () {
      limiter = AsyncRateLimiter<String>(
        (args) async {
          executedItems.add(args);
          return 'processed_$args';
        },
        AsyncRateLimiterOptions<String>(
          limit: 3,
          window: Duration(seconds: 60),
          enabled: false,
        ),
      );

      expect(limiter.state.status, PacerStatus.disabled);

      limiter.setOptions(AsyncRateLimiterOptions<String>(
        limit: 3,
        window: Duration(seconds: 60),
        enabled: true,
      ));

      expect(limiter.options.enabled, true);
      expect(limiter.state.status, PacerStatus.idle);
    });

    test('fixed window type', () async {
      limiter = AsyncRateLimiter<String>(
        (args) async {
          executedItems.add(args);
          return 'processed_$args';
        },
        AsyncRateLimiterOptions<String>(
          limit: 2,
          window: Duration(seconds: 1),
          windowType: WindowType.fixed,
        ),
      );

      await limiter.maybeExecute('first');
      await limiter.maybeExecute('second');
      final result3 = await limiter.maybeExecute('third');
      expect(result3, null); // Should be rejected
    });

    test('sliding window type', () async {
      limiter = AsyncRateLimiter<String>(
        (args) async {
          executedItems.add(args);
          return 'processed_$args';
        },
        AsyncRateLimiterOptions<String>(
          limit: 2,
          window: Duration(seconds: 10),
          windowType: WindowType.sliding,
        ),
      );

      await limiter.maybeExecute('first');
      await limiter.maybeExecute('second');
      final result3 = await limiter.maybeExecute('third');
      expect(result3, null); // Should be rejected
    });

    test('onExecute callback is called', () async {
      List<String> executedArgs = [];

      limiter = AsyncRateLimiter<String>(
        (args) async {
          executedItems.add(args);
          return 'processed_$args';
        },
        AsyncRateLimiterOptions<String>(
          limit: 3,
          window: Duration(seconds: 60),
          onExecute: (args) => executedArgs.add(args),
        ),
      );

      await limiter.maybeExecute('first');
      await limiter.maybeExecute('second');

      expect(executedArgs, ['first', 'second']);
    });

    test('onReject callback is called', () async {
      List<String> rejectedArgs = [];

      limiter = AsyncRateLimiter<String>(
        (args) async {
          executedItems.add(args);
          return 'processed_$args';
        },
        AsyncRateLimiterOptions<String>(
          limit: 2,
          window: Duration(seconds: 60),
          onReject: (args) => rejectedArgs.add(args),
        ),
      );

      await limiter.maybeExecute('first');
      await limiter.maybeExecute('second');
      await limiter.maybeExecute('third'); // rejected

      expect(rejectedArgs, ['third']);
    });

    test('onSuccess callback is called', () async {
      List<String> successResults = [];

      limiter = AsyncRateLimiter<String>(
        (args) async {
          executedItems.add(args);
          return 'processed_$args';
        },
        AsyncRateLimiterOptions<String>(
          limit: 3,
          window: Duration(seconds: 60),
          onSuccess: (result) => successResults.add(result),
        ),
      );

      await limiter.maybeExecute('first');
      await limiter.maybeExecute('second');

      expect(successResults, ['processed_first', 'processed_second']);
    });

    test('maybeExecuteCount tracks total attempts', () async {
      limiter = AsyncRateLimiter<String>(
        (args) async {
          executedItems.add(args);
          return 'processed_$args';
        },
        AsyncRateLimiterOptions<String>(
          limit: 2,
          window: Duration(seconds: 60),
        ),
      );

      await limiter.maybeExecute('first');
      await limiter.maybeExecute('second');
      await limiter.maybeExecute('third'); // rejected
      await limiter.maybeExecute('fourth'); // rejected

      expect(limiter.state.maybeExecuteCount, 4);
      expect(limiter.state.executionCount, 2);
      expect(limiter.state.rejectionCount, 2);
    });

    test('execution times are tracked', () async {
      limiter = AsyncRateLimiter<String>(
        (args) async {
          executedItems.add(args);
          return 'processed_$args';
        },
        AsyncRateLimiterOptions<String>(
          limit: 3,
          window: Duration(seconds: 60),
        ),
      );

      final before = DateTime.now();
      await limiter.maybeExecute('first');
      await limiter.maybeExecute('second');
      final after = DateTime.now();

      expect(limiter.state.executionTimes.length, 2);
      expect(limiter.state.executionTimes[0].isAfter(before), true);
      expect(limiter.state.executionTimes[1].isBefore(after), true);
    });

    test('error handling with throwOnError false', () async {
      limiter = AsyncRateLimiter<String>(
        (args) async {
          if (args == 'error') {
            throw Exception('Test error');
          }
          executedItems.add(args);
          return 'processed_$args';
        },
        AsyncRateLimiterOptions<String>(
          limit: 3,
          window: Duration(seconds: 60),
          throwOnError: false,
        ),
      );

      final result = await limiter.maybeExecute('error');
      expect(result, null);
      expect(limiter.state.errorCount, 1);
      expect(executedItems, isEmpty);
    });

    test('error handling with throwOnError true', () async {
      limiter = AsyncRateLimiter<String>(
        (args) async {
          if (args == 'error') {
            throw Exception('Test error');
          }
          executedItems.add(args);
          return 'processed_$args';
        },
        AsyncRateLimiterOptions<String>(
          limit: 3,
          window: Duration(seconds: 60),
          throwOnError: true,
        ),
      );

      expect(() async => await limiter.maybeExecute('error'), throwsException);
      // Wait for the error to be processed
      await Future.delayed(Duration(milliseconds: 10));
      expect(limiter.state.errorCount, 1);
    });

    test('abort resets to idle state', () async {
      limiter = AsyncRateLimiter<String>(
        (args) async {
          executedItems.add(args);
          return 'processed_$args';
        },
        AsyncRateLimiterOptions<String>(
          limit: 3,
          window: Duration(seconds: 60),
        ),
      );

      await limiter.maybeExecute('first');
      expect(limiter.state.status, PacerStatus.idle);

      limiter.abort();
      expect(limiter.state.status, PacerStatus.idle);
    });
  });
}