// 🎯 Dart imports:
import 'dart:async';

// 🐦 Flutter imports:
import 'package:flutter/foundation.dart';

// 🌎 Project imports:
import 'package:gnrllybttr_pacer/src/common/common.dart';
import 'package:gnrllybttr_pacer/src/throttler/models.dart';

class Throttler<T> extends ChangeNotifier {
  Throttler(this.fn, ThrottlerOptions<T> options)
      : _options = options,
        _state = ThrottlerState<T>() {
    if (!_options.enabled) {
      _state = _state.copyWith(status: PacerStatus.disabled);
    }
  }

  final AnyFunction fn;
  ThrottlerOptions<T> _options;
  ThrottlerState<T> _state;
  Timer? _timer;

  ThrottlerOptions<T> get options => _options;
  ThrottlerState<T> get state => _state;

  void maybeExecute(T args) {
    if (!_options.enabled) {
      return;
    }

    final now = DateTime.now();
    final timeSinceLast = _state.lastExecutionTime != null
        ? now.difference(_state.lastExecutionTime!)
        : _options.wait;

    _state = _state.copyWith(
      maybeExecuteCount: _state.maybeExecuteCount + 1,
      lastArgs: args,
    );
    notifyListeners();

    if (timeSinceLast >= _options.wait) {
      _execute(args, now);
    } else if (_options.trailing) {
      final remaining = _options.wait - timeSinceLast;
      _state = _state.copyWith(nextExecutionTime: now.add(remaining));
      _timer?.cancel();
      _timer = Timer(remaining, () => _execute(args, DateTime.now()));
    }
  }

  void _execute(T args, DateTime executionTime) {
    _options.onExecute?.call(args);
    notifyListeners();
  }

  void cancel() {
    _timer?.cancel();
    _state = _state.copyWith();
    notifyListeners();
  }

  void flush() {
    if (_state.nextExecutionTime != null && _state.lastArgs != null) {
      _timer?.cancel();
      _execute(_state.lastArgs as T, DateTime.now());
    }
  }

  void setOptions(ThrottlerOptions<T> options) {
    _options = options;
    if (!_options.enabled) {
      cancel();
      _state = _state.copyWith(status: PacerStatus.disabled);
    } else {
      _state = _state.copyWith(status: PacerStatus.idle);
    }
    notifyListeners();
  }
}
