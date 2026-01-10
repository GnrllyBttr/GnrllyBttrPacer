import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gnrllybttr_pacer/src/rate_limiter/rate_limiter.dart';
import 'package:gnrllybttr_pacer/src/rate_limiter/models.dart';
import 'package:gnrllybttr_pacer/src/common/common.dart';

void main() {
  group('RateLimiter', () {
    late RateLimiter<String> limiter;
    late List<String> executedItems;

    setUp(() {
      executedItems = [];
    });

    test('constructor with enabled options', () {
      limiter = RateLimiter<String>(
        (args) {
          executedItems.add(args);
        },
        const RateLimiterOptions<String>(
          limit: 3,
          window: Duration(seconds: 60),
        ),
      );

      expect(limiter.options.enabled, true);
      expect(limiter.state.status, PacerStatus.idle);
      expect(limiter.state.isExceeded, false);
    });

    test('constructor with disabled options', () {
      limiter = RateLimiter<String>(
        (args) {
          executedItems.add(args);
        },
        const RateLimiterOptions<String>(
          limit: 3,
          window: Duration(seconds: 60),
          enabled: false,
        ),
      );

      expect(limiter.options.enabled, false);
      expect(limiter.state.status, PacerStatus.disabled);
    });

    test('disabled limiter ignores maybeExecute calls', () {
      limiter = RateLimiter<String>(
        (args) {
          executedItems.add(args);
        },
        const RateLimiterOptions<String>(
          limit: 3,
          window: Duration(seconds: 60),
          enabled: false,
        ),
      );

      final executed = limiter.maybeExecute('test');
      expect(executed, false);
      expect(executedItems, isEmpty);
    });

    test('maybeExecute allows execution within limit', () {
      limiter = RateLimiter<String>(
        (args) {
          executedItems.add(args);
        },
        const RateLimiterOptions<String>(
          limit: 2,
          window: Duration(seconds: 60),
        ),
      );

      final executed1 = limiter.maybeExecute('first');
      final executed2 = limiter.maybeExecute('second');

      expect(executed1, true);
      expect(executed2, true);
      expect(executedItems, ['first', 'second']);
      expect(limiter.state.executionCount, 2);
      expect(limiter.state.isExceeded, false);
    });

    test('maybeExecute rejects when limit exceeded', () {
      limiter = RateLimiter<String>(
        (args) {
          executedItems.add(args);
        },
        const RateLimiterOptions<String>(
          limit: 2,
          window: Duration(seconds: 60),
        ),
      );

      limiter.maybeExecute('first');
      limiter.maybeExecute('second');
      final executed3 = limiter.maybeExecute('third');

      expect(executed3, false);
      expect(executedItems, ['first', 'second']);
      expect(limiter.state.rejectionCount, 1);
      expect(limiter.state.isExceeded, true);
    });

    test('getRemainingInWindow returns correct count', () {
      limiter = RateLimiter<String>(
        (args) {
          executedItems.add(args);
        },
        const RateLimiterOptions<String>(
          limit: 3,
          window: Duration(seconds: 60),
        ),
      );

      expect(limiter.getRemainingInWindow(), 3);

      limiter.maybeExecute('first');
      expect(limiter.getRemainingInWindow(), 2);

      limiter.maybeExecute('second');
      expect(limiter.getRemainingInWindow(), 1);

      limiter.maybeExecute('third');
      expect(limiter.getRemainingInWindow(), 0);

      limiter.maybeExecute('fourth'); // rejected
      expect(limiter.getRemainingInWindow(), 0);
    });

    test('getMsUntilNextWindow returns zero when no executions', () {
      limiter = RateLimiter<String>(
        (args) {
          executedItems.add(args);
        },
        const RateLimiterOptions<String>(
          limit: 3,
          window: Duration(seconds: 60),
        ),
      );

      final waitTime = limiter.getMsUntilNextWindow();
      expect(waitTime, Duration.zero);
    });

    test('getMsUntilNextWindow returns time until window resets', () {
      limiter = RateLimiter<String>(
        (args) {
          executedItems.add(args);
        },
        const RateLimiterOptions<String>(
          limit: 2,
          window: Duration(seconds: 10),
        ),
      );

      limiter.maybeExecute('first');
      final waitTime = limiter.getMsUntilNextWindow();
      expect(waitTime.inSeconds, greaterThan(0));
      expect(waitTime.inSeconds, lessThanOrEqualTo(10));
    });

    test('reset clears execution history', () {
      limiter = RateLimiter<String>(
        (args) {
          executedItems.add(args);
        },
        const RateLimiterOptions<String>(
          limit: 2,
          window: Duration(seconds: 60),
        ),
      );

      limiter.maybeExecute('first');
      limiter.maybeExecute('second');
      limiter.maybeExecute('third'); // rejected

      expect(limiter.state.executionCount, 2);
      expect(limiter.state.rejectionCount, 1);
      expect(limiter.state.isExceeded, true);

      limiter.reset();

      expect(limiter.state.executionCount, 0);
      expect(limiter.state.rejectionCount, 0);
      expect(limiter.state.isExceeded, false);
      expect(limiter.state.executionTimes, isEmpty);

      // Should allow execution again
      final executed = limiter.maybeExecute('fourth');
      expect(executed, true);
      expect(executedItems, ['first', 'second', 'fourth']);
    });

    test('setOptions with disabled option', () {
      limiter = RateLimiter<String>(
        (args) {
          executedItems.add(args);
        },
        const RateLimiterOptions<String>(
          limit: 3,
          window: Duration(seconds: 60),
        ),
      );

      limiter.maybeExecute('test');
      expect(limiter.state.status, PacerStatus.idle);

      limiter.setOptions(
        const RateLimiterOptions<String>(
          limit: 3,
          window: Duration(seconds: 60),
          enabled: false,
        ),
      );

      expect(limiter.options.enabled, false);
      expect(limiter.state.status, PacerStatus.disabled);
    });

    test('setOptions with enabled option', () {
      limiter = RateLimiter<String>(
        (args) {
          executedItems.add(args);
        },
        const RateLimiterOptions<String>(
          limit: 3,
          window: Duration(seconds: 60),
          enabled: false,
        ),
      );

      expect(limiter.state.status, PacerStatus.disabled);

      limiter.setOptions(
        const RateLimiterOptions<String>(
          limit: 3,
          window: Duration(seconds: 60),
        ),
      );

      expect(limiter.options.enabled, true);
      expect(limiter.state.status, PacerStatus.idle);
    });

    test('fixed window type', () {
      limiter = RateLimiter<String>(
        (args) {
          executedItems.add(args);
        },
        const RateLimiterOptions<String>(
          limit: 2,
          window: Duration(seconds: 1),
        ),
      );

      limiter.maybeExecute('first');
      limiter.maybeExecute('second');
      expect(limiter.maybeExecute('third'), false); // Should be rejected

      // Wait for window to reset
      // Note: In a real test, you'd wait for the window duration
      // but for this test we just verify the logic works
    });

    test('sliding window type', () {
      limiter = RateLimiter<String>(
        (args) {
          executedItems.add(args);
        },
        const RateLimiterOptions<String>(
          limit: 2,
          window: Duration(seconds: 10),
          windowType: WindowType.sliding,
        ),
      );

      limiter.maybeExecute('first');
      limiter.maybeExecute('second');
      expect(limiter.maybeExecute('third'), false); // Should be rejected
    });

    test('onExecute callback is called', () {
      final List<String> executedArgs = [];

      limiter = RateLimiter<String>(
        (args) {
          executedItems.add(args);
        },
        RateLimiterOptions<String>(
          limit: 3,
          window: const Duration(seconds: 60),
          onExecute: executedArgs.add,
        ),
      );

      limiter.maybeExecute('first');
      limiter.maybeExecute('second');

      expect(executedArgs, ['first', 'second']);
    });

    test('onReject callback is called', () {
      final List<String> rejectedArgs = [];

      limiter = RateLimiter<String>(
        (args) {
          executedItems.add(args);
        },
        RateLimiterOptions<String>(
          limit: 2,
          window: const Duration(seconds: 60),
          onReject: rejectedArgs.add,
        ),
      );

      limiter.maybeExecute('first');
      limiter.maybeExecute('second');
      limiter.maybeExecute('third'); // rejected

      expect(rejectedArgs, ['third']);
    });

    test('maybeExecuteCount tracks total attempts', () {
      limiter = RateLimiter<String>(
        (args) {
          executedItems.add(args);
        },
        const RateLimiterOptions<String>(
          limit: 2,
          window: Duration(seconds: 60),
        ),
      );

      limiter.maybeExecute('first');
      limiter.maybeExecute('second');
      limiter.maybeExecute('third'); // rejected
      limiter.maybeExecute('fourth'); // rejected

      expect(limiter.state.maybeExecuteCount, 4);
      expect(limiter.state.executionCount, 2);
      expect(limiter.state.rejectionCount, 2);
    });

    test('execution times are tracked', () {
      limiter = RateLimiter<String>(
        (args) {
          executedItems.add(args);
        },
        const RateLimiterOptions<String>(
          limit: 3,
          window: Duration(seconds: 60),
        ),
      );

      final before = DateTime.now();
      limiter.maybeExecute('first');
      limiter.maybeExecute('second');
      final after = DateTime.now();

      expect(limiter.state.executionTimes.length, 2);
      expect(limiter.state.executionTimes[0].isAfter(before), true);
      expect(limiter.state.executionTimes[1].isBefore(after), true);
    });
  });
}
