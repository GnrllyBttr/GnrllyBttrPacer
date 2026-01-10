import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gnrllybttr_pacer/src/throttler/async_throttler.dart';
import 'package:gnrllybttr_pacer/src/throttler/models.dart';
import 'package:gnrllybttr_pacer/src/common/common.dart';

void main() {
  group('AsyncThrottler', () {
    late AsyncThrottler<String> throttler;
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
      throttler.cancel();
    });

    test('constructor with enabled options', () {
      throttler = AsyncThrottler<String>(
        (args) async {
          executedArgs.add(args);
          return 'result_$args';
        },
        AsyncThrottlerOptions<String>(
          wait: Duration(milliseconds: 100),
          leading: true,
          trailing: true,
        ),
      );

      expect(throttler.options.enabled, true);
      expect(throttler.state.status, PacerStatus.idle);
      expect(throttler.state.maybeExecuteCount, 0);
    });

    test('constructor with disabled options', () {
      throttler = AsyncThrottler<String>(
        (args) async => 'result_$args',
        AsyncThrottlerOptions<String>(
          enabled: false,
          wait: Duration(milliseconds: 100),
        ),
      );

      expect(throttler.options.enabled, false);
      expect(throttler.state.status, PacerStatus.disabled);
    });

    test('maybeExecute throws when disabled', () {
      throttler = AsyncThrottler<String>(
        (args) async => 'result_$args',
        AsyncThrottlerOptions<String>(
          enabled: false,
          wait: Duration(milliseconds: 100),
        ),
      );

      expect(() => throttler.maybeExecute('test'), throwsException);
    });

    test('maybeExecute with leading edge executes immediately', () async {
      throttler = AsyncThrottler<String>(
        (args) async {
          executedArgs.add(args);
          callLog.add('execute:$args');
          await Future.delayed(Duration(milliseconds: 10));
          return 'result_$args';
        },
        AsyncThrottlerOptions<String>(
          wait: Duration(milliseconds: 100),
          leading: true,
          trailing: false,
          onExecute: (args) => callLog.add('onExecute:$args'),
          onSuccess: (result) => results.add(result),
        ),
      );

      final future = throttler.maybeExecute('first');
      expect(throttler.state.isExecuting, true);
      expect(throttler.state.status, PacerStatus.executing);

      final result = await future;
      expect(result, 'result_first');
      expect(executedArgs, ['first']);
      expect(callLog, ['execute:first', 'onExecute:first']);
      expect(results, ['result_first']);
      expect(throttler.state.executionCount, 1);
      expect(throttler.state.successCount, 1);
      expect(throttler.state.settleCount, 1);
      expect(throttler.state.isExecuting, false);
    });

    test('maybeExecute throttles subsequent calls with leading edge', () async {
      throttler = AsyncThrottler<String>(
        (args) async {
          executedArgs.add(args);
          await Future.delayed(Duration(milliseconds: 10));
          return 'result_$args';
        },
        AsyncThrottlerOptions<String>(
          wait: Duration(milliseconds: 50),
          leading: true,
          trailing: false,
        ),
      );

      // First call executes immediately
      final future1 = throttler.maybeExecute('first');
      expect(await future1, 'result_first');
      expect(executedArgs, ['first']);

      // Subsequent calls within throttle period throw
      expect(() => throttler.maybeExecute('second'), throwsException);
      expect(() => throttler.maybeExecute('third'), throwsException);
      expect(executedArgs, ['first']);
      expect(throttler.state.maybeExecuteCount, 3);

      // Wait for throttle period to expire
      await Future.delayed(Duration(milliseconds: 60));

      // Next call should execute
      final future4 = throttler.maybeExecute('fourth');
      expect(await future4, 'result_fourth');
      expect(executedArgs, ['first', 'fourth']);
    });

    test('maybeExecute with trailing edge schedules delayed execution', () async {
      throttler = AsyncThrottler<String>(
        (args) async {
          executedArgs.add(args);
          await Future.delayed(Duration(milliseconds: 10));
          return 'result_$args';
        },
        AsyncThrottlerOptions<String>(
          wait: Duration(milliseconds: 50),
          leading: false,
          trailing: true,
        ),
      );

      // First call doesn't execute immediately
      final future1 = throttler.maybeExecute('first');
      expect(executedArgs, isEmpty);
      expect(throttler.state.nextExecutionTime, isNotNull);

      // Subsequent calls update the scheduled execution
      final future2 = throttler.maybeExecute('second');
      expect(executedArgs, isEmpty);

      // Wait for execution
      await Future.delayed(Duration(milliseconds: 60));
      expect(await future1, 'result_second'); // Last call wins
      expect(await future2, 'result_second');
      expect(executedArgs, ['second']);
    });

    test('maybeExecute with both leading and trailing', () async {
      throttler = AsyncThrottler<String>(
        (args) async {
          executedArgs.add(args);
          await Future.delayed(Duration(milliseconds: 5));
          return 'result_$args';
        },
        AsyncThrottlerOptions<String>(
          wait: Duration(milliseconds: 50),
          leading: true,
          trailing: true,
        ),
      );

      // First call executes immediately (leading)
      final future1 = throttler.maybeExecute('first');
      expect(await future1, 'result_first');
      expect(executedArgs, ['first']);

      // Subsequent calls within period schedule trailing
      final future2 = throttler.maybeExecute('second');
      expect(executedArgs, ['first']);

      // Wait for trailing execution
      await Future.delayed(Duration(milliseconds: 60));
      expect(await future2, 'result_second');
      expect(executedArgs, ['first', 'second']);
    });

    test('maybeExecute handles errors with throwOnError true', () async {
      throttler = AsyncThrottler<String>(
        (args) async {
          throw Exception('Test error');
        },
        AsyncThrottlerOptions<String>(
          wait: Duration(milliseconds: 30),
          leading: true,
          trailing: false,
          throwOnError: true,
          onError: (error) => errors.add(error),
        ),
      );

      final future = throttler.maybeExecute('test');
      await expectLater(future, throwsException);
      expect(throttler.state.errorCount, 1);
      expect(throttler.state.successCount, 0);
      expect(throttler.state.settleCount, 1);
      expect(errors.length, 1);
    });

    test('maybeExecute handles errors with throwOnError false', () async {
      throttler = AsyncThrottler<String>(
        (args) async {
          throw Exception('Test error');
        },
        AsyncThrottlerOptions<String>(
          wait: Duration(milliseconds: 30),
          leading: true,
          trailing: false,
          throwOnError: false,
          onError: (error) => errors.add(error),
        ),
      );

      final future = throttler.maybeExecute('test');
      final result = await future;
      expect(result, null);
      expect(throttler.state.errorCount, 1);
      expect(throttler.state.successCount, 0);
      expect(throttler.state.settleCount, 1);
      expect(errors.length, 1);
    });

    test('abort cancels pending execution', () async {
      throttler = AsyncThrottler<String>(
        (args) async {
          executedArgs.add(args);
          await Future.delayed(Duration(milliseconds: 50));
          return 'result_$args';
        },
        AsyncThrottlerOptions<String>(
          wait: Duration(milliseconds: 30),
          leading: false,
          trailing: true,
        ),
      );

      final future = throttler.maybeExecute('test');
      expect(throttler.state.nextExecutionTime, isNotNull);

      throttler.abort();

      await expectLater(future, throwsA(predicate((e) => e.toString().contains('Aborted'))));
      expect(executedArgs, isEmpty);
    });

    test('cancel is alias for abort', () async {
      throttler = AsyncThrottler<String>(
        (args) async => 'result_$args',
        AsyncThrottlerOptions<String>(
          wait: Duration(milliseconds: 30),
          leading: false,
          trailing: true,
        ),
      );

      throttler.maybeExecute('test');
      expect(throttler.state.nextExecutionTime, isNotNull);

      throttler.cancel();
      expect(throttler.state.nextExecutionTime, null);
    });

    test('flush executes pending call immediately', () async {
      throttler = AsyncThrottler<String>(
        (args) async {
          executedArgs.add(args);
          await Future.delayed(Duration(milliseconds: 10));
          return 'result_$args';
        },
        AsyncThrottlerOptions<String>(
          wait: Duration(milliseconds: 100),
          leading: false,
          trailing: true,
        ),
      );

      final future = throttler.maybeExecute('test');
      expect(throttler.state.nextExecutionTime, isNotNull);
      expect(executedArgs, isEmpty);

      throttler.flush();
      final result = await future;
      expect(result, 'result_test');
      expect(executedArgs, ['test']);
      expect(throttler.state.nextExecutionTime, null);
    });

    test('flush does nothing when no pending call', () {
      throttler = AsyncThrottler<String>(
        (args) async => 'result_$args',
        AsyncThrottlerOptions<String>(
          wait: Duration(milliseconds: 100),
          leading: true,
          trailing: false,
        ),
      );

      throttler.flush(); // Should not crash
      expect(throttler.state.nextExecutionTime, null);
    });

    test('setOptions with disabled option', () {
      throttler = AsyncThrottler<String>(
        (args) async => 'result_$args',
        AsyncThrottlerOptions<String>(
          wait: Duration(milliseconds: 100),
          leading: true,
          trailing: true,
        ),
      );

      // Schedule a call
      throttler.maybeExecute('test');
      expect(throttler.state.status, PacerStatus.idle);

      // Disable throttler
      throttler.setOptions(AsyncThrottlerOptions<String>(
        enabled: false,
        wait: Duration(milliseconds: 100),
      ));

      expect(throttler.options.enabled, false);
      expect(throttler.state.status, PacerStatus.disabled);
    });

    test('setOptions with enabled option', () {
      throttler = AsyncThrottler<String>(
        (args) async => 'result_$args',
        AsyncThrottlerOptions<String>(
          enabled: false,
          wait: Duration(milliseconds: 100),
        ),
      );

      expect(throttler.state.status, PacerStatus.disabled);

      // Enable throttler
      throttler.setOptions(AsyncThrottlerOptions<String>(
        enabled: true,
        wait: Duration(milliseconds: 100),
      ));

      expect(throttler.options.enabled, true);
      expect(throttler.state.status, PacerStatus.idle);
    });

    test('onSettled callback is called', () async {
      List<dynamic> settledResults = [];
      List<dynamic> settledErrors = [];

      throttler = AsyncThrottler<String>(
        (args) async {
          executedArgs.add(args);
          return 'result_$args';
        },
        AsyncThrottlerOptions<String>(
          wait: Duration(milliseconds: 30),
          leading: true,
          trailing: false,
          onSettled: (result, error) {
            settledResults.add(result);
            settledErrors.add(error);
          },
        ),
      );

      await throttler.maybeExecute('test');
      expect(settledResults, ['result_test']);
      expect(settledErrors, [null]);
    });

    test('multiple rapid calls update lastArgs correctly', () async {
      throttler = AsyncThrottler<String>(
        (args) async {
          executedArgs.add(args);
          await Future.delayed(Duration(milliseconds: 10));
          return 'result_$args';
        },
        AsyncThrottlerOptions<String>(
          wait: Duration(milliseconds: 50),
          leading: false,
          trailing: true,
        ),
      );

      throttler.maybeExecute('first');
      expect(throttler.state.lastArgs, 'first');

      throttler.maybeExecute('second');
      expect(throttler.state.lastArgs, 'second');

      throttler.maybeExecute('third');
      expect(throttler.state.lastArgs, 'third');

      await Future.delayed(Duration(milliseconds: 60));
      expect(executedArgs, ['third']); // Only last call executes
    });
  });
}