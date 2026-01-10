import 'package:flutter_test/flutter_test.dart';
import 'package:gnrllybttr_pacer/src/batcher/models.dart';
import 'package:gnrllybttr_pacer/src/common/common.dart';

void main() {
  group('AsyncBatcherOptions', () {
    test('constructor with default values', () {
      const options = AsyncBatcherOptions<String>();

      expect(options.enabled, true);
      expect(options.key, null);
      expect(options.maxSize, null);
      expect(options.wait, null);
      expect(options.getShouldExecute, null);
      expect(options.onExecute, null);
      expect(options.onItemsChange, null);
      expect(options.started, false);
      expect(options.onSuccess, null);
      expect(options.onError, null);
      expect(options.onSettled, null);
      expect(options.throwOnError, false);
    });

    test('constructor with custom values', () {
      bool shouldExecute(List<String> items) => items.length >= 2;
      void onExecute(List<String> items) {}
      void onItemsChange(List<String> items) {}
      void onSuccess(dynamic result) {}
      void onError(dynamic error) {}
      void onSettled(dynamic result, dynamic error) {}

      final options = AsyncBatcherOptions<String>(
        enabled: false,
        key: 'test-key',
        maxSize: 10,
        wait: const Duration(seconds: 5),
        getShouldExecute: shouldExecute,
        onExecute: onExecute,
        onItemsChange: onItemsChange,
        started: true,
        onSuccess: onSuccess,
        onError: onError,
        onSettled: onSettled,
        throwOnError: true,
      );

      expect(options.enabled, false);
      expect(options.key, 'test-key');
      expect(options.maxSize, 10);
      expect(options.wait, const Duration(seconds: 5));
      expect(options.getShouldExecute, isNotNull);
      expect(options.getShouldExecute!(['a']), false); // length < 2
      expect(options.getShouldExecute!(['a', 'b']), true); // length >= 2
      expect(options.onExecute, isNotNull);
      expect(options.onItemsChange, isNotNull);
      expect(options.started, true);
      expect(options.onSuccess, isNotNull);
      expect(options.onError, isNotNull);
      expect(options.onSettled, isNotNull);
      expect(options.throwOnError, true);
    });

    test('extends PacerOptions', () {
      const options = AsyncBatcherOptions<int>();
      expect(options, isA<PacerOptions>());
    });
  });

  group('AsyncBatcherState', () {
    test('constructor with default values', () {
      const state = AsyncBatcherState<String>();

      expect(state.executionCount, 0);
      expect(state.status, PacerStatus.idle);
      expect(state.items, const <String>[]);
      expect(state.isEmpty, true);
      expect(state.isPending, false);
      expect(state.size, 0);
      expect(state.totalItemsProcessed, 0);
      expect(state.failedItems, const <String>[]);
      expect(state.errorCount, 0);
      expect(state.successCount, 0);
      expect(state.settleCount, 0);
      expect(state.isExecuting, false);
      expect(state.lastResult, null);
    });

    test('constructor with custom values', () {
      final items = ['item1', 'item2'];
      final failedItems = ['failed1'];

      final state = AsyncBatcherState<String>(
        executionCount: 5,
        status: PacerStatus.executing,
        items: items,
        isEmpty: false,
        isPending: true,
        size: 2,
        totalItemsProcessed: 10,
        failedItems: failedItems,
        errorCount: 1,
        successCount: 4,
        settleCount: 5,
        isExecuting: true,
        lastResult: 'success',
      );

      expect(state.executionCount, 5);
      expect(state.status, PacerStatus.executing);
      expect(state.items, items);
      expect(state.isEmpty, false);
      expect(state.isPending, true);
      expect(state.size, 2);
      expect(state.totalItemsProcessed, 10);
      expect(state.failedItems, failedItems);
      expect(state.errorCount, 1);
      expect(state.successCount, 4);
      expect(state.settleCount, 5);
      expect(state.isExecuting, true);
      expect(state.lastResult, 'success');
    });

    test('extends PacerState', () {
      const state = AsyncBatcherState<int>();
      expect(state, isA<PacerState>());
    });

    group('copyWith', () {
      test('copyWith with no arguments returns identical state', () {
        const original = AsyncBatcherState<String>(
          executionCount: 1,
          status: PacerStatus.executing,
          items: ['test'],
          isEmpty: false,
          isPending: true,
          size: 1,
          totalItemsProcessed: 5,
          failedItems: ['failed'],
          errorCount: 1,
          settleCount: 1,
          isExecuting: true,
          lastResult: 'result',
        );

        final copy = original.copyWith();

        expect(copy.executionCount, original.executionCount);
        expect(copy.status, original.status);
        expect(copy.items, original.items);
        expect(copy.isEmpty, original.isEmpty);
        expect(copy.isPending, original.isPending);
        expect(copy.size, original.size);
        expect(copy.totalItemsProcessed, original.totalItemsProcessed);
        expect(copy.failedItems, original.failedItems);
        expect(copy.errorCount, original.errorCount);
        expect(copy.successCount, original.successCount);
        expect(copy.settleCount, original.settleCount);
        expect(copy.isExecuting, original.isExecuting);
        expect(copy.lastResult, original.lastResult);
      });

      test('copyWith with executionCount', () {
        const original = AsyncBatcherState<String>();
        final copy = original.copyWith(executionCount: 5);
        expect(copy.executionCount, 5);
        expect(copy.status, original.status);
      });

      test('copyWith with status', () {
        const original = AsyncBatcherState<String>();
        final copy = original.copyWith(status: PacerStatus.executing);
        expect(copy.status, PacerStatus.executing);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with items', () {
        const original = AsyncBatcherState<String>();
        final newItems = ['item1', 'item2'];
        final copy = original.copyWith(items: newItems);
        expect(copy.items, newItems);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with isEmpty', () {
        const original = AsyncBatcherState<String>();
        final copy = original.copyWith(isEmpty: false);
        expect(copy.isEmpty, false);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with isPending', () {
        const original = AsyncBatcherState<String>();
        final copy = original.copyWith(isPending: true);
        expect(copy.isPending, true);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with size', () {
        const original = AsyncBatcherState<String>();
        final copy = original.copyWith(size: 10);
        expect(copy.size, 10);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with totalItemsProcessed', () {
        const original = AsyncBatcherState<String>();
        final copy = original.copyWith(totalItemsProcessed: 100);
        expect(copy.totalItemsProcessed, 100);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with failedItems', () {
        const original = AsyncBatcherState<String>();
        final newFailedItems = ['failed1', 'failed2'];
        final copy = original.copyWith(failedItems: newFailedItems);
        expect(copy.failedItems, newFailedItems);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with errorCount', () {
        const original = AsyncBatcherState<String>();
        final copy = original.copyWith(errorCount: 3);
        expect(copy.errorCount, 3);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with successCount', () {
        const original = AsyncBatcherState<String>();
        final copy = original.copyWith(successCount: 7);
        expect(copy.successCount, 7);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with settleCount', () {
        const original = AsyncBatcherState<String>();
        final copy = original.copyWith(settleCount: 10);
        expect(copy.settleCount, 10);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with isExecuting', () {
        const original = AsyncBatcherState<String>();
        final copy = original.copyWith(isExecuting: true);
        expect(copy.isExecuting, true);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with lastResult', () {
        const original = AsyncBatcherState<String>();
        final copy = original.copyWith(lastResult: 'new result');
        expect(copy.lastResult, 'new result');
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with multiple fields', () {
        const original = AsyncBatcherState<String>();
        final copy = original.copyWith(
          executionCount: 2,
          status: PacerStatus.executing,
          size: 5,
          isExecuting: true,
        );

        expect(copy.executionCount, 2);
        expect(copy.status, PacerStatus.executing);
        expect(copy.size, 5);
        expect(copy.isExecuting, true);
        // Other fields should remain unchanged
        expect(copy.items, original.items);
        expect(copy.isEmpty, original.isEmpty);
      });
    });
  });

  group('BatcherOptions', () {
    test('constructor with default values', () {
      const options = BatcherOptions<String>();

      expect(options.enabled, true);
      expect(options.key, null);
      expect(options.maxSize, null);
      expect(options.wait, null);
      expect(options.getShouldExecute, null);
      expect(options.onExecute, null);
      expect(options.onItemsChange, null);
      expect(options.started, false);
    });

    test('constructor with custom values', () {
      bool shouldExecute(List<String> items) => items.length >= 3;
      void onExecute(List<String> items) {}
      void onItemsChange(List<String> items) {}

      final options = BatcherOptions<String>(
        enabled: false,
        key: 'batch-key',
        maxSize: 20,
        wait: const Duration(seconds: 10),
        getShouldExecute: shouldExecute,
        onExecute: onExecute,
        onItemsChange: onItemsChange,
        started: true,
      );

      expect(options.enabled, false);
      expect(options.key, 'batch-key');
      expect(options.maxSize, 20);
      expect(options.wait, const Duration(seconds: 10));
      expect(options.getShouldExecute, isNotNull);
      expect(options.getShouldExecute!(['a', 'b']), false); // length < 3
      expect(options.getShouldExecute!(['a', 'b', 'c']), true); // length >= 3
      expect(options.onExecute, isNotNull);
      expect(options.onItemsChange, isNotNull);
      expect(options.started, true);
    });

    test('extends PacerOptions', () {
      const options = BatcherOptions<int>();
      expect(options, isA<PacerOptions>());
    });
  });

  group('BatcherState', () {
    test('constructor with default values', () {
      const state = BatcherState<String>();

      expect(state.executionCount, 0);
      expect(state.status, PacerStatus.idle);
      expect(state.items, const <String>[]);
      expect(state.isEmpty, true);
      expect(state.isPending, false);
      expect(state.size, 0);
      expect(state.totalItemsProcessed, 0);
    });

    test('constructor with custom values', () {
      final items = ['item1', 'item2', 'item3'];

      final state = BatcherState<String>(
        executionCount: 3,
        status: PacerStatus.executing,
        items: items,
        isEmpty: false,
        isPending: true,
        size: 3,
        totalItemsProcessed: 15,
      );

      expect(state.executionCount, 3);
      expect(state.status, PacerStatus.executing);
      expect(state.items, items);
      expect(state.isEmpty, false);
      expect(state.isPending, true);
      expect(state.size, 3);
      expect(state.totalItemsProcessed, 15);
    });

    test('extends PacerState', () {
      const state = BatcherState<int>();
      expect(state, isA<PacerState>());
    });

    group('copyWith', () {
      test('copyWith with no arguments returns identical state', () {
        const original = BatcherState<String>(
          executionCount: 2,
          status: PacerStatus.executing,
          items: ['test1', 'test2'],
          isEmpty: false,
          isPending: true,
          size: 2,
          totalItemsProcessed: 8,
        );

        final copy = original.copyWith();

        expect(copy.executionCount, original.executionCount);
        expect(copy.status, original.status);
        expect(copy.items, original.items);
        expect(copy.isEmpty, original.isEmpty);
        expect(copy.isPending, original.isPending);
        expect(copy.size, original.size);
        expect(copy.totalItemsProcessed, original.totalItemsProcessed);
      });

      test('copyWith with executionCount', () {
        const original = BatcherState<String>();
        final copy = original.copyWith(executionCount: 7);
        expect(copy.executionCount, 7);
        expect(copy.status, original.status);
      });

      test('copyWith with status', () {
        const original = BatcherState<String>();
        final copy = original.copyWith(status: PacerStatus.executing);
        expect(copy.status, PacerStatus.executing);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with items', () {
        const original = BatcherState<String>();
        final newItems = ['new1', 'new2', 'new3'];
        final copy = original.copyWith(items: newItems);
        expect(copy.items, newItems);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with isEmpty', () {
        const original = BatcherState<String>();
        final copy = original.copyWith(isEmpty: false);
        expect(copy.isEmpty, false);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with isPending', () {
        const original = BatcherState<String>();
        final copy = original.copyWith(isPending: true);
        expect(copy.isPending, true);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with size', () {
        const original = BatcherState<String>();
        final copy = original.copyWith(size: 25);
        expect(copy.size, 25);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with totalItemsProcessed', () {
        const original = BatcherState<String>();
        final copy = original.copyWith(totalItemsProcessed: 200);
        expect(copy.totalItemsProcessed, 200);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with multiple fields', () {
        const original = BatcherState<String>();
        final copy = original.copyWith(
          executionCount: 4,
          status: PacerStatus.executing,
          size: 12,
          isPending: true,
        );

        expect(copy.executionCount, 4);
        expect(copy.status, PacerStatus.executing);
        expect(copy.size, 12);
        expect(copy.isPending, true);
        // Other fields should remain unchanged
        expect(copy.items, original.items);
        expect(copy.isEmpty, original.isEmpty);
      });
    });
  });

  group('Type safety', () {
    test('AsyncBatcherOptions supports different generic types', () {
      const stringOptions = AsyncBatcherOptions<String>();
      const intOptions = AsyncBatcherOptions<int>();
      const customOptions = AsyncBatcherOptions<Map<String, dynamic>>();

      expect(stringOptions, isA<AsyncBatcherOptions<String>>());
      expect(intOptions, isA<AsyncBatcherOptions<int>>());
      expect(customOptions, isA<AsyncBatcherOptions<Map<String, dynamic>>>());
    });

    test('AsyncBatcherState supports different generic types', () {
      const stringState = AsyncBatcherState<String>();
      const intState = AsyncBatcherState<int>();
      const customState = AsyncBatcherState<Map<String, dynamic>>();

      expect(stringState, isA<AsyncBatcherState<String>>());
      expect(intState, isA<AsyncBatcherState<int>>());
      expect(customState, isA<AsyncBatcherState<Map<String, dynamic>>>());
    });

    test('BatcherOptions supports different generic types', () {
      const stringOptions = BatcherOptions<String>();
      const intOptions = BatcherOptions<int>();
      const customOptions = BatcherOptions<Map<String, dynamic>>();

      expect(stringOptions, isA<BatcherOptions<String>>());
      expect(intOptions, isA<BatcherOptions<int>>());
      expect(customOptions, isA<BatcherOptions<Map<String, dynamic>>>());
    });

    test('BatcherState supports different generic types', () {
      const stringState = BatcherState<String>();
      const intState = BatcherState<int>();
      const customState = BatcherState<Map<String, dynamic>>();

      expect(stringState, isA<BatcherState<String>>());
      expect(intState, isA<BatcherState<int>>());
      expect(customState, isA<BatcherState<Map<String, dynamic>>>());
    });
  });

  group('Immutability', () {
    test('AsyncBatcherState copyWith creates new instance', () {
      const original = AsyncBatcherState<String>(
        items: ['original'],
        executionCount: 1,
      );

      final copy = original.copyWith(executionCount: 2);

      expect(original.executionCount, 1);
      expect(copy.executionCount, 2);
      expect(original.items, ['original']);
      expect(copy.items, ['original']); // Should share the same list reference
    });

    test('BatcherState copyWith creates new instance', () {
      const original = BatcherState<String>(
        items: ['original'],
        executionCount: 1,
      );

      final copy = original.copyWith(executionCount: 2);

      expect(original.executionCount, 1);
      expect(copy.executionCount, 2);
      expect(original.items, ['original']);
      expect(copy.items, ['original']); // Should share the same list reference
    });
  });
}
