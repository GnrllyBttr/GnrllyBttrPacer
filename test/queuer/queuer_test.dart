import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gnrllybttr_pacer/src/queuer/queuer.dart';
import 'package:gnrllybttr_pacer/src/queuer/models.dart';
import 'package:gnrllybttr_pacer/src/common/common.dart';

void main() {
  group('Queuer', () {
    late Queuer<String> queuer;
    late List<String> executedItems;

    setUp(() {
      executedItems = [];
    });

    tearDown(() {
      queuer.stop();
    });

    test('constructor with enabled options', () {
      queuer = Queuer<String>(
        (item) {
          executedItems.add(item as String);
        },
        const QueuerOptions<String>(
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
      queuer = Queuer<String>(
        (item) {
          executedItems.add(item as String);
        },
        const QueuerOptions<String>(
          enabled: false,
          maxSize: 3,
        ),
      );

      expect(queuer.options.enabled, false);
      expect(queuer.state.status, PacerStatus.disabled);
    });

    test('disabled queuer ignores addItem calls', () {
      queuer = Queuer<String>(
        (item) {
          executedItems.add(item as String);
        },
        const QueuerOptions<String>(
          enabled: false,
          maxSize: 2,
        ),
      );

      final added = queuer.addItem('test');
      expect(added, false);
      expect(queuer.state.size, 0);
      expect(executedItems, isEmpty);
    });

    test('addItem adds to queue and starts processing when started', () {
      queuer = Queuer<String>(
        (item) {
          executedItems.add(item as String);
        },
        const QueuerOptions<String>(
          maxSize: 10,
          started: true,
        ),
      );

      final added = queuer.addItem('first');
      expect(added, true);
      expect(queuer.state.size, 0); // Processed immediately
      expect(executedItems, ['first']);
    });

    test('addItem schedules execution when wait is set', () async {
      queuer = Queuer<String>(
        (item) {
          executedItems.add(item as String);
        },
        const QueuerOptions<String>(
          wait: Duration(milliseconds: 50),
          started: true,
        ),
      );

      queuer.addItem('first');
      expect(queuer.state.isRunning, true);
      expect(queuer.state.status, PacerStatus.running);
      expect(executedItems, isEmpty);

      await Future.delayed(const Duration(milliseconds: 60));
      expect(executedItems, ['first']);
      // Queuer may stay running if configured to do so
      expect(queuer.state.status != PacerStatus.disabled, true);
    });

    test('addItem rejects when queue is full', () {
      int rejectionCount = 0;
      queuer = Queuer<String>(
        (item) {
          executedItems.add(item as String);
        },
        QueuerOptions<String>(
          maxSize: 2,
          onReject: (item) => rejectionCount++,
        ),
      );

      queuer.addItem('first');
      queuer.addItem('second');
      final added = queuer.addItem('third');

      expect(added, false);
      expect(queuer.state.size, 2); // Items not processed
      expect(executedItems, isEmpty);
      expect(rejectionCount, 1);
      expect(queuer.state.rejectionCount, 1);
    });

    test('getNextItem returns null when empty', () {
      queuer = Queuer<String>(
        (item) {
          executedItems.add(item as String);
        },
        const QueuerOptions<String>(),
      );

      final item = queuer.getNextItem();
      expect(item, null);
    });

    test('getNextItem returns and removes items from queue', () {
      queuer = Queuer<String>(
        (item) {
          executedItems.add(item as String);
        },
        const QueuerOptions<String>(),
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
      queuer = Queuer<String>(
        (item) {
          executedItems.add(item as String);
        },
        const QueuerOptions<String>(
          wait: Duration(milliseconds: 50),
        ),
      );

      queuer.addItem('first');
      queuer.addItem('second');
      expect(queuer.state.isRunning, false);

      queuer.start();
      expect(queuer.state.isRunning, true);
      expect(queuer.state.status, PacerStatus.running);

      await Future.delayed(const Duration(milliseconds: 120));
      expect(executedItems, ['first', 'second']);
    });

    test('stop halts processing', () async {
      queuer = Queuer<String>(
        (item) {
          executedItems.add(item as String);
        },
        const QueuerOptions<String>(
          wait: Duration(milliseconds: 200), // Longer wait
        ),
      );

      queuer.addItem('first');
      queuer.addItem('second');
      queuer.start(); // Start manually
      expect(queuer.state.isRunning, true);

      // Stop immediately after starting
      queuer.stop();
      expect(queuer.state.isRunning, false);
      expect(queuer.state.status, PacerStatus.idle);

      await Future.delayed(const Duration(milliseconds: 250));
      expect(executedItems, isEmpty); // No processing occurred
      expect(queuer.state.size, 2); // Items still in queue
    });

    test('clear removes all items', () {
      queuer = Queuer<String>(
        (item) {
          executedItems.add(item as String);
        },
        const QueuerOptions<String>(),
      );

      queuer.addItem('first');
      queuer.addItem('second');
      expect(queuer.state.size, 2);

      queuer.clear();
      expect(queuer.state.size, 0);
      expect(queuer.state.isEmpty, true);
      expect(queuer.state.items, isEmpty);
    });

    test('reset clears items and resets counters', () {
      queuer = Queuer<String>(
        (item) {
          executedItems.add(item as String);
        },
        const QueuerOptions<String>(),
      );

      queuer.addItem('first');
      queuer.addItem('second');
      expect(queuer.state.size, 2);
      expect(queuer.state.addItemCount, 2);

      queuer.reset();
      expect(queuer.state.size, 0);
      expect(queuer.state.addItemCount, 0);
      expect(queuer.state.executionCount, 0);
    });

    test('flush processes all items immediately', () {
      queuer = Queuer<String>(
        (item) {
          executedItems.add(item as String);
        },
        const QueuerOptions<String>(
          wait: Duration(seconds: 1), // Long wait
        ),
      );

      queuer.addItem('first');
      queuer.addItem('second');
      expect(queuer.state.size, 2);
      expect(executedItems, isEmpty);

      queuer.flush();
      expect(executedItems, ['first', 'second']);
      expect(queuer.state.size, 0);
    });

    test('peekAllItems returns current items without removing them', () {
      queuer = Queuer<String>(
        (item) {
          executedItems.add(item as String);
        },
        const QueuerOptions<String>(),
      );

      queuer.addItem('first');
      queuer.addItem('second');

      final items = queuer.peekAllItems();
      expect(items, ['first', 'second']);
      expect(queuer.state.size, 2); // Items still in queue
    });

    test('setOptions with disabled option', () {
      queuer = Queuer<String>(
        (item) {
          executedItems.add(item as String);
        },
        const QueuerOptions<String>(
          maxSize: 5,
          wait: Duration(milliseconds: 100),
          started: true,
        ),
      );

      queuer.addItem('test');
      expect(queuer.state.status, PacerStatus.running);

      queuer.setOptions(
        const QueuerOptions<String>(
          enabled: false,
          maxSize: 5,
        ),
      );

      expect(queuer.options.enabled, false);
      expect(queuer.state.status, PacerStatus.disabled);
      expect(queuer.state.isRunning, false);
    });

    test('setOptions with enabled option', () {
      queuer = Queuer<String>(
        (item) {
          executedItems.add(item as String);
        },
        const QueuerOptions<String>(
          enabled: false,
          maxSize: 5,
        ),
      );

      expect(queuer.state.status, PacerStatus.disabled);

      queuer.setOptions(
        const QueuerOptions<String>(
          maxSize: 5,
        ),
      );

      expect(queuer.options.enabled, true);
      expect(queuer.state.status, PacerStatus.idle);
    });

    test('LIFO ordering with getItemsFrom back', () {
      queuer = Queuer<String>(
        (item) {
          executedItems.add(item as String);
        },
        const QueuerOptions<String>(
          getItemsFrom: QueuePosition.back,
        ),
      );

      queuer.addItem('first');
      queuer.addItem('second');
      queuer.addItem('third');

      queuer.flush();
      expect(executedItems, ['third', 'second', 'first']);
    });

    test('FIFO ordering by default', () {
      queuer = Queuer<String>(
        (item) {
          executedItems.add(item as String);
        },
        const QueuerOptions<String>(),
      );

      queuer.addItem('first');
      queuer.addItem('second');
      queuer.addItem('third');

      queuer.flush();
      expect(executedItems, ['first', 'second', 'third']); // FIFO order
    });

    test('item expiration', () async {
      int expiredCount = 0;
      queuer = Queuer<String>(
        (item) {
          executedItems.add(item as String);
        },
        QueuerOptions<String>(
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
