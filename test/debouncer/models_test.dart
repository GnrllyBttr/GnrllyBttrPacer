import 'package:flutter_test/flutter_test.dart';
import 'package:gnrllybttr_pacer/src/debouncer/models.dart';
import 'package:gnrllybttr_pacer/src/common/common.dart';

void main() {
  group('AsyncDebouncerOptions', () {
    test('constructor with default values', () {
      const options = AsyncDebouncerOptions<String>(
        wait: Duration(milliseconds: 100),
      );

      expect(options.enabled, true);
      expect(options.key, null);
      expect(options.wait, const Duration(milliseconds: 100));
      expect(options.leading, false);
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

      final options = AsyncDebouncerOptions<String>(
        enabled: false,
        key: 'test-key',
        wait: const Duration(seconds: 5),
        leading: true,
        trailing: false,
        onExecute: onExecute,
        onSuccess: onSuccess,
        onError: onError,
        onSettled: onSettled,
        throwOnError: true,
      );

      expect(options.enabled, false);
      expect(options.key, 'test-key');
      expect(options.wait, const Duration(seconds: 5));
      expect(options.leading, true);
      expect(options.trailing, false);
      expect(options.onExecute, isNotNull);
      expect(options.onSuccess, isNotNull);
      expect(options.onError, isNotNull);
      expect(options.onSettled, isNotNull);
      expect(options.throwOnError, true);
    });

    test('extends PacerOptions', () {
      const options = AsyncDebouncerOptions<int>(
        wait: Duration(milliseconds: 100),
      );
      expect(options, isA<PacerOptions>());
    });
  });

  group('AsyncDebouncerState', () {
    test('constructor with default values', () {
      const state = AsyncDebouncerState<String>();

      expect(state.executionCount, 0);
      expect(state.status, PacerStatus.idle);
      expect(state.maybeExecuteCount, 0);
      expect(state.lastArgs, null);
      expect(state.isPending, false);
      expect(state.errorCount, 0);
      expect(state.successCount, 0);
      expect(state.settleCount, 0);
      expect(state.isExecuting, false);
      expect(state.lastResult, null);
    });

    test('constructor with custom values', () {
      final state = AsyncDebouncerState<String>(
        executionCount: 5,
        status: PacerStatus.executing,
        maybeExecuteCount: 10,
        lastArgs: 'test-args',
        isPending: true,
        errorCount: 1,
        successCount: 4,
        settleCount: 5,
        isExecuting: true,
        lastResult: 'success',
      );

      expect(state.executionCount, 5);
      expect(state.status, PacerStatus.executing);
      expect(state.maybeExecuteCount, 10);
      expect(state.lastArgs, 'test-args');
      expect(state.isPending, true);
      expect(state.errorCount, 1);
      expect(state.successCount, 4);
      expect(state.settleCount, 5);
      expect(state.isExecuting, true);
      expect(state.lastResult, 'success');
    });

    test('extends PacerState', () {
      const state = AsyncDebouncerState<int>();
      expect(state, isA<PacerState>());
    });

    group('copyWith', () {
      test('copyWith with no arguments returns identical state', () {
        const original = AsyncDebouncerState<String>(
          executionCount: 1,
          status: PacerStatus.executing,
          maybeExecuteCount: 5,
          lastArgs: 'args',
          isPending: true,
          errorCount: 1,
          successCount: 0,
          settleCount: 1,
          isExecuting: true,
          lastResult: 'result',
        );

        final copy = original.copyWith();

        expect(copy.executionCount, original.executionCount);
        expect(copy.status, original.status);
        expect(copy.maybeExecuteCount, original.maybeExecuteCount);
        expect(copy.lastArgs, original.lastArgs);
        expect(copy.isPending, original.isPending);
        expect(copy.errorCount, original.errorCount);
        expect(copy.successCount, original.successCount);
        expect(copy.settleCount, original.settleCount);
        expect(copy.isExecuting, original.isExecuting);
        expect(copy.lastResult, original.lastResult);
      });

      test('copyWith with executionCount', () {
        const original = AsyncDebouncerState<String>();
        final copy = original.copyWith(executionCount: 5);
        expect(copy.executionCount, 5);
        expect(copy.status, original.status);
      });

      test('copyWith with status', () {
        const original = AsyncDebouncerState<String>();
        final copy = original.copyWith(status: PacerStatus.executing);
        expect(copy.status, PacerStatus.executing);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with maybeExecuteCount', () {
        const original = AsyncDebouncerState<String>();
        final copy = original.copyWith(maybeExecuteCount: 10);
        expect(copy.maybeExecuteCount, 10);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with lastArgs', () {
        const original = AsyncDebouncerState<String>();
        final copy = original.copyWith(lastArgs: 'new-args');
        expect(copy.lastArgs, 'new-args');
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with isPending', () {
        const original = AsyncDebouncerState<String>();
        final copy = original.copyWith(isPending: true);
        expect(copy.isPending, true);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with errorCount', () {
        const original = AsyncDebouncerState<String>();
        final copy = original.copyWith(errorCount: 3);
        expect(copy.errorCount, 3);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with successCount', () {
        const original = AsyncDebouncerState<String>();
        final copy = original.copyWith(successCount: 7);
        expect(copy.successCount, 7);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with settleCount', () {
        const original = AsyncDebouncerState<String>();
        final copy = original.copyWith(settleCount: 10);
        expect(copy.settleCount, 10);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with isExecuting', () {
        const original = AsyncDebouncerState<String>();
        final copy = original.copyWith(isExecuting: true);
        expect(copy.isExecuting, true);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with lastResult', () {
        const original = AsyncDebouncerState<String>();
        final copy = original.copyWith(lastResult: 'new result');
        expect(copy.lastResult, 'new result');
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with multiple fields', () {
        const original = AsyncDebouncerState<String>();
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
        expect(copy.isPending, original.isPending);
      });
    });
  });

  group('DebouncerOptions', () {
    test('constructor with default values', () {
      const options = DebouncerOptions<String>(
        wait: Duration(milliseconds: 100),
      );

      expect(options.enabled, true);
      expect(options.key, null);
      expect(options.wait, const Duration(milliseconds: 100));
      expect(options.leading, false);
      expect(options.trailing, true);
      expect(options.onExecute, null);
    });

    test('constructor with custom values', () {
      void onExecute(String args) {}

      final options = DebouncerOptions<String>(
        enabled: false,
        key: 'debounce-key',
        wait: const Duration(seconds: 10),
        leading: true,
        trailing: false,
        onExecute: onExecute,
      );

      expect(options.enabled, false);
      expect(options.key, 'debounce-key');
      expect(options.wait, const Duration(seconds: 10));
      expect(options.leading, true);
      expect(options.trailing, false);
      expect(options.onExecute, isNotNull);
    });

    test('extends PacerOptions', () {
      const options = DebouncerOptions<int>(
        wait: Duration(milliseconds: 100),
      );
      expect(options, isA<PacerOptions>());
    });
  });

  group('DebouncerState', () {
    test('constructor with default values', () {
      const state = DebouncerState<String>();

      expect(state.executionCount, 0);
      expect(state.status, PacerStatus.idle);
      expect(state.maybeExecuteCount, 0);
      expect(state.lastArgs, null);
      expect(state.isPending, false);
    });

    test('constructor with custom values', () {
      final state = DebouncerState<String>(
        executionCount: 3,
        status: PacerStatus.executing,
        maybeExecuteCount: 8,
        lastArgs: 'test-args',
        isPending: true,
      );

      expect(state.executionCount, 3);
      expect(state.status, PacerStatus.executing);
      expect(state.maybeExecuteCount, 8);
      expect(state.lastArgs, 'test-args');
      expect(state.isPending, true);
    });

    test('extends PacerState', () {
      const state = DebouncerState<int>();
      expect(state, isA<PacerState>());
    });

    group('copyWith', () {
      test('copyWith with no arguments returns identical state', () {
        const original = DebouncerState<String>(
          executionCount: 2,
          status: PacerStatus.executing,
          maybeExecuteCount: 6,
          lastArgs: 'args',
          isPending: true,
        );

        final copy = original.copyWith();

        expect(copy.executionCount, original.executionCount);
        expect(copy.status, original.status);
        expect(copy.maybeExecuteCount, original.maybeExecuteCount);
        expect(copy.lastArgs, original.lastArgs);
        expect(copy.isPending, original.isPending);
      });

      test('copyWith with executionCount', () {
        const original = DebouncerState<String>();
        final copy = original.copyWith(executionCount: 7);
        expect(copy.executionCount, 7);
        expect(copy.status, original.status);
      });

      test('copyWith with status', () {
        const original = DebouncerState<String>();
        final copy = original.copyWith(status: PacerStatus.executing);
        expect(copy.status, PacerStatus.executing);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with maybeExecuteCount', () {
        const original = DebouncerState<String>();
        final copy = original.copyWith(maybeExecuteCount: 15);
        expect(copy.maybeExecuteCount, 15);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with lastArgs', () {
        const original = DebouncerState<String>();
        final copy = original.copyWith(lastArgs: 'new-args');
        expect(copy.lastArgs, 'new-args');
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with isPending', () {
        const original = DebouncerState<String>();
        final copy = original.copyWith(isPending: true);
        expect(copy.isPending, true);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with multiple fields', () {
        const original = DebouncerState<String>();
        final copy = original.copyWith(
          executionCount: 4,
          status: PacerStatus.executing,
          maybeExecuteCount: 12,
          isPending: true,
        );

        expect(copy.executionCount, 4);
        expect(copy.status, PacerStatus.executing);
        expect(copy.maybeExecuteCount, 12);
        expect(copy.isPending, true);
        // Other fields should remain unchanged
        expect(copy.lastArgs, original.lastArgs);
      });
    });
  });

  group('Type safety', () {
    test('AsyncDebouncerOptions supports different generic types', () {
      const stringOptions = AsyncDebouncerOptions<String>(
        wait: Duration(milliseconds: 100),
      );
      const intOptions = AsyncDebouncerOptions<int>(
        wait: Duration(milliseconds: 100),
      );
      const customOptions = AsyncDebouncerOptions<Map<String, dynamic>>(
        wait: Duration(milliseconds: 100),
      );

      expect(stringOptions, isA<AsyncDebouncerOptions<String>>());
      expect(intOptions, isA<AsyncDebouncerOptions<int>>());
      expect(customOptions, isA<AsyncDebouncerOptions<Map<String, dynamic>>>());
    });

    test('AsyncDebouncerState supports different generic types', () {
      const stringState = AsyncDebouncerState<String>();
      const intState = AsyncDebouncerState<int>();
      const customState = AsyncDebouncerState<Map<String, dynamic>>();

      expect(stringState, isA<AsyncDebouncerState<String>>());
      expect(intState, isA<AsyncDebouncerState<int>>());
      expect(customState, isA<AsyncDebouncerState<Map<String, dynamic>>>());
    });

    test('DebouncerOptions supports different generic types', () {
      const stringOptions = DebouncerOptions<String>(
        wait: Duration(milliseconds: 100),
      );
      const intOptions = DebouncerOptions<int>(
        wait: Duration(milliseconds: 100),
      );
      const customOptions = DebouncerOptions<Map<String, dynamic>>(
        wait: Duration(milliseconds: 100),
      );

      expect(stringOptions, isA<DebouncerOptions<String>>());
      expect(intOptions, isA<DebouncerOptions<int>>());
      expect(customOptions, isA<DebouncerOptions<Map<String, dynamic>>>());
    });

    test('DebouncerState supports different generic types', () {
      const stringState = DebouncerState<String>();
      const intState = DebouncerState<int>();
      const customState = DebouncerState<Map<String, dynamic>>();

      expect(stringState, isA<DebouncerState<String>>());
      expect(intState, isA<DebouncerState<int>>());
      expect(customState, isA<DebouncerState<Map<String, dynamic>>>());
    });
  });

  group('Immutability', () {
    test('AsyncDebouncerState copyWith creates new instance', () {
      const original = AsyncDebouncerState<String>(
        lastArgs: 'original',
        executionCount: 1,
      );

      final copy = original.copyWith(executionCount: 2);

      expect(original.executionCount, 1);
      expect(copy.executionCount, 2);
      expect(original.lastArgs, 'original');
      expect(copy.lastArgs, 'original'); // Should share the same reference
    });

    test('DebouncerState copyWith creates new instance', () {
      const original = DebouncerState<String>(
        lastArgs: 'original',
        executionCount: 1,
      );

      final copy = original.copyWith(executionCount: 2);

      expect(original.executionCount, 1);
      expect(copy.executionCount, 2);
      expect(original.lastArgs, 'original');
      expect(copy.lastArgs, 'original'); // Should share the same reference
    });
  });
}