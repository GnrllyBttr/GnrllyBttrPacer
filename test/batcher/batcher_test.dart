import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gnrllybttr_pacer/src/batcher/batcher.dart';
import 'package:gnrllybttr_pacer/src/batcher/models.dart';
import 'package:gnrllybttr_pacer/src/common/common.dart';

void main() {
  group('Batcher', () {
    late Batcher<String> batcher;
    late List<List<String>> executedBatches;

    setUp(() {
      executedBatches = [];
    });

    tearDown(() {
      batcher.stop();
    });

    test('constructor with enabled options', () {
      batcher = Batcher<String>(
        (items) {
          executedBatches.add(items as List<String>);
        },
        const BatcherOptions<String>(
          maxSize: 3,
          wait: Duration(milliseconds: 100),
        ),
      );

      expect(batcher.options.enabled, true);
      expect(batcher.state.status, PacerStatus.idle);
      expect(batcher.state.isEmpty, true);
      expect(batcher.state.size, 0);
    });

    test('constructor with disabled options', () {
      batcher = Batcher<String>(
        (items) {
          executedBatches.add(items as List<String>);
        },
        const BatcherOptions<String>(
          enabled: false,
          maxSize: 3,
        ),
      );

      expect(batcher.options.enabled, false);
      expect(batcher.state.status, PacerStatus.disabled);
    });

    test('disabled batcher ignores addItem calls', () {
      batcher = Batcher<String>(
        (items) {
          executedBatches.add(items as List<String>);
        },
        const BatcherOptions<String>(
          enabled: false,
          maxSize: 2,
        ),
      );

      batcher.addItem('test');
      expect(batcher.state.size, 0);
      expect(executedBatches, isEmpty);
    });

    test('addItem executes when custom shouldExecute returns true', () {
      batcher = Batcher<String>(
        (items) {
          executedBatches.add(items as List<String>);
        },
        BatcherOptions<String>(
          getShouldExecute: (items) => items.contains('trigger'),
        ),
      );

      batcher.addItem('first');
      expect(executedBatches, isEmpty);

      batcher.addItem('trigger');
      expect(executedBatches, [
        ['first', 'trigger']
      ]);
    });

    test('addItem schedules execution when wait is set', () async {
      batcher = Batcher<String>(
        (items) {
          executedBatches.add(items as List<String>);
        },
        const BatcherOptions<String>(
          wait: Duration(milliseconds: 50),
        ),
      );

      batcher.addItem('first');
      expect(batcher.state.isPending, true);
      expect(batcher.state.status, PacerStatus.pending);
      expect(executedBatches, isEmpty);

      await Future.delayed(const Duration(milliseconds: 60));
      expect(executedBatches, [
        ['first']
      ]);
      expect(batcher.state.isPending, false);
      expect(batcher.state.status, PacerStatus.idle);
    });

    test('execute processes all items immediately', () {
      batcher = Batcher<String>(
        (items) {
          executedBatches.add(items as List<String>);
        },
        const BatcherOptions<String>(
          maxSize: 10,
        ),
      );

      batcher.addItem('first');
      batcher.addItem('second');
      batcher.addItem('third');

      expect(batcher.state.size, 3);
      expect(executedBatches, isEmpty);

      batcher.execute();
      expect(executedBatches, [
        ['first', 'second', 'third']
      ]);
      expect(batcher.state.size, 0);
      expect(batcher.state.isEmpty, true);
    });

    test('execute does nothing when batch is empty', () {
      batcher = Batcher<String>(
        (items) {
          executedBatches.add(items as List<String>);
        },
        const BatcherOptions<String>(),
      );

      batcher.execute(); // Should not crash
      expect(executedBatches, isEmpty);
    });

    test('stop cancels pending execution', () async {
      batcher = Batcher<String>(
        (items) {
          executedBatches.add(items as List<String>);
        },
        const BatcherOptions<String>(
          wait: Duration(milliseconds: 50),
        ),
      );

      batcher.addItem('first');
      expect(batcher.state.isPending, true);

      batcher.stop();
      expect(batcher.state.isPending, false);
      expect(batcher.state.status, PacerStatus.idle);

      // Wait and verify no execution occurred
      await Future.delayed(const Duration(milliseconds: 60));
      expect(executedBatches, isEmpty);
      expect(batcher.state.size, 1); // Item still in batch
    });

    test('flush executes immediately if not empty', () {
      batcher = Batcher<String>(
        (items) {
          executedBatches.add(items as List<String>);
        },
        const BatcherOptions<String>(
          maxSize: 10,
        ),
      );

      batcher.addItem('first');
      batcher.addItem('second');

      expect(batcher.state.size, 2);
      expect(executedBatches, isEmpty);

      batcher.flush();
      expect(executedBatches, [
        ['first', 'second']
      ]);
      expect(batcher.state.size, 0);
    });

    test('flush does nothing when empty', () {
      batcher = Batcher<String>(
        (items) {
          executedBatches.add(items as List<String>);
        },
        const BatcherOptions<String>(),
      );

      batcher.flush(); // Should not crash
      expect(executedBatches, isEmpty);
    });

    test('peekAllItems returns current items without executing', () {
      batcher = Batcher<String>(
        (items) {
          executedBatches.add(items as List<String>);
        },
        const BatcherOptions<String>(
          maxSize: 10,
        ),
      );

      batcher.addItem('first');
      batcher.addItem('second');

      final items = batcher.peekAllItems();
      expect(items, ['first', 'second']);
      expect(batcher.state.size, 2); // Items still in batch
      expect(executedBatches, isEmpty); // Not executed
    });

    test('setOptions with disabled option', () {
      batcher = Batcher<String>(
        (items) {
          executedBatches.add(items as List<String>);
        },
        const BatcherOptions<String>(
          maxSize: 5,
          wait: Duration(milliseconds: 100),
        ),
      );

      // Add an item and schedule execution
      batcher.addItem('test');
      expect(batcher.state.status, PacerStatus.pending);

      // Disable batcher
      batcher.setOptions(
        const BatcherOptions<String>(
          enabled: false,
          maxSize: 5,
        ),
      );

      expect(batcher.options.enabled, false);
      expect(batcher.state.status, PacerStatus.disabled);
      expect(batcher.state.isPending, false);
    });

    test('setOptions with enabled option', () {
      batcher = Batcher<String>(
        (items) {
          executedBatches.add(items as List<String>);
        },
        const BatcherOptions<String>(
          enabled: false,
          maxSize: 5,
        ),
      );

      expect(batcher.state.status, PacerStatus.disabled);

      // Enable batcher
      batcher.setOptions(
        const BatcherOptions<String>(
          maxSize: 5,
        ),
      );

      expect(batcher.options.enabled, true);
      expect(batcher.state.status, PacerStatus.idle);
    });

    test('disabled batcher ignores addItem calls', () {
      batcher = Batcher<String>(
        (items) {
          executedBatches.add(items as List<String>);
        },
        const BatcherOptions<String>(
          enabled: false,
          maxSize: 2,
        ),
      );

      batcher.addItem('test');
      expect(batcher.state.size, 0);
      expect(executedBatches, isEmpty);
    });

    test('multiple items accumulate correctly', () {
      batcher = Batcher<String>(
        (items) {
          executedBatches.add(items as List<String>);
        },
        const BatcherOptions<String>(
          maxSize: 3,
        ),
      );

      batcher.addItem('first');
      expect(batcher.state.items, ['first']);
      expect(batcher.state.size, 1);

      batcher.addItem('second');
      expect(batcher.state.items, ['first', 'second']);
      expect(batcher.state.size, 2);

      batcher.addItem('third');
      expect(batcher.state.items, ['first', 'second', 'third']);
      expect(batcher.state.size, 3);

      // Should have executed
      expect(executedBatches, [
        ['first', 'second', 'third']
      ]);
      expect(batcher.state.size, 0);
    });

    test('onItemsChange callback is called', () {
      final List<List<String>> changedItems = [];

      batcher = Batcher<String>(
        (items) {
          executedBatches.add(items as List<String>);
        },
        BatcherOptions<String>(
          maxSize: 3,
          onItemsChange: (items) => changedItems.add(List.from(items)),
        ),
      );

      batcher.addItem('first');
      expect(changedItems, [
        ['first']
      ]);

      batcher.addItem('second');
      expect(changedItems, [
        ['first'],
        ['first', 'second']
      ]);
    });

    test('execution clears batch state', () {
      batcher = Batcher<String>(
        (items) {
          executedBatches.add(items as List<String>);
        },
        const BatcherOptions<String>(
          maxSize: 2,
        ),
      );

      batcher.addItem('first');
      batcher.addItem('second');

      expect(batcher.state.size, 0); // Executed automatically
      expect(batcher.state.isEmpty, true);
      expect(batcher.state.items, isEmpty);
    });
  });
}
