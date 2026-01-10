import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gnrllybttr_pacer/src/queuer/async_queuer.dart';
import 'package:gnrllybttr_pacer/src/queuer/models.dart';
import 'package:gnrllybttr_pacer/src/common/common.dart';

void main() {
  group('AsyncQueuer', () {
    late AsyncQueuer<String> queuer;
    late List<String> executedItems;

    setUp(() {
      executedItems = [];
    });

    tearDown(() {
      queuer.stop();
    });

    test('constructor with enabled options', () {
      queuer = AsyncQueuer<String>(
        (item) async {
          executedItems.add(item);
          return 'processed_$item';
        },
        const AsyncQueuerOptions<String>(
          maxSize: 3,
          wait: Duration(milliseconds: 100),
        ),
      );

      expect(queuer.options.enabled, true);
      expect(queuer.state.status, PacerStatus.idle);
      expect(queuer.state.isEmpty, true);
      expect(queuer.state.size, 0);
    });

    test('constructor with disabled options', () {
      queuer = AsyncQueuer<String>(
        (item) async {
          executedItems.add(item);
          return 'processed_$item';
        },
        const AsyncQueuerOptions<String>(
          enabled: false,
          maxSize: 3,
        ),
      );

      expect(queuer.options.enabled, false);
      expect(queuer.state.status, PacerStatus.disabled);
    });

    test('disabled queuer rejects addItem calls', () async {
      queuer = AsyncQueuer<String>(
        (item) async {
          executedItems.add(item);
          return 'processed_$item';
        },
        const AsyncQueuerOptions<String>(
          enabled: false,
          maxSize: 2,
        ),
      );

      expect(() => queuer.addItem('test'), throwsException);
      expect(queuer.state.size, 0);
      expect(executedItems, isEmpty);
    });

    test('addItem adds to queue and returns future', () async {
      queuer = AsyncQueuer<String>(
        (item) async {
          executedItems.add(item);
          await Future.delayed(const Duration(milliseconds: 10));
          return 'processed_$item';
        },
        const AsyncQueuerOptions<String>(
          maxSize: 10,
          started: true,
        ),
      );

      final future = queuer.addItem('first');
      expect(queuer.state.size, 1);

      final result = await future;
      expect(result, 'processed_first');
      expect(executedItems, ['first']);
      expect(queuer.state.size, 0);
    });

    test('addItem rejects when queue is full', () async {
      queuer = AsyncQueuer<String>(
        (item) async {
          executedItems.add(item);
          return 'processed_$item';
        },
        const AsyncQueuerOptions<String>(
          maxSize: 2,
          started: true,
        ),
      );

      await queuer.addItem('first');
      await queuer.addItem('second');

      expect(() => queuer.addItem('third'), throwsException);
      expect(queuer.state.rejectionCount, 1);
    });

    test('getNextItem returns null when empty', () {
      queuer = AsyncQueuer<String>(
        (item) async {
          executedItems.add(item);
          return 'processed_$item';
        },
        const AsyncQueuerOptions<String>(),
      );

      final item = queuer.getNextItem();
      expect(item, null);
    });

    test('getNextItem returns and removes items from queue', () {
      queuer = AsyncQueuer<String>(
        (item) async {
          executedItems.add(item);
          return 'processed_$item';
        },
        const AsyncQueuerOptions<String>(),
      );

      queuer.addItem('first');
      queuer.addItem('second');

      final item1 = queuer.getNextItem();
      expect(item1, 'first');
      expect(queuer.state.size, 1);

      final item2 = queuer.getNextItem();
      expect(item2, 'second');
      expect(queuer.state.size, 0);
    });

    test('start begins processing queued items', () async {
      queuer = AsyncQueuer<String>(
        (item) async {
          executedItems.add(item);
          await Future.delayed(const Duration(milliseconds: 10));
          return 'processed_$item';
        },
        const AsyncQueuerOptions<String>(
          wait: Duration(milliseconds: 50),
        ),
      );

      final future1 = queuer.addItem('first');
      final future2 = queuer.addItem('second');
      expect(queuer.state.isRunning, false);

      queuer.start();
      expect(queuer.state.isRunning, true);
      expect(queuer.state.status, PacerStatus.running);

      await Future.wait([future1, future2]);
      expect(executedItems, ['first', 'second']);
    });

    test('stop halts processing', () async {
      queuer = AsyncQueuer<String>(
        (item) async {
          executedItems.add(item);
          return 'processed_$item';
        },
        const AsyncQueuerOptions<String>(
          wait: Duration(milliseconds: 50),
          started: true,
        ),
      );

      queuer.addItem('first');
      queuer.addItem('second');
      expect(queuer.state.isRunning, true);

      queuer.stop();
      expect(queuer.state.isRunning, false);
      expect(queuer.state.status, PacerStatus.idle);

      await Future.delayed(const Duration(milliseconds: 60));
      expect(executedItems, isEmpty); // No processing occurred
      expect(queuer.state.size, 2); // Items still in queue
    });

    test('concurrency limits parallel processing', () async {
      int activeCount = 0;
      int maxActive = 0;

      queuer = AsyncQueuer<String>(
        (item) async {
          activeCount++;
          maxActive = maxActive > activeCount ? maxActive : activeCount;
          await Future.delayed(const Duration(milliseconds: 50));
          activeCount--;
          executedItems.add(item);
          return 'processed_$item';
        },
        const AsyncQueuerOptions<String>(
          concurrency: 2,
          started: true,
        ),
      );

      final futures = <Future>[];
      for (int i = 0; i < 5; i++) {
        futures.add(queuer.addItem('item$i'));
      }

      await Future.wait(futures);
      expect(maxActive, 2); // Should not exceed concurrency limit
      expect(executedItems.length, 5);
    });

    test('clear removes all items', () async {
      queuer = AsyncQueuer<String>(
        (item) async {
          executedItems.add(item);
          return 'processed_$item';
        },
        const AsyncQueuerOptions<String>(),
      );

      queuer.addItem('first');
      queuer.addItem('second');
      expect(queuer.state.size, 2);

      queuer.clear();
      expect(queuer.state.size, 0);
      expect(queuer.state.isEmpty, true);
      expect(queuer.state.items, isEmpty);
      expect(queuer.state.pendingItems, isEmpty);
      expect(queuer.state.activeItems, isEmpty);
    });

    test('reset clears items and resets counters', () async {
      queuer = AsyncQueuer<String>(
        (item) async {
          executedItems.add(item);
          return 'processed_$item';
        },
        const AsyncQueuerOptions<String>(),
      );

      await queuer.addItem('first');
      await queuer.addItem('second');
      expect(queuer.state.addItemCount, 2);

      queuer.reset();
      expect(queuer.state.size, 0);
      expect(queuer.state.addItemCount, 0);
      expect(queuer.state.executionCount, 0);
    });

    test('flush processes all items immediately', () async {
      queuer = AsyncQueuer<String>(
        (item) async {
          executedItems.add(item);
          await Future.delayed(const Duration(milliseconds: 10));
          return 'processed_$item';
        },
        const AsyncQueuerOptions<String>(
          wait: Duration(seconds: 1), // Long wait
        ),
      );

      final futures = <Future>[];
      futures.add(queuer.addItem('first'));
      futures.add(queuer.addItem('second'));
      expect(queuer.state.size, 2);

      queuer.flush();
      await Future.wait(futures);
      expect(executedItems, ['first', 'second']);
    });

    test('peekAllItems returns current items without removing them', () {
      queuer = AsyncQueuer<String>(
        (item) async {
          executedItems.add(item);
          return 'processed_$item';
        },
        const AsyncQueuerOptions<String>(),
      );

      queuer.addItem('first');
      queuer.addItem('second');

      final items = queuer.peekAllItems();
      expect(items, ['first', 'second']);
      expect(queuer.state.size, 2); // Items still in queue
    });

    test('setOptions with disabled option', () {
      queuer = AsyncQueuer<String>(
        (item) async {
          executedItems.add(item);
          return 'processed_$item';
        },
        const AsyncQueuerOptions<String>(
          maxSize: 5,
          wait: Duration(milliseconds: 100),
          started: true,
        ),
      );

      queuer.addItem('test');
      expect(queuer.state.status, PacerStatus.running);

      queuer.setOptions(
        const AsyncQueuerOptions<String>(
          enabled: false,
          maxSize: 5,
        ),
      );

      expect(queuer.options.enabled, false);
      expect(queuer.state.status, PacerStatus.disabled);
      expect(queuer.state.isRunning, false);
    });

    test('setOptions with enabled option', () {
      queuer = AsyncQueuer<String>(
        (item) async {
          executedItems.add(item);
          return 'processed_$item';
        },
        const AsyncQueuerOptions<String>(
          enabled: false,
          maxSize: 5,
        ),
      );

      expect(queuer.state.status, PacerStatus.disabled);

      queuer.setOptions(
        const AsyncQueuerOptions<String>(
          maxSize: 5,
        ),
      );

      expect(queuer.options.enabled, true);
      expect(queuer.state.status, PacerStatus.idle);
    });

    test('error handling with throwOnError false', () async {
      queuer = AsyncQueuer<String>(
        (item) async {
          if (item == 'error') {
            throw Exception('Test error');
          }
          executedItems.add(item);
          return 'processed_$item';
        },
        const AsyncQueuerOptions<String>(
          started: true,
        ),
      );

      final result = await queuer.addItem('error');
      expect(result, null);
      expect(queuer.state.errorCount, 1);
      expect(executedItems, isEmpty);
    });

    test('error handling with throwOnError true', () async {
      queuer = AsyncQueuer<String>(
        (item) async {
          if (item == 'error') {
            throw Exception('Test error');
          }
          executedItems.add(item);
          return 'processed_$item';
        },
        const AsyncQueuerOptions<String>(
          throwOnError: true,
          started: true,
        ),
      );

      expect(() async => queuer.addItem('error'), throwsException);
      // Wait for the error to be processed
      await Future.delayed(const Duration(milliseconds: 10));
      expect(queuer.state.errorCount, 1);
    });

    test('LIFO ordering with getItemsFrom back', () async {
      queuer = AsyncQueuer<String>(
        (item) async {
          executedItems.add(item);
          return 'processed_$item';
        },
        const AsyncQueuerOptions<String>(
          getItemsFrom: QueuePosition.back, // Get from back = LIFO
        ),
      );

      await queuer.addItem('first');
      await queuer.addItem('second');
      await queuer.addItem('third');

      // Now start processing
      queuer.start();
      await Future.delayed(
        const Duration(milliseconds: 50),
      ); // Wait for processing

      expect(executedItems, ['third', 'second', 'first']);
    });

    test('item expiration', () async {
      int expiredCount = 0;
      queuer = AsyncQueuer<String>(
        (item) async {
          executedItems.add(item);
          return 'processed_$item';
        },
        AsyncQueuerOptions<String>(
          expirationDuration: const Duration(milliseconds: 50),
          onExpire: (item) => expiredCount++,
        ),
      );

      queuer.addItem('first');
      expect(queuer.state.size, 1);

      await Future.delayed(const Duration(milliseconds: 60));

      queuer.getNextItem(); // Should trigger expiration check
      expect(expiredCount, 1);
      expect(queuer.state.expirationCount, 1);
    });
  });
}
