import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gnrllybttr_pacer/src/throttler/throttler.dart';
import 'package:gnrllybttr_pacer/src/throttler/models.dart';
import 'package:gnrllybttr_pacer/src/common/common.dart';

void main() {
  group('Throttler', () {
    late Throttler<String> throttler;
    late List<String> executedArgs;
    late List<String> callLog;

    setUp(() {
      executedArgs = [];
      callLog = [];
    });

    tearDown(() {
      throttler.cancel();
    });

    test('constructor with enabled options', () {
      throttler = Throttler<String>(
        (args) {
          executedArgs.add(args);
        },
        ThrottlerOptions<String>(
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
      throttler = Throttler<String>(
        (args) {
          executedArgs.add(args);
        },
        ThrottlerOptions<String>(
          enabled: false,
          wait: Duration(milliseconds: 100),
        ),
      );

      expect(throttler.options.enabled, false);
      expect(throttler.state.status, PacerStatus.disabled);
    });

    test('disabled throttler ignores maybeExecute calls', () {
      throttler = Throttler<String>(
        (args) {
          executedArgs.add(args);
        },
        ThrottlerOptions<String>(
          enabled: false,
          wait: Duration(milliseconds: 100),
        ),
      );

      throttler.maybeExecute('test');
      expect(executedArgs, isEmpty);
      expect(throttler.state.maybeExecuteCount, 0);
    });

    test('disabled throttler ignores maybeExecute calls', () {
      throttler = Throttler<String>(
        (args) {
          executedArgs.add(args);
        },
        ThrottlerOptions<String>(
          enabled: false,
          wait: Duration(milliseconds: 100),
        ),
      );

      throttler.maybeExecute('test');
      expect(executedArgs, isEmpty);
      expect(throttler.state.maybeExecuteCount, 0);
    });
  });
}