import 'package:flutter_test/flutter_test.dart';
import 'package:gnrllybttr_pacer/src/queuer/models.dart';
import 'package:gnrllybttr_pacer/src/common/common.dart';

void main() {
  group('AsyncQueuerOptions', () {
    test('constructor with default values', () {
      const options = AsyncQueuerOptions<String>();

      expect(options.enabled, true);
      expect(options.key, null);
      expect(options.wait, null);
      expect(options.maxSize, null);
      expect(options.addItemsTo, QueuePosition.back);
      expect(options.getItemsFrom, QueuePosition.front);
      expect(options.getPriority, null);
      expect(options.expirationDuration, null);
      expect(options.onExecute, null);
      expect(options.onExpire, null);
      expect(options.onReject, null);
      expect(options.started, false);
      expect(options.concurrency, 1);
      expect(options.onSuccess, null);
      expect(options.onError, null);
      expect(options.onSettled, null);
      expect(options.throwOnError, false);
    });

    test('constructor with custom values', () {
      int getPriority(String item) => item.length;
      void onExecute(String item) {}
      void onExpire(String item) {}
      void onReject(String item) {}
      void onSuccess(dynamic result) {}
      void onError(dynamic error) {}
      void onSettled(dynamic result, dynamic error) {}

      final options = AsyncQueuerOptions<String>(
        enabled: false,
        key: 'test-key',
        wait: const Duration(seconds: 5),
        maxSize: 100,
        addItemsTo: QueuePosition.front,
        getItemsFrom: QueuePosition.back,
        getPriority: getPriority,
        expirationDuration: const Duration(minutes: 5),
        onExecute: onExecute,
        onExpire: onExpire,
        onReject: onReject,
        started: true,
        concurrency: 3,
        onSuccess: onSuccess,
        onError: onError,
        onSettled: onSettled,
        throwOnError: true,
      );

      expect(options.enabled, false);
      expect(options.key, 'test-key');
      expect(options.wait, const Duration(seconds: 5));
      expect(options.maxSize, 100);
      expect(options.addItemsTo, QueuePosition.front);
      expect(options.getItemsFrom, QueuePosition.back);
      expect(options.getPriority, isNotNull);
      expect(options.getPriority!('test'), 4);
      expect(options.expirationDuration, const Duration(minutes: 5));
      expect(options.onExecute, isNotNull);
      expect(options.onExpire, isNotNull);
      expect(options.onReject, isNotNull);
      expect(options.started, true);
      expect(options.concurrency, 3);
      expect(options.onSuccess, isNotNull);
      expect(options.onError, isNotNull);
      expect(options.onSettled, isNotNull);
      expect(options.throwOnError, true);
    });

    test('extends PacerOptions', () {
      const options = AsyncQueuerOptions<int>();
      expect(options, isA<PacerOptions>());
    });
  });

  group('AsyncQueuerState', () {
    test('constructor with default values', () {
      const state = AsyncQueuerState<String>();

      expect(state.executionCount, 0);
      expect(state.status, PacerStatus.idle);
      expect(state.addItemCount, 0);
      expect(state.expirationCount, 0);
      expect(state.rejectionCount, 0);
      expect(state.items, const <String>[]);
      expect(state.itemTimestamps, const <DateTime>[]);
      expect(state.isEmpty, true);
      expect(state.isFull, false);
      expect(state.isRunning, false);
      expect(state.size, 0);
      expect(state.activeItems, const <String>[]);
      expect(state.pendingItems, const <String>[]);
      expect(state.errorCount, 0);
      expect(state.successCount, 0);
      expect(state.settleCount, 0);
      expect(state.isExecuting, false);
      expect(state.lastResult, null);
    });

    test('constructor with custom values', () {
      final items = ['item1', 'item2'];
      final itemTimestamps = [DateTime.now(), DateTime.now().add(const Duration(seconds: 1))];
      final activeItems = ['active1'];
      final pendingItems = ['pending1', 'pending2'];

      final state = AsyncQueuerState<String>(
        executionCount: 5,
        status: PacerStatus.executing,
        addItemCount: 10,
        expirationCount: 2,
        rejectionCount: 1,
        items: items,
        itemTimestamps: itemTimestamps,
        isEmpty: false,
        isFull: true,
        isRunning: true,
        size: 2,
        activeItems: activeItems,
        pendingItems: pendingItems,
        errorCount: 1,
        successCount: 4,
        settleCount: 5,
        isExecuting: true,
        lastResult: 'success',
      );

      expect(state.executionCount, 5);
      expect(state.status, PacerStatus.executing);
      expect(state.addItemCount, 10);
      expect(state.expirationCount, 2);
      expect(state.rejectionCount, 1);
      expect(state.items, items);
      expect(state.itemTimestamps, itemTimestamps);
      expect(state.isEmpty, false);
      expect(state.isFull, true);
      expect(state.isRunning, true);
      expect(state.size, 2);
      expect(state.activeItems, activeItems);
      expect(state.pendingItems, pendingItems);
      expect(state.errorCount, 1);
      expect(state.successCount, 4);
      expect(state.settleCount, 5);
      expect(state.isExecuting, true);
      expect(state.lastResult, 'success');
    });

    test('extends PacerState', () {
      const state = AsyncQueuerState<int>();
      expect(state, isA<PacerState>());
    });

    group('copyWith', () {
      test('copyWith with no arguments returns identical state', () {
        const original = AsyncQueuerState<String>(
          executionCount: 1,
          status: PacerStatus.executing,
          addItemCount: 5,
          expirationCount: 1,
          rejectionCount: 0,
          items: ['item'],
          itemTimestamps: [],
          isEmpty: false,
          isFull: false,
          isRunning: true,
          size: 1,
          activeItems: ['active'],
          pendingItems: [],
          errorCount: 0,
          successCount: 1,
          settleCount: 1,
          isExecuting: true,
          lastResult: 'result',
        );

        final copy = original.copyWith();

        expect(copy.executionCount, original.executionCount);
        expect(copy.status, original.status);
        expect(copy.addItemCount, original.addItemCount);
        expect(copy.expirationCount, original.expirationCount);
        expect(copy.rejectionCount, original.rejectionCount);
        expect(copy.items, original.items);
        expect(copy.itemTimestamps, original.itemTimestamps);
        expect(copy.isEmpty, original.isEmpty);
        expect(copy.isFull, original.isFull);
        expect(copy.isRunning, original.isRunning);
        expect(copy.size, original.size);
        expect(copy.activeItems, original.activeItems);
        expect(copy.pendingItems, original.pendingItems);
        expect(copy.errorCount, original.errorCount);
        expect(copy.successCount, original.successCount);
        expect(copy.settleCount, original.settleCount);
        expect(copy.isExecuting, original.isExecuting);
        expect(copy.lastResult, original.lastResult);
      });

      test('copyWith with executionCount', () {
        const original = AsyncQueuerState<String>();
        final copy = original.copyWith(executionCount: 5);
        expect(copy.executionCount, 5);
        expect(copy.status, original.status);
      });

      test('copyWith with status', () {
        const original = AsyncQueuerState<String>();
        final copy = original.copyWith(status: PacerStatus.executing);
        expect(copy.status, PacerStatus.executing);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with addItemCount', () {
        const original = AsyncQueuerState<String>();
        final copy = original.copyWith(addItemCount: 10);
        expect(copy.addItemCount, 10);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with expirationCount', () {
        const original = AsyncQueuerState<String>();
        final copy = original.copyWith(expirationCount: 3);
        expect(copy.expirationCount, 3);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with rejectionCount', () {
        const original = AsyncQueuerState<String>();
        final copy = original.copyWith(rejectionCount: 2);
        expect(copy.rejectionCount, 2);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with items', () {
        const original = AsyncQueuerState<String>();
        final newItems = ['item1', 'item2'];
        final copy = original.copyWith(items: newItems);
        expect(copy.items, newItems);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with itemTimestamps', () {
        const original = AsyncQueuerState<String>();
        final newTimestamps = [DateTime.now()];
        final copy = original.copyWith(itemTimestamps: newTimestamps);
        expect(copy.itemTimestamps, newTimestamps);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with isEmpty', () {
        const original = AsyncQueuerState<String>();
        final copy = original.copyWith(isEmpty: false);
        expect(copy.isEmpty, false);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with isFull', () {
        const original = AsyncQueuerState<String>();
        final copy = original.copyWith(isFull: true);
        expect(copy.isFull, true);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with isRunning', () {
        const original = AsyncQueuerState<String>();
        final copy = original.copyWith(isRunning: true);
        expect(copy.isRunning, true);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with size', () {
        const original = AsyncQueuerState<String>();
        final copy = original.copyWith(size: 10);
        expect(copy.size, 10);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with activeItems', () {
        const original = AsyncQueuerState<String>();
        final newActiveItems = ['active1', 'active2'];
        final copy = original.copyWith(activeItems: newActiveItems);
        expect(copy.activeItems, newActiveItems);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with pendingItems', () {
        const original = AsyncQueuerState<String>();
        final newPendingItems = ['pending1'];
        final copy = original.copyWith(pendingItems: newPendingItems);
        expect(copy.pendingItems, newPendingItems);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with errorCount', () {
        const original = AsyncQueuerState<String>();
        final copy = original.copyWith(errorCount: 3);
        expect(copy.errorCount, 3);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with successCount', () {
        const original = AsyncQueuerState<String>();
        final copy = original.copyWith(successCount: 7);
        expect(copy.successCount, 7);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with settleCount', () {
        const original = AsyncQueuerState<String>();
        final copy = original.copyWith(settleCount: 10);
        expect(copy.settleCount, 10);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with isExecuting', () {
        const original = AsyncQueuerState<String>();
        final copy = original.copyWith(isExecuting: true);
        expect(copy.isExecuting, true);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with lastResult', () {
        const original = AsyncQueuerState<String>();
        final copy = original.copyWith(lastResult: 'new result');
        expect(copy.lastResult, 'new result');
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with multiple fields', () {
        const original = AsyncQueuerState<String>();
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

  group('QueuerOptions', () {
    test('constructor with default values', () {
      const options = QueuerOptions<String>();

      expect(options.enabled, true);
      expect(options.key, null);
      expect(options.wait, null);
      expect(options.maxSize, null);
      expect(options.addItemsTo, QueuePosition.back);
      expect(options.getItemsFrom, QueuePosition.front);
      expect(options.getPriority, null);
      expect(options.expirationDuration, null);
      expect(options.onExecute, null);
      expect(options.onExpire, null);
      expect(options.onReject, null);
      expect(options.started, false);
    });

    test('constructor with custom values', () {
      int getPriority(String item) => item.length;
      void onExecute(String item) {}
      void onExpire(String item) {}
      void onReject(String item) {}

      final options = QueuerOptions<String>(
        enabled: false,
        key: 'queue-key',
        wait: const Duration(seconds: 10),
        maxSize: 50,
        addItemsTo: QueuePosition.front,
        getItemsFrom: QueuePosition.back,
        getPriority: getPriority,
        expirationDuration: const Duration(minutes: 10),
        onExecute: onExecute,
        onExpire: onExpire,
        onReject: onReject,
        started: true,
      );

      expect(options.enabled, false);
      expect(options.key, 'queue-key');
      expect(options.wait, const Duration(seconds: 10));
      expect(options.maxSize, 50);
      expect(options.addItemsTo, QueuePosition.front);
      expect(options.getItemsFrom, QueuePosition.back);
      expect(options.getPriority, isNotNull);
      expect(options.getPriority!('test'), 4);
      expect(options.expirationDuration, const Duration(minutes: 10));
      expect(options.onExecute, isNotNull);
      expect(options.onExpire, isNotNull);
      expect(options.onReject, isNotNull);
      expect(options.started, true);
    });

    test('extends PacerOptions', () {
      const options = QueuerOptions<int>();
      expect(options, isA<PacerOptions>());
    });
  });

  group('QueuerState', () {
    test('constructor with default values', () {
      const state = QueuerState<String>();

      expect(state.executionCount, 0);
      expect(state.status, PacerStatus.idle);
      expect(state.addItemCount, 0);
      expect(state.expirationCount, 0);
      expect(state.rejectionCount, 0);
      expect(state.items, const <String>[]);
      expect(state.itemTimestamps, const <DateTime>[]);
      expect(state.isEmpty, true);
      expect(state.isFull, false);
      expect(state.isRunning, false);
      expect(state.size, 0);
    });

    test('constructor with custom values', () {
      final items = ['item1', 'item2', 'item3'];
      final itemTimestamps = [
        DateTime.now(),
        DateTime.now().add(const Duration(seconds: 1)),
        DateTime.now().add(const Duration(seconds: 2))
      ];

      final state = QueuerState<String>(
        executionCount: 3,
        status: PacerStatus.executing,
        addItemCount: 8,
        expirationCount: 1,
        rejectionCount: 2,
        items: items,
        itemTimestamps: itemTimestamps,
        isEmpty: false,
        isFull: false,
        isRunning: true,
        size: 3,
      );

      expect(state.executionCount, 3);
      expect(state.status, PacerStatus.executing);
      expect(state.addItemCount, 8);
      expect(state.expirationCount, 1);
      expect(state.rejectionCount, 2);
      expect(state.items, items);
      expect(state.itemTimestamps, itemTimestamps);
      expect(state.isEmpty, false);
      expect(state.isFull, false);
      expect(state.isRunning, true);
      expect(state.size, 3);
    });

    test('extends PacerState', () {
      const state = QueuerState<int>();
      expect(state, isA<PacerState>());
    });

    group('copyWith', () {
      test('copyWith with no arguments returns identical state', () {
        const original = QueuerState<String>(
          executionCount: 2,
          status: PacerStatus.executing,
          addItemCount: 6,
          expirationCount: 1,
          rejectionCount: 0,
          items: ['item1', 'item2'],
          itemTimestamps: [],
          isEmpty: false,
          isFull: false,
          isRunning: true,
          size: 2,
        );

        final copy = original.copyWith();

        expect(copy.executionCount, original.executionCount);
        expect(copy.status, original.status);
        expect(copy.addItemCount, original.addItemCount);
        expect(copy.expirationCount, original.expirationCount);
        expect(copy.rejectionCount, original.rejectionCount);
        expect(copy.items, original.items);
        expect(copy.itemTimestamps, original.itemTimestamps);
        expect(copy.isEmpty, original.isEmpty);
        expect(copy.isFull, original.isFull);
        expect(copy.isRunning, original.isRunning);
        expect(copy.size, original.size);
      });

      test('copyWith with executionCount', () {
        const original = QueuerState<String>();
        final copy = original.copyWith(executionCount: 7);
        expect(copy.executionCount, 7);
        expect(copy.status, original.status);
      });

      test('copyWith with status', () {
        const original = QueuerState<String>();
        final copy = original.copyWith(status: PacerStatus.executing);
        expect(copy.status, PacerStatus.executing);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with addItemCount', () {
        const original = QueuerState<String>();
        final copy = original.copyWith(addItemCount: 15);
        expect(copy.addItemCount, 15);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with expirationCount', () {
        const original = QueuerState<String>();
        final copy = original.copyWith(expirationCount: 5);
        expect(copy.expirationCount, 5);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with rejectionCount', () {
        const original = QueuerState<String>();
        final copy = original.copyWith(rejectionCount: 3);
        expect(copy.rejectionCount, 3);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with items', () {
        const original = QueuerState<String>();
        final newItems = ['new1', 'new2', 'new3'];
        final copy = original.copyWith(items: newItems);
        expect(copy.items, newItems);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with itemTimestamps', () {
        const original = QueuerState<String>();
        final newTimestamps = [DateTime.now(), DateTime.now().add(const Duration(hours: 1))];
        final copy = original.copyWith(itemTimestamps: newTimestamps);
        expect(copy.itemTimestamps, newTimestamps);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with isEmpty', () {
        const original = QueuerState<String>();
        final copy = original.copyWith(isEmpty: false);
        expect(copy.isEmpty, false);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with isFull', () {
        const original = QueuerState<String>();
        final copy = original.copyWith(isFull: true);
        expect(copy.isFull, true);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with isRunning', () {
        const original = QueuerState<String>();
        final copy = original.copyWith(isRunning: true);
        expect(copy.isRunning, true);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with size', () {
        const original = QueuerState<String>();
        final copy = original.copyWith(size: 25);
        expect(copy.size, 25);
        expect(copy.executionCount, original.executionCount);
      });

      test('copyWith with multiple fields', () {
        const original = QueuerState<String>();
        final copy = original.copyWith(
          executionCount: 4,
          status: PacerStatus.executing,
          size: 12,
          isRunning: true,
        );

        expect(copy.executionCount, 4);
        expect(copy.status, PacerStatus.executing);
        expect(copy.size, 12);
        expect(copy.isRunning, true);
        // Other fields should remain unchanged
        expect(copy.items, original.items);
        expect(copy.isEmpty, original.isEmpty);
      });
    });
  });

  group('Type safety', () {
    test('AsyncQueuerOptions supports different generic types', () {
      const stringOptions = AsyncQueuerOptions<String>();
      const intOptions = AsyncQueuerOptions<int>();
      const customOptions = AsyncQueuerOptions<Map<String, dynamic>>();

      expect(stringOptions, isA<AsyncQueuerOptions<String>>());
      expect(intOptions, isA<AsyncQueuerOptions<int>>());
      expect(customOptions, isA<AsyncQueuerOptions<Map<String, dynamic>>>());
    });

    test('AsyncQueuerState supports different generic types', () {
      const stringState = AsyncQueuerState<String>();
      const intState = AsyncQueuerState<int>();
      const customState = AsyncQueuerState<Map<String, dynamic>>();

      expect(stringState, isA<AsyncQueuerState<String>>());
      expect(intState, isA<AsyncQueuerState<int>>());
      expect(customState, isA<AsyncQueuerState<Map<String, dynamic>>>());
    });

    test('QueuerOptions supports different generic types', () {
      const stringOptions = QueuerOptions<String>();
      const intOptions = QueuerOptions<int>();
      const customOptions = QueuerOptions<Map<String, dynamic>>();

      expect(stringOptions, isA<QueuerOptions<String>>());
      expect(intOptions, isA<QueuerOptions<int>>());
      expect(customOptions, isA<QueuerOptions<Map<String, dynamic>>>());
    });

    test('QueuerState supports different generic types', () {
      const stringState = QueuerState<String>();
      const intState = QueuerState<int>();
      const customState = QueuerState<Map<String, dynamic>>();

      expect(stringState, isA<QueuerState<String>>());
      expect(intState, isA<QueuerState<int>>());
      expect(customState, isA<QueuerState<Map<String, dynamic>>>());
    });
  });

  group('Immutability', () {
    test('AsyncQueuerState copyWith creates new instance', () {
      const original = AsyncQueuerState<String>(
        items: ['original'],
        executionCount: 1,
      );

      final copy = original.copyWith(executionCount: 2);

      expect(original.executionCount, 1);
      expect(copy.executionCount, 2);
      expect(original.items, ['original']);
      expect(copy.items, ['original']); // Should share the same list reference
    });

    test('QueuerState copyWith creates new instance', () {
      const original = QueuerState<String>(
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