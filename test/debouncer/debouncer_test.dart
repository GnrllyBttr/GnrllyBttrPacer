import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gnrllybttr_pacer/src/debouncer/debouncer.dart';
import 'package:gnrllybttr_pacer/src/debouncer/models.dart';
import 'package:gnrllybttr_pacer/src/common/common.dart';

void main() {
  group('Debouncer', () {
    late Debouncer<String> debouncer;
    late List<String> executedArgs;
    late List<String> callLog;

    setUp(() {
      executedArgs = [];
      callLog = [];
    });

    tearDown(() {
      debouncer.cancel();
    });

    test('constructor with enabled options', () {
      debouncer = Debouncer<String>(
        (args) {
          executedArgs.add(args);
        },
        const DebouncerOptions<String>(
          wait: Duration(milliseconds: 100),
          leading: true,
        ),
      );

      expect(debouncer.options.enabled, true);
      expect(debouncer.state.status, PacerStatus.idle);
      expect(debouncer.state.maybeExecuteCount, 0);
      expect(debouncer.state.isPending, false);
    });

    test('constructor with disabled options', () {
      debouncer = Debouncer<String>(
        (args) {
          executedArgs.add(args);
        },
        const DebouncerOptions<String>(
          enabled: false,
          wait: Duration(milliseconds: 100),
        ),
      );

      expect(debouncer.options.enabled, false);
      expect(debouncer.state.status, PacerStatus.disabled);
    });

    test('maybeExecute with trailing edge delays execution', () async {
      debouncer = Debouncer<String>(
        (args) {
          executedArgs.add(args);
          callLog.add('execute:$args');
        },
        DebouncerOptions<String>(
          wait: const Duration(milliseconds: 50),
          onExecute: (args) => callLog.add('onExecute:$args'),
        ),
      );

      // First call starts timer
      debouncer.maybeExecute('first');
      expect(executedArgs, isEmpty);
      expect(debouncer.state.isPending, true);
      expect(debouncer.state.status, PacerStatus.pending);

      // Call again before timer expires
      debouncer.maybeExecute('second');
      expect(executedArgs, isEmpty);

      // Wait for execution
      await Future.delayed(const Duration(milliseconds: 60));
      expect(executedArgs, ['second']); // Last call wins
      expect(callLog, ['onExecute:second', 'execute:second']);
      expect(debouncer.state.isPending, false);
      expect(debouncer.state.status, PacerStatus.idle);
      expect(debouncer.state.executionCount, 1);
    });

    test('maybeExecute with leading edge executes immediately', () async {
      debouncer = Debouncer<String>(
        (args) {
          executedArgs.add(args);
          callLog.add('execute:$args');
        },
        DebouncerOptions<String>(
          wait: const Duration(milliseconds: 50),
          leading: true,
          trailing: false,
          onExecute: (args) => callLog.add('onExecute:$args'),
        ),
      );

      // First call executes immediately
      debouncer.maybeExecute('first');
      expect(executedArgs, ['first']);
      expect(callLog, ['onExecute:first', 'execute:first']);
      expect(debouncer.state.executionCount, 1);

      // Subsequent calls don't execute until reset
      debouncer.maybeExecute('second');
      expect(executedArgs, ['first']);
      expect(debouncer.state.maybeExecuteCount, 2);

      // Wait for reset period
      await Future.delayed(const Duration(milliseconds: 60));

      // Next call executes immediately again
      debouncer.maybeExecute('third');
      expect(executedArgs, ['first', 'third']);
      expect(debouncer.state.executionCount, 2);
    });

    test('maybeExecute with both leading and trailing', () async {
      debouncer = Debouncer<String>(
        (args) {
          executedArgs.add(args);
          callLog.add('execute:$args:${DateTime.now().millisecondsSinceEpoch}');
        },
        DebouncerOptions<String>(
          wait: const Duration(milliseconds: 50),
          leading: true,
          onExecute: (args) => callLog.add('onExecute:$args'),
        ),
      );

      // First call executes immediately (leading)
      debouncer.maybeExecute('first');
      expect(executedArgs, ['first']);

      // Subsequent calls reset timer
      debouncer.maybeExecute('second');
      expect(executedArgs, ['first']); // No additional execution

      // Wait for trailing execution
      await Future.delayed(const Duration(milliseconds: 60));
      expect(executedArgs.length, 2); // Should have trailing execution
      expect(executedArgs[1], 'second');
    });

    test('cancel stops pending execution', () async {
      debouncer = Debouncer<String>(
        (args) {
          executedArgs.add(args);
        },
        const DebouncerOptions<String>(
          wait: Duration(milliseconds: 50),
        ),
      );

      debouncer.maybeExecute('test');
      expect(debouncer.state.isPending, true);

      debouncer.cancel();
      expect(debouncer.state.isPending, false);
      expect(debouncer.state.status, PacerStatus.idle);

      // Wait and verify no execution occurred
      await Future.delayed(const Duration(milliseconds: 60));
      expect(executedArgs, isEmpty);
    });

    test('flush executes pending call immediately', () async {
      debouncer = Debouncer<String>(
        (args) {
          executedArgs.add(args);
        },
        const DebouncerOptions<String>(
          wait: Duration(milliseconds: 100),
        ),
      );

      debouncer.maybeExecute('test');
      expect(debouncer.state.isPending, true);
      expect(executedArgs, isEmpty);

      debouncer.flush();
      expect(executedArgs, ['test']);
      expect(debouncer.state.isPending, false);
      expect(debouncer.state.status, PacerStatus.idle);
    });

    test('flush does nothing when not trailing or no pending call', () {
      debouncer = Debouncer<String>(
        (args) {
          executedArgs.add(args);
        },
        const DebouncerOptions<String>(
          wait: Duration(milliseconds: 100),
          leading: true,
          trailing: false,
        ),
      );

      debouncer.flush(); // Should not crash
      expect(executedArgs, isEmpty);
    });

    test('setOptions with disabled option', () {
      debouncer = Debouncer<String>(
        (args) {
          executedArgs.add(args);
        },
        const DebouncerOptions<String>(
          wait: Duration(milliseconds: 100),
        ),
      );

      // Schedule a call
      debouncer.maybeExecute('test');
      expect(debouncer.state.status, PacerStatus.pending);

      // Disable debouncer
      debouncer.setOptions(
        const DebouncerOptions<String>(
          enabled: false,
          wait: Duration(milliseconds: 100),
        ),
      );

      expect(debouncer.options.enabled, false);
      expect(debouncer.state.status, PacerStatus.disabled);
      expect(debouncer.state.isPending, false);
    });

    test('setOptions with enabled option', () {
      debouncer = Debouncer<String>(
        (args) {
          executedArgs.add(args);
        },
        const DebouncerOptions<String>(
          enabled: false,
          wait: Duration(milliseconds: 100),
        ),
      );

      expect(debouncer.state.status, PacerStatus.disabled);

      // Enable debouncer
      debouncer.setOptions(
        const DebouncerOptions<String>(
          wait: Duration(milliseconds: 100),
        ),
      );

      expect(debouncer.options.enabled, true);
      expect(debouncer.state.status, PacerStatus.idle);
    });

    test('disabled debouncer ignores maybeExecute calls', () {
      debouncer = Debouncer<String>(
        (args) {
          executedArgs.add(args);
        },
        const DebouncerOptions<String>(
          enabled: false,
          wait: Duration(milliseconds: 100),
        ),
      );

      debouncer.maybeExecute('test');
      expect(executedArgs, isEmpty);
      expect(debouncer.state.maybeExecuteCount, 0);
    });

    test('multiple rapid calls update lastArgs correctly', () async {
      debouncer = Debouncer<String>(
        (args) {
          executedArgs.add(args);
        },
        const DebouncerOptions<String>(
          wait: Duration(milliseconds: 30),
        ),
      );

      debouncer.maybeExecute('first');
      expect(debouncer.state.lastArgs, 'first');

      debouncer.maybeExecute('second');
      expect(debouncer.state.lastArgs, 'second');

      debouncer.maybeExecute('third');
      expect(debouncer.state.lastArgs, 'third');

      await Future.delayed(const Duration(milliseconds: 40));
      expect(executedArgs, ['third']); // Only last call executes
    });

    test('leading execution prevents subsequent leading executions', () async {
      debouncer = Debouncer<String>(
        (args) {
          executedArgs.add(args);
        },
        const DebouncerOptions<String>(
          wait: Duration(milliseconds: 50),
          leading: true,
        ),
      );

      // First call executes immediately
      debouncer.maybeExecute('first');
      expect(executedArgs, ['first']);

      // Subsequent calls don't execute immediately
      debouncer.maybeExecute('second');
      debouncer.maybeExecute('third');
      expect(executedArgs, ['first']);

      // Wait for reset and trailing execution
      await Future.delayed(const Duration(milliseconds: 60));
      expect(executedArgs, ['first', 'third']);
    });

    test('execution count increments correctly', () async {
      debouncer = Debouncer<String>(
        (args) {
          executedArgs.add(args);
        },
        const DebouncerOptions<String>(
          wait: Duration(milliseconds: 30),
        ),
      );

      debouncer.maybeExecute('first');
      expect(debouncer.state.executionCount, 0); // Not executed yet

      await Future.delayed(const Duration(milliseconds: 40));
      expect(debouncer.state.executionCount, 1); // Now executed

      debouncer.maybeExecute('second');
      await Future.delayed(const Duration(milliseconds: 40));
      expect(debouncer.state.executionCount, 2); // Second execution
    });
  });
}
