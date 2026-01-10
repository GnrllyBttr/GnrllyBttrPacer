import 'package:flutter_test/flutter_test.dart';
import 'package:gnrllybttr_pacer/src/rate_limiter/models.dart';
import 'package:gnrllybttr_pacer/src/common/common.dart';

void main() {
  group('AsyncRateLimiterOptions', () {
    test('constructor with default values', () {
      const options = AsyncRateLimiterOptions<String>(
        limit: 10,
        window: Duration(seconds: 60),
      );

      expect(options.enabled, true);
      expect(options.key, null);
      expect(options.limit, 10);
      expect(options.window, const Duration(seconds: 60));
      expect(options.windowType, WindowType.fixed);
      expect(options.onExecute, null);
      expect(options.onReject, null);
      expect(options.onSuccess, null);
      expect(options.onError, null);
      expect(options.onSettled, null);
      expect(options.throwOnError, false);
    });

    test('constructor with custom values', () {
      void onExecute(String args) {}
      void onReject(String args) {}
      void onSuccess(dynamic result) {}
      void onError(dynamic error) {}
      void onSettled(dynamic result, dynamic error) {}

      final options = AsyncRateLimiterOptions<String>(
        enabled: false,
        key: 'test-key',
        limit: 5,
        window: const Duration(minutes: 1),
        windowType: WindowType.sliding,
        onExecute: onExecute,
        onReject: onReject,
        onSuccess: onSuccess,
        onError: onError,
        onSettled: onSettled,
        throwOnError: true,
      );

      expect(options.enabled, false);
      expect(options.key, 'test-key');
      expect(options.limit, 5);
      expect(options.window, const Duration(minutes: 1));
      expect(options.windowType, WindowType.sliding);
      expect(options.onExecute, isNotNull);
      expect(options.onReject, isNotNull);
      expect(options.onSuccess, isNotNull);
      expect(options.onError, isNotNull);
      expect(options.onSettled, isNotNull);
      expect(options.throwOnError, true);
    });

    test('extends PacerOptions', () {
      const options = AsyncRateLimiterOptions<int>(
        limit: 10,
        window: Duration(seconds: 60),
      );
      expect(options, isA<PacerOptions>());
    });
  });

  group('AsyncRateLimiterState', () {
    test('constructor with default values', () {
      const state = AsyncRateLimiterState<String>();

      expect(state.executionCount, 0);
      expect(state.status, PacerStatus.idle);
      expect(state.maybeExecuteCount, 0);
      expect(state.rejectionCount, 0);
      expect(state.executionTimes, const <DateTime>[]);
      expect(state.isExceeded, false);
      expect(state.errorCount, 0);
      expect(state.successCount, 0);
      expect(state.settleCount, 0);
      expect(state.isExecuting, false);
      expect(state.lastResult, null);
    });

    test('constructor with custom values', () {
      final executionTimes = [DateTime.now(), DateTime.now().subtract(const Duration(seconds: 30))];

      final state = AsyncRateLimiterState<String>(
        executionCount: 5,
        status: PacerStatus.executing,
        maybeExecuteCount: 8,
        rejectionCount: 3,
        executionTimes: executionTimes,
        isExceeded: true,
        errorCount: 1,
        successCount: 4,
        settleCount: 5,
        isExecuting: true,
        lastResult: 'success',
      );

      expect(state.executionCount, 5);
      expect(state.status, PacerStatus.executing);
      expect(state.maybeExecuteCount, 8);
      expect(state.rejectionCount, 3);
      expect(state.executionTimes, executionTimes);
      expect(state.isExceeded, true);
      expect(state.errorCount, 1);
      expect(state.successCount, 4);
      expect(state.settleCount, 5);
      expect(state.isExecuting, true);
      expect(state.lastResult, 'success');
    });

    test('extends PacerState', () {
      const state = AsyncRateLimiterState<int>();
      expect(state, isA<PacerState>());
    });

    group('copyWith', () {
      test('copyWith with no arguments returns identical state', () {
        final executionTimes = [DateTime.now()];
        final original = AsyncRateLimiterState<String>(
          executionCount: 1,
          status: PacerStatus.executing,
          maybeExecuteCount: 3,
          rejectionCount: 2,
          executionTimes: executionTimes,
          isExceeded: true,
          errorCount: 0,
          successCount: 1,
          settleCount: 1,
          isExecuting: true,
          lastResult: 'result',
        );

        final copy = original.copyWith();

        expect(copy.executionCount, original.executionCount);
        expect(copy.status, original.status);
        expect(copy.maybeExecuteCount, original.maybeExecuteCount);
        expect(copy.rejectionCount, original.rejectionCount);
        expect(copy.executionTimes, original.executionTimes);
        expect(copy.isExceeded, original.isExceeded);
        expect(copy.errorCount, original.errorCount);
        expect(copy.successCount, original.successCount);
        expect(copy.settleCount, original.settleCount);
        expect(copy.isExecuting, original.isExecuting);
        expect(copy.lastResult, original.lastResult);
      });

      test('copyWith with executionCount', () {
        const original = AsyncRateLimiterState<String>();
        final copy = original.copyWith(executionCount: 5);
        expect(copy.executionCount, 5);
        expect(copy.status, original.status);
      });

      test('copyWith with status', () {
        const original = AsyncRateLimiterState<String>();
        final copy = original.copyWith(status: PacerStatus.executing);
        expect(copy.status, PacerStatus.executing);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with maybeExecuteCount', () {
        const original = AsyncRateLimiterState<String>();
        final copy = original.copyWith(maybeExecuteCount: 10);
        expect(copy.maybeExecuteCount, 10);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with rejectionCount', () {
        const original = AsyncRateLimiterState<String>();
        final copy = original.copyWith(rejectionCount: 3);
        expect(copy.rejectionCount, 3);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with executionTimes', () {
        const original = AsyncRateLimiterState<String>();
        final newExecutionTimes = [DateTime.now(), DateTime.now().add(const Duration(minutes: 1))];
        final copy = original.copyWith(executionTimes: newExecutionTimes);
        expect(copy.executionTimes, newExecutionTimes);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with isExceeded', () {
        const original = AsyncRateLimiterState<String>();
        final copy = original.copyWith(isExceeded: true);
        expect(copy.isExceeded, true);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with errorCount', () {
        const original = AsyncRateLimiterState<String>();
        final copy = original.copyWith(errorCount: 3);
        expect(copy.errorCount, 3);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with successCount', () {
        const original = AsyncRateLimiterState<String>();
        final copy = original.copyWith(successCount: 7);
        expect(copy.successCount, 7);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with settleCount', () {
        const original = AsyncRateLimiterState<String>();
        final copy = original.copyWith(settleCount: 10);
        expect(copy.settleCount, 10);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with isExecuting', () {
        const original = AsyncRateLimiterState<String>();
        final copy = original.copyWith(isExecuting: true);
        expect(copy.isExecuting, true);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with lastResult', () {
        const original = AsyncRateLimiterState<String>();
        final copy = original.copyWith(lastResult: 'new result');
        expect(copy.lastResult, 'new result');
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with multiple fields', () {
        const original = AsyncRateLimiterState<String>();
        final copy = original.copyWith(
          executionCount: 2,
          status: PacerStatus.executing,
          rejectionCount: 5,
          isExecuting: true,
        );

        expect(copy.executionCount, 2);
        expect(copy.status, PacerStatus.executing);
        expect(copy.rejectionCount, 5);
        expect(copy.isExecuting, true);
        // Other fields should remain unchanged
        expect(copy.executionTimes, original.executionTimes);
        expect(copy.isExceeded, original.isExceeded);
      });
    });
  });

  group('RateLimiterOptions', () {
    test('constructor with default values', () {
      const options = RateLimiterOptions<String>(
        limit: 10,
        window: Duration(seconds: 60),
      );

      expect(options.enabled, true);
      expect(options.key, null);
      expect(options.limit, 10);
      expect(options.window, const Duration(seconds: 60));
      expect(options.windowType, WindowType.fixed);
      expect(options.onExecute, null);
      expect(options.onReject, null);
    });

    test('constructor with custom values', () {
      void onExecute(String args) {}
      void onReject(String args) {}

      final options = RateLimiterOptions<String>(
        enabled: false,
        key: 'rate-key',
        limit: 20,
        window: const Duration(minutes: 5),
        windowType: WindowType.sliding,
        onExecute: onExecute,
        onReject: onReject,
      );

      expect(options.enabled, false);
      expect(options.key, 'rate-key');
      expect(options.limit, 20);
      expect(options.window, const Duration(minutes: 5));
      expect(options.windowType, WindowType.sliding);
      expect(options.onExecute, isNotNull);
      expect(options.onReject, isNotNull);
    });

    test('extends PacerOptions', () {
      const options = RateLimiterOptions<int>(
        limit: 10,
        window: Duration(seconds: 60),
      );
      expect(options, isA<PacerOptions>());
    });
  });

  group('RateLimiterState', () {
    test('constructor with default values', () {
      const state = RateLimiterState<String>();

      expect(state.executionCount, 0);
      expect(state.status, PacerStatus.idle);
      expect(state.maybeExecuteCount, 0);
      expect(state.rejectionCount, 0);
      expect(state.executionTimes, const <DateTime>[]);
      expect(state.isExceeded, false);
    });

    test('constructor with custom values', () {
      final executionTimes = [
        DateTime.now(),
        DateTime.now().subtract(const Duration(seconds: 10)),
        DateTime.now().subtract(const Duration(seconds: 20))
      ];

      final state = RateLimiterState<String>(
        executionCount: 3,
        status: PacerStatus.executing,
        maybeExecuteCount: 6,
        rejectionCount: 3,
        executionTimes: executionTimes,
        isExceeded: true,
      );

      expect(state.executionCount, 3);
      expect(state.status, PacerStatus.executing);
      expect(state.maybeExecuteCount, 6);
      expect(state.rejectionCount, 3);
      expect(state.executionTimes, executionTimes);
      expect(state.isExceeded, true);
    });

    test('extends PacerState', () {
      const state = RateLimiterState<int>();
      expect(state, isA<PacerState>());
    });

    group('copyWith', () {
      test('copyWith with no arguments returns identical state', () {
        final executionTimes = [DateTime.now(), DateTime.now().add(const Duration(hours: 1))];
        final original = RateLimiterState<String>(
          executionCount: 2,
          status: PacerStatus.executing,
          maybeExecuteCount: 4,
          rejectionCount: 2,
          executionTimes: executionTimes,
          isExceeded: true,
        );

        final copy = original.copyWith();

        expect(copy.executionCount, original.executionCount);
        expect(copy.status, original.status);
        expect(copy.maybeExecuteCount, original.maybeExecuteCount);
        expect(copy.rejectionCount, original.rejectionCount);
        expect(copy.executionTimes, original.executionTimes);
        expect(copy.isExceeded, original.isExceeded);
      });

      test('copyWith with executionCount', () {
        const original = RateLimiterState<String>();
        final copy = original.copyWith(executionCount: 7);
        expect(copy.executionCount, 7);
        expect(copy.status, original.status);
      });

      test('copyWith with status', () {
        const original = RateLimiterState<String>();
        final copy = original.copyWith(status: PacerStatus.executing);
        expect(copy.status, PacerStatus.executing);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with maybeExecuteCount', () {
        const original = RateLimiterState<String>();
        final copy = original.copyWith(maybeExecuteCount: 15);
        expect(copy.maybeExecuteCount, 15);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with rejectionCount', () {
        const original = RateLimiterState<String>();
        final copy = original.copyWith(rejectionCount: 5);
        expect(copy.rejectionCount, 5);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with executionTimes', () {
        const original = RateLimiterState<String>();
        final newExecutionTimes = [DateTime.now(), DateTime.now().add(const Duration(days: 1))];
        final copy = original.copyWith(executionTimes: newExecutionTimes);
        expect(copy.executionTimes, newExecutionTimes);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with isExceeded', () {
        const original = RateLimiterState<String>();
        final copy = original.copyWith(isExceeded: true);
        expect(copy.isExceeded, true);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with multiple fields', () {
        const original = RateLimiterState<String>();
        final copy = original.copyWith(
          executionCount: 4,
          status: PacerStatus.executing,
          rejectionCount: 8,
          isExceeded: true,
        );

        expect(copy.executionCount, 4);
        expect(copy.status, PacerStatus.executing);
        expect(copy.rejectionCount, 8);
        expect(copy.isExceeded, true);
        // Other fields should remain unchanged
        expect(copy.executionTimes, original.executionTimes);
        expect(copy.maybeExecuteCount, original.maybeExecuteCount);
      });
    });
  });

  group('Type safety', () {
    test('AsyncRateLimiterOptions supports different generic types', () {
      const stringOptions = AsyncRateLimiterOptions<String>(
        limit: 10,
        window: Duration(seconds: 60),
      );
      const intOptions = AsyncRateLimiterOptions<int>(
        limit: 10,
        window: Duration(seconds: 60),
      );
      const customOptions = AsyncRateLimiterOptions<Map<String, dynamic>>(
        limit: 10,
        window: Duration(seconds: 60),
      );

      expect(stringOptions, isA<AsyncRateLimiterOptions<String>>());
      expect(intOptions, isA<AsyncRateLimiterOptions<int>>());
      expect(customOptions, isA<AsyncRateLimiterOptions<Map<String, dynamic>>>());
    });

    test('AsyncRateLimiterState supports different generic types', () {
      const stringState = AsyncRateLimiterState<String>();
      const intState = AsyncRateLimiterState<int>();
      const customState = AsyncRateLimiterState<Map<String, dynamic>>();

      expect(stringState, isA<AsyncRateLimiterState<String>>());
      expect(intState, isA<AsyncRateLimiterState<int>>());
      expect(customState, isA<AsyncRateLimiterState<Map<String, dynamic>>>());
    });

    test('RateLimiterOptions supports different generic types', () {
      const stringOptions = RateLimiterOptions<String>(
        limit: 10,
        window: Duration(seconds: 60),
      );
      const intOptions = RateLimiterOptions<int>(
        limit: 10,
        window: Duration(seconds: 60),
      );
      const customOptions = RateLimiterOptions<Map<String, dynamic>>(
        limit: 10,
        window: Duration(seconds: 60),
      );

      expect(stringOptions, isA<RateLimiterOptions<String>>());
      expect(intOptions, isA<RateLimiterOptions<int>>());
      expect(customOptions, isA<RateLimiterOptions<Map<String, dynamic>>>());
    });

    test('RateLimiterState supports different generic types', () {
      const stringState = RateLimiterState<String>();
      const intState = RateLimiterState<int>();
      const customState = RateLimiterState<Map<String, dynamic>>();

      expect(stringState, isA<RateLimiterState<String>>());
      expect(intState, isA<RateLimiterState<int>>());
      expect(customState, isA<RateLimiterState<Map<String, dynamic>>>());
    });
  });

  group('Immutability', () {
    test('AsyncRateLimiterState copyWith creates new instance', () {
      final executionTimes = [DateTime.now()];
      final original = AsyncRateLimiterState<String>(
        executionTimes: executionTimes,
        executionCount: 1,
      );

      final copy = original.copyWith(executionCount: 2);

      expect(original.executionCount, 1);
      expect(copy.executionCount, 2);
      expect(original.executionTimes, executionTimes);
      expect(copy.executionTimes, executionTimes); // Should share the same list reference
    });

    test('RateLimiterState copyWith creates new instance', () {
      final executionTimes = [DateTime.now()];
      final original = RateLimiterState<String>(
        executionTimes: executionTimes,
        executionCount: 1,
      );

      final copy = original.copyWith(executionCount: 2);

      expect(original.executionCount, 1);
      expect(copy.executionCount, 2);
      expect(original.executionTimes, executionTimes);
      expect(copy.executionTimes, executionTimes); // Should share the same list reference
    });
  });
}