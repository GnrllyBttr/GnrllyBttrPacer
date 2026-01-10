import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gnrllybttr_pacer/src/debouncer/async_debouncer.dart';
import 'package:gnrllybttr_pacer/src/debouncer/models.dart';
import 'package:gnrllybttr_pacer/src/common/common.dart';

void main() {
  group('AsyncDebouncer', () {
    late AsyncDebouncer<String> debouncer;
    late List<String> executedArgs;
    late List<String> callLog;
    late List<dynamic> results;
    late List<dynamic> errors;

    setUp(() {
      executedArgs = [];
      callLog = [];
      results = [];
      errors = [];
    });

    tearDown(() {
      debouncer.cancel();
    });

    test('constructor with enabled options', () {
      debouncer = AsyncDebouncer<String>(
        (args) async {
          executedArgs.add(args);
          return 'result_$args';
        },
        const AsyncDebouncerOptions<String>(
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
      debouncer = AsyncDebouncer<String>(
        (args) async => 'result_$args',
        const AsyncDebouncerOptions<String>(
          enabled: false,
          wait: Duration(milliseconds: 100),
        ),
      );

      expect(debouncer.options.enabled, false);
      expect(debouncer.state.status, PacerStatus.disabled);
    });

    test('maybeExecute throws when disabled', () {
      debouncer = AsyncDebouncer<String>(
        (args) async => 'result_$args',
        const AsyncDebouncerOptions<String>(
          enabled: false,
          wait: Duration(milliseconds: 100),
        ),
      );

      expect(() => debouncer.maybeExecute('test'), throwsException);
    });

    test('maybeExecute with trailing edge delays execution', () async {
      debouncer = AsyncDebouncer<String>(
        (args) async {
          executedArgs.add(args);
          callLog.add('execute:$args');
          await Future.delayed(const Duration(milliseconds: 10));
          return 'result_$args';
        },
        AsyncDebouncerOptions<String>(
          wait: const Duration(milliseconds: 50),
          onExecute: (args) => callLog.add('onExecute:$args'),
          onSuccess: (result) => results.add(result),
        ),
      );

      // First call starts timer
      final future1 = debouncer.maybeExecute('first');
      expect(debouncer.state.isPending, true);
      expect(debouncer.state.status, PacerStatus.pending);

      // Call again before timer expires
      final future2 = debouncer.maybeExecute('second');
      expect(executedArgs, isEmpty);

      // Wait for execution
      await Future.delayed(const Duration(milliseconds: 60));
      final result1 = await future1;
      final result2 = await future2;
      expect(result1, 'result_second'); // Last call wins
      expect(result2, 'result_second');
      expect(executedArgs, ['second']);
      expect(callLog, ['execute:second', 'onExecute:second']);
      expect(results, ['result_second']);
      expect(debouncer.state.executionCount, 1);
      expect(debouncer.state.successCount, 1);
      expect(debouncer.state.settleCount, 1);
      expect(debouncer.state.isPending, false);
      expect(debouncer.state.status, PacerStatus.idle);
    });

    test('maybeExecute with leading edge executes immediately', () async {
      debouncer = AsyncDebouncer<String>(
        (args) async {
          executedArgs.add(args);
          callLog.add('execute:$args');
          await Future.delayed(const Duration(milliseconds: 10));
          return 'result_$args';
        },
        AsyncDebouncerOptions<String>(
          wait: const Duration(milliseconds: 50),
          leading: true,
          trailing: false,
          onExecute: (args) => callLog.add('onExecute:$args'),
          onSuccess: (result) => results.add(result),
        ),
      );

      // First call executes immediately
      final future1 = debouncer.maybeExecute('first');
      expect(debouncer.state.isExecuting, true);
      expect(debouncer.state.status, PacerStatus.executing);

      final result1 = await future1;
      expect(result1, 'result_first');
      expect(executedArgs, ['first']);
      expect(callLog, ['execute:first', 'onExecute:first']);
      expect(results, ['result_first']);
      expect(debouncer.state.executionCount, 1);

      // Subsequent calls don't execute immediately
      final future2 = debouncer.maybeExecute('second');
      expect(executedArgs, ['first']); // No additional execution

      // Wait for reset period
      await Future.delayed(const Duration(milliseconds: 60));

      // Next call executes immediately again
      final future3 = debouncer.maybeExecute('third');
      final result3 = await future3;
      expect(result3, 'result_third');
      expect(executedArgs, ['first', 'third']);
      expect(debouncer.state.executionCount, 2);
    });

    test('maybeExecute with both leading and trailing', () async {
      debouncer = AsyncDebouncer<String>(
        (args) async {
          executedArgs.add(args);
          await Future.delayed(const Duration(milliseconds: 5));
          return 'result_$args';
        },
        const AsyncDebouncerOptions<String>(
          wait: Duration(milliseconds: 50),
          leading: true,
        ),
      );

      // First call executes immediately (leading)
      final future1 = debouncer.maybeExecute('first');
      expect(await future1, 'result_first');
      expect(executedArgs, ['first']);

      // Subsequent calls reset timer
      final future2 = debouncer.maybeExecute('second');
      expect(executedArgs, ['first']); // No additional execution

      // Wait for trailing execution
      await Future.delayed(const Duration(milliseconds: 60));
      expect(await future2, 'result_second');
      expect(executedArgs, ['first', 'second']);
    });

    test('maybeExecute handles errors with throwOnError true', () async {
      debouncer = AsyncDebouncer<String>(
        (args) async {
          throw Exception('Test error');
        },
        AsyncDebouncerOptions<String>(
          wait: const Duration(milliseconds: 30),
          leading: true,
          trailing: false,
          throwOnError: true,
          onError: (error) => errors.add(error),
        ),
      );

      final future = debouncer.maybeExecute('test');
      await expectLater(future, throwsException);
      expect(debouncer.state.errorCount, 1);
      expect(debouncer.state.successCount, 0);
      expect(debouncer.state.settleCount, 1);
      expect(errors.length, 1);
    });

    test('maybeExecute handles errors with throwOnError false', () async {
      debouncer = AsyncDebouncer<String>(
        (args) async {
          throw Exception('Test error');
        },
        AsyncDebouncerOptions<String>(
          wait: const Duration(milliseconds: 30),
          leading: true,
          trailing: false,
          onError: (error) => errors.add(error),
        ),
      );

      final future = debouncer.maybeExecute('test');
      final result = await future;
      expect(result, null);
      expect(debouncer.state.errorCount, 1);
      expect(debouncer.state.successCount, 0);
      expect(debouncer.state.settleCount, 1);
      expect(errors.length, 1);
    });

    test('abort cancels pending execution', () async {
      debouncer = AsyncDebouncer<String>(
        (args) async {
          executedArgs.add(args);
          await Future.delayed(const Duration(milliseconds: 50));
          return 'result_$args';
        },
        const AsyncDebouncerOptions<String>(
          wait: Duration(milliseconds: 30),
        ),
      );

      final future = debouncer.maybeExecute('test');
      expect(debouncer.state.isPending, true);

      debouncer.abort();

      await expectLater(
        future,
        throwsA(predicate((e) => e.toString().contains('Aborted'))),
      );
      expect(executedArgs, isEmpty);
      expect(debouncer.state.isPending, false);
      expect(debouncer.state.status, PacerStatus.idle);
    });

    test('cancel is alias for abort', () async {
      debouncer = AsyncDebouncer<String>(
        (args) async => 'result_$args',
        const AsyncDebouncerOptions<String>(
          wait: Duration(milliseconds: 30),
        ),
      );

      debouncer.maybeExecute('test');
      expect(debouncer.state.isPending, true);

      debouncer.cancel();
      expect(debouncer.state.isPending, false);
    });

    test('flush executes pending call immediately', () async {
      debouncer = AsyncDebouncer<String>(
        (args) async {
          executedArgs.add(args);
          await Future.delayed(const Duration(milliseconds: 10));
          return 'result_$args';
        },
        const AsyncDebouncerOptions<String>(
          wait: Duration(milliseconds: 100),
        ),
      );

      final future = debouncer.maybeExecute('test');
      expect(debouncer.state.isPending, true);
      expect(executedArgs, isEmpty);

      debouncer.flush();
      final result = await future;
      expect(result, 'result_test');
      expect(executedArgs, ['test']);
      expect(debouncer.state.isPending, false);
      expect(debouncer.state.status, PacerStatus.idle);
    });

    test('flush does nothing when not trailing or no pending call', () {
      debouncer = AsyncDebouncer<String>(
        (args) async => 'result_$args',
        const AsyncDebouncerOptions<String>(
          wait: Duration(milliseconds: 100),
          leading: true,
          trailing: false,
        ),
      );

      debouncer.flush(); // Should not crash
      expect(debouncer.state.isPending, false);
    });

    test('setOptions with disabled option', () {
      debouncer = AsyncDebouncer<String>(
        (args) async => 'result_$args',
        const AsyncDebouncerOptions<String>(
          wait: Duration(milliseconds: 100),
        ),
      );

      // Schedule a call
      debouncer.maybeExecute('test');
      expect(debouncer.state.status, PacerStatus.pending);

      // Disable debouncer
      debouncer.setOptions(
        const AsyncDebouncerOptions<String>(
          enabled: false,
          wait: Duration(milliseconds: 100),
        ),
      );

      expect(debouncer.options.enabled, false);
      expect(debouncer.state.status, PacerStatus.disabled);
      expect(debouncer.state.isPending, false);
    });

    test('setOptions with enabled option', () {
      debouncer = AsyncDebouncer<String>(
        (args) async => 'result_$args',
        const AsyncDebouncerOptions<String>(
          enabled: false,
          wait: Duration(milliseconds: 100),
        ),
      );

      expect(debouncer.state.status, PacerStatus.disabled);

      // Enable debouncer
      debouncer.setOptions(
        const AsyncDebouncerOptions<String>(
          wait: Duration(milliseconds: 100),
        ),
      );

      expect(debouncer.options.enabled, true);
      expect(debouncer.state.status, PacerStatus.idle);
    });

    test('onSettled callback is called', () async {
      final List<dynamic> settledResults = [];
      final List<dynamic> settledErrors = [];

      debouncer = AsyncDebouncer<String>(
        (args) async {
          executedArgs.add(args);
          return 'result_$args';
        },
        AsyncDebouncerOptions<String>(
          wait: const Duration(milliseconds: 30),
          leading: true,
          trailing: false,
          onSettled: (result, error) {
            settledResults.add(result);
            settledErrors.add(error);
          },
        ),
      );

      await debouncer.maybeExecute('test');
      expect(settledResults, ['result_test']);
      expect(settledErrors, [null]);
    });
  });
}
