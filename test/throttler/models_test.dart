import 'package:flutter_test/flutter_test.dart';
import 'package:gnrllybttr_pacer/src/throttler/models.dart';
import 'package:gnrllybttr_pacer/src/common/common.dart';

void main() {
  group('AsyncThrottlerOptions', () {
    test('constructor with default values', () {
      const options = AsyncThrottlerOptions<String>(
        wait: Duration(seconds: 1),
      );

      expect(options.enabled, true);
      expect(options.key, null);
      expect(options.wait, const Duration(seconds: 1));
      expect(options.leading, true);
      expect(options.trailing, true);
      expect(options.onExecute, null);
      expect(options.onSuccess, null);
      expect(options.onError, null);
      expect(options.onSettled, null);
      expect(options.throwOnError, false);
    });

    test('constructor with custom values', () {
      void onExecute(String args) {}
      void onSuccess(dynamic result) {}
      void onError(dynamic error) {}
      void onSettled(dynamic result, dynamic error) {}

      final options = AsyncThrottlerOptions<String>(
        enabled: false,
        key: 'test-key',
        wait: const Duration(milliseconds: 500),
        leading: false,
        trailing: false,
        onExecute: onExecute,
        onSuccess: onSuccess,
        onError: onError,
        onSettled: onSettled,
        throwOnError: true,
      );

      expect(options.enabled, false);
      expect(options.key, 'test-key');
      expect(options.wait, const Duration(milliseconds: 500));
      expect(options.leading, false);
      expect(options.trailing, false);
      expect(options.onExecute, isNotNull);
      expect(options.onSuccess, isNotNull);
      expect(options.onError, isNotNull);
      expect(options.onSettled, isNotNull);
      expect(options.throwOnError, true);
    });

    test('extends PacerOptions', () {
      const options = AsyncThrottlerOptions<int>(
        wait: Duration(seconds: 1),
      );
      expect(options, isA<PacerOptions>());
    });
  });

  group('AsyncThrottlerState', () {
    test('constructor with default values', () {
      const state = AsyncThrottlerState<String>();

      expect(state.executionCount, 0);
      expect(state.status, PacerStatus.idle);
      expect(state.maybeExecuteCount, 0);
      expect(state.lastArgs, null);
      expect(state.lastExecutionTime, null);
      expect(state.nextExecutionTime, null);
      expect(state.errorCount, 0);
      expect(state.successCount, 0);
      expect(state.settleCount, 0);
      expect(state.isExecuting, false);
      expect(state.lastResult, null);
    });

    test('constructor with custom values', () {
      final lastExecutionTime = DateTime.now();
      final nextExecutionTime = DateTime.now().add(const Duration(seconds: 1));

      final state = AsyncThrottlerState<String>(
        executionCount: 5,
        status: PacerStatus.executing,
        maybeExecuteCount: 8,
        lastArgs: 'test-args',
        lastExecutionTime: lastExecutionTime,
        nextExecutionTime: nextExecutionTime,
        errorCount: 1,
        successCount: 4,
        settleCount: 5,
        isExecuting: true,
        lastResult: 'success',
      );

      expect(state.executionCount, 5);
      expect(state.status, PacerStatus.executing);
      expect(state.maybeExecuteCount, 8);
      expect(state.lastArgs, 'test-args');
      expect(state.lastExecutionTime, lastExecutionTime);
      expect(state.nextExecutionTime, nextExecutionTime);
      expect(state.errorCount, 1);
      expect(state.successCount, 4);
      expect(state.settleCount, 5);
      expect(state.isExecuting, true);
      expect(state.lastResult, 'success');
    });

    test('extends PacerState', () {
      const state = AsyncThrottlerState<int>();
      expect(state, isA<PacerState>());
    });

    group('copyWith', () {
      test('copyWith with no arguments returns identical state', () {
        final lastExecutionTime = DateTime.now();
        final nextExecutionTime = DateTime.now().add(const Duration(seconds: 1));
        final original = AsyncThrottlerState<String>(
          executionCount: 1,
          status: PacerStatus.executing,
          maybeExecuteCount: 3,
          lastArgs: 'args',
          lastExecutionTime: lastExecutionTime,
          nextExecutionTime: nextExecutionTime,
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
        expect(copy.lastArgs, original.lastArgs);
        expect(copy.lastExecutionTime, original.lastExecutionTime);
        expect(copy.nextExecutionTime, original.nextExecutionTime);
        expect(copy.errorCount, original.errorCount);
        expect(copy.successCount, original.successCount);
        expect(copy.settleCount, original.settleCount);
        expect(copy.isExecuting, original.isExecuting);
        expect(copy.lastResult, original.lastResult);
      });

      test('copyWith with executionCount', () {
        const original = AsyncThrottlerState<String>();
        final copy = original.copyWith(executionCount: 5);
        expect(copy.executionCount, 5);
        expect(copy.status, original.status);
      });

      test('copyWith with status', () {
        const original = AsyncThrottlerState<String>();
        final copy = original.copyWith(status: PacerStatus.executing);
        expect(copy.status, PacerStatus.executing);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with maybeExecuteCount', () {
        const original = AsyncThrottlerState<String>();
        final copy = original.copyWith(maybeExecuteCount: 10);
        expect(copy.maybeExecuteCount, 10);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with lastArgs', () {
        const original = AsyncThrottlerState<String>();
        final copy = original.copyWith(lastArgs: 'new-args');
        expect(copy.lastArgs, 'new-args');
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with lastExecutionTime', () {
        const original = AsyncThrottlerState<String>();
        final newTime = DateTime.now();
        final copy = original.copyWith(lastExecutionTime: newTime);
        expect(copy.lastExecutionTime, newTime);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with nextExecutionTime', () {
        const original = AsyncThrottlerState<String>();
        final newTime = DateTime.now().add(const Duration(minutes: 1));
        final copy = original.copyWith(nextExecutionTime: newTime);
        expect(copy.nextExecutionTime, newTime);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with errorCount', () {
        const original = AsyncThrottlerState<String>();
        final copy = original.copyWith(errorCount: 3);
        expect(copy.errorCount, 3);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with successCount', () {
        const original = AsyncThrottlerState<String>();
        final copy = original.copyWith(successCount: 7);
        expect(copy.successCount, 7);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with settleCount', () {
        const original = AsyncThrottlerState<String>();
        final copy = original.copyWith(settleCount: 10);
        expect(copy.settleCount, 10);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with isExecuting', () {
        const original = AsyncThrottlerState<String>();
        final copy = original.copyWith(isExecuting: true);
        expect(copy.isExecuting, true);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with lastResult', () {
        const original = AsyncThrottlerState<String>();
        final copy = original.copyWith(lastResult: 'new result');
        expect(copy.lastResult, 'new result');
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with multiple fields', () {
        const original = AsyncThrottlerState<String>();
        final copy = original.copyWith(
          executionCount: 2,
          status: PacerStatus.executing,
          maybeExecuteCount: 5,
          isExecuting: true,
        );

        expect(copy.executionCount, 2);
        expect(copy.status, PacerStatus.executing);
        expect(copy.maybeExecuteCount, 5);
        expect(copy.isExecuting, true);
        // Other fields should remain unchanged
        expect(copy.lastArgs, original.lastArgs);
        expect(copy.lastExecutionTime, original.lastExecutionTime);
      });
    });
  });

  group('ThrottlerOptions', () {
    test('constructor with default values', () {
      const options = ThrottlerOptions<String>(
        wait: Duration(seconds: 1),
      );

      expect(options.enabled, true);
      expect(options.key, null);
      expect(options.wait, const Duration(seconds: 1));
      expect(options.leading, true);
      expect(options.trailing, true);
      expect(options.onExecute, null);
    });

    test('constructor with custom values', () {
      void onExecute(String args) {}

      final options = ThrottlerOptions<String>(
        enabled: false,
        key: 'throttle-key',
        wait: const Duration(milliseconds: 200),
        leading: false,
        trailing: false,
        onExecute: onExecute,
      );

      expect(options.enabled, false);
      expect(options.key, 'throttle-key');
      expect(options.wait, const Duration(milliseconds: 200));
      expect(options.leading, false);
      expect(options.trailing, false);
      expect(options.onExecute, isNotNull);
    });

    test('extends PacerOptions', () {
      const options = ThrottlerOptions<int>(
        wait: Duration(seconds: 1),
      );
      expect(options, isA<PacerOptions>());
    });
  });

  group('ThrottlerState', () {
    test('constructor with default values', () {
      const state = ThrottlerState<String>();

      expect(state.executionCount, 0);
      expect(state.status, PacerStatus.idle);
      expect(state.maybeExecuteCount, 0);
      expect(state.lastArgs, null);
      expect(state.lastExecutionTime, null);
      expect(state.nextExecutionTime, null);
    });

    test('constructor with custom values', () {
      final lastExecutionTime = DateTime.now();
      final nextExecutionTime = DateTime.now().add(const Duration(seconds: 2));

      final state = ThrottlerState<String>(
        executionCount: 3,
        status: PacerStatus.executing,
        maybeExecuteCount: 6,
        lastArgs: 'test-args',
        lastExecutionTime: lastExecutionTime,
        nextExecutionTime: nextExecutionTime,
      );

      expect(state.executionCount, 3);
      expect(state.status, PacerStatus.executing);
      expect(state.maybeExecuteCount, 6);
      expect(state.lastArgs, 'test-args');
      expect(state.lastExecutionTime, lastExecutionTime);
      expect(state.nextExecutionTime, nextExecutionTime);
    });

    test('extends PacerState', () {
      const state = ThrottlerState<int>();
      expect(state, isA<PacerState>());
    });

    group('copyWith', () {
      test('copyWith with no arguments returns identical state', () {
        final lastExecutionTime = DateTime.now();
        final nextExecutionTime = DateTime.now().add(const Duration(seconds: 1));
        final original = ThrottlerState<String>(
          executionCount: 2,
          status: PacerStatus.executing,
          maybeExecuteCount: 4,
          lastArgs: 'args',
          lastExecutionTime: lastExecutionTime,
          nextExecutionTime: nextExecutionTime,
        );

        final copy = original.copyWith();

        expect(copy.executionCount, original.executionCount);
        expect(copy.status, original.status);
        expect(copy.maybeExecuteCount, original.maybeExecuteCount);
        expect(copy.lastArgs, original.lastArgs);
        expect(copy.lastExecutionTime, original.lastExecutionTime);
        expect(copy.nextExecutionTime, original.nextExecutionTime);
      });

      test('copyWith with executionCount', () {
        const original = ThrottlerState<String>();
        final copy = original.copyWith(executionCount: 7);
        expect(copy.executionCount, 7);
        expect(copy.status, original.status);
      });

      test('copyWith with status', () {
        const original = ThrottlerState<String>();
        final copy = original.copyWith(status: PacerStatus.executing);
        expect(copy.status, PacerStatus.executing);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with maybeExecuteCount', () {
        const original = ThrottlerState<String>();
        final copy = original.copyWith(maybeExecuteCount: 15);
        expect(copy.maybeExecuteCount, 15);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with lastArgs', () {
        const original = ThrottlerState<String>();
        final copy = original.copyWith(lastArgs: 'new-args');
        expect(copy.lastArgs, 'new-args');
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with lastExecutionTime', () {
        const original = ThrottlerState<String>();
        final newTime = DateTime.now().add(const Duration(hours: 1));
        final copy = original.copyWith(lastExecutionTime: newTime);
        expect(copy.lastExecutionTime, newTime);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with nextExecutionTime', () {
        const original = ThrottlerState<String>();
        final newTime = DateTime.now().add(const Duration(days: 1));
        final copy = original.copyWith(nextExecutionTime: newTime);
        expect(copy.nextExecutionTime, newTime);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with multiple fields', () {
        const original = ThrottlerState<String>();
        final copy = original.copyWith(
          executionCount: 4,
          status: PacerStatus.executing,
          maybeExecuteCount: 12,
        );

        expect(copy.executionCount, 4);
        expect(copy.status, PacerStatus.executing);
        expect(copy.maybeExecuteCount, 12);
        // Other fields should remain unchanged
        expect(copy.lastArgs, original.lastArgs);
        expect(copy.lastExecutionTime, original.lastExecutionTime);
      });
    });
  });

  group('Type safety', () {
    test('AsyncThrottlerOptions supports different generic types', () {
      const stringOptions = AsyncThrottlerOptions<String>(
        wait: Duration(seconds: 1),
      );
      const intOptions = AsyncThrottlerOptions<int>(
        wait: Duration(seconds: 1),
      );
      const customOptions = AsyncThrottlerOptions<Map<String, dynamic>>(
        wait: Duration(seconds: 1),
      );

      expect(stringOptions, isA<AsyncThrottlerOptions<String>>());
      expect(intOptions, isA<AsyncThrottlerOptions<int>>());
      expect(customOptions, isA<AsyncThrottlerOptions<Map<String, dynamic>>>());
    });

    test('AsyncThrottlerState supports different generic types', () {
      const stringState = AsyncThrottlerState<String>();
      const intState = AsyncThrottlerState<int>();
      const customState = AsyncThrottlerState<Map<String, dynamic>>();

      expect(stringState, isA<AsyncThrottlerState<String>>());
      expect(intState, isA<AsyncThrottlerState<int>>());
      expect(customState, isA<AsyncThrottlerState<Map<String, dynamic>>>());
    });

    test('ThrottlerOptions supports different generic types', () {
      const stringOptions = ThrottlerOptions<String>(
        wait: Duration(seconds: 1),
      );
      const intOptions = ThrottlerOptions<int>(
        wait: Duration(seconds: 1),
      );
      const customOptions = ThrottlerOptions<Map<String, dynamic>>(
        wait: Duration(seconds: 1),
      );

      expect(stringOptions, isA<ThrottlerOptions<String>>());
      expect(intOptions, isA<ThrottlerOptions<int>>());
      expect(customOptions, isA<ThrottlerOptions<Map<String, dynamic>>>());
    });

    test('ThrottlerState supports different generic types', () {
      const stringState = ThrottlerState<String>();
      const intState = ThrottlerState<int>();
      const customState = ThrottlerState<Map<String, dynamic>>();

      expect(stringState, isA<ThrottlerState<String>>());
      expect(intState, isA<ThrottlerState<int>>());
      expect(customState, isA<ThrottlerState<Map<String, dynamic>>>());
    });
  });

  group('Immutability', () {
    test('AsyncThrottlerState copyWith creates new instance', () {
      const original = AsyncThrottlerState<String>(
        lastArgs: 'original',
        executionCount: 1,
      );

      final copy = original.copyWith(executionCount: 2);

      expect(original.executionCount, 1);
      expect(copy.executionCount, 2);
      expect(original.lastArgs, 'original');
      expect(copy.lastArgs, 'original');
    });

    test('ThrottlerState copyWith creates new instance', () {
      const original = ThrottlerState<String>(
        lastArgs: 'original',
        executionCount: 1,
      );

      final copy = original.copyWith(executionCount: 2);

      expect(original.executionCount, 1);
      expect(copy.executionCount, 2);
      expect(original.lastArgs, 'original');
      expect(copy.lastArgs, 'original');
    });
  });
}