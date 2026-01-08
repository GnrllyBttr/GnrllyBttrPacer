import 'dart:async';
import 'package:flutter/foundation.dart';
import 'common.dart';

class ThrottlerOptions extends PacerOptions {
  final Duration wait;
  final bool leading;
  final bool trailing;
  final void Function(List<dynamic> args)? onExecute;

  ThrottlerOptions({
    super.enabled = true,
    super.key,
    required this.wait,
    this.leading = true,
    this.trailing = true,
    this.onExecute,
  });
}

class ThrottlerState extends PacerState {
  final int maybeExecuteCount;
  final List<dynamic>? lastArgs;
  final DateTime? lastExecutionTime;
  final DateTime? nextExecutionTime;

  ThrottlerState({
    super.executionCount = 0,
    super.status = PacerStatus.idle,
    this.maybeExecuteCount = 0,
    this.lastArgs,
    this.lastExecutionTime,
    this.nextExecutionTime,
  });

  ThrottlerState copyWith({
    int? executionCount,
    PacerStatus? status,
    int? maybeExecuteCount,
    List<dynamic>? lastArgs,
    DateTime? lastExecutionTime,
    DateTime? nextExecutionTime,
  }) {
    return ThrottlerState(
      executionCount: executionCount ?? this.executionCount,
      status: status ?? this.status,
      maybeExecuteCount: maybeExecuteCount ?? this.maybeExecuteCount,
      lastArgs: lastArgs ?? this.lastArgs,
      lastExecutionTime: lastExecutionTime ?? this.lastExecutionTime,
      nextExecutionTime: nextExecutionTime ?? this.nextExecutionTime,
    );
  }
}

class Throttler extends ChangeNotifier {
  final AnyFunction fn;
  ThrottlerOptions _options;
  ThrottlerState _state;
  Timer? _timer;

  Throttler(this.fn, ThrottlerOptions options)
      : _options = options,
        _state = ThrottlerState() {
    if (!_options.enabled) {
      _state = _state.copyWith(status: PacerStatus.disabled);
    }
  }

  ThrottlerOptions get options => _options;
  ThrottlerState get state => _state;

  void maybeExecute(List<dynamic> args) {
    if (!_options.enabled) return;

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

  void _execute(List<dynamic> args, DateTime executionTime) {
    try {
      fn(args);
      _options.onExecute?.call(args);
      _state = _state.copyWith(
        executionCount: _state.executionCount + 1,
        lastExecutionTime: executionTime,
        nextExecutionTime: null,
      );
    } catch (e) {
      // Handle error if needed
    }
    notifyListeners();
  }

  void cancel() {
    _timer?.cancel();
    _state = _state.copyWith(nextExecutionTime: null);
    notifyListeners();
  }

  void flush() {
    if (_state.nextExecutionTime != null) {
      _timer?.cancel();
      _execute(_state.lastArgs!, DateTime.now());
    }
  }

  void setOptions(ThrottlerOptions options) {
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