import 'dart:async';
import 'package:flutter/foundation.dart';
import 'common.dart';

class DebouncerOptions extends PacerOptions {
  final Duration wait;
  final bool leading;
  final bool trailing;
  final void Function(List<dynamic> args)? onExecute;

  DebouncerOptions({
    super.enabled = true,
    super.key,
    required this.wait,
    this.leading = false,
    this.trailing = true,
    this.onExecute,
  });
}

class DebouncerState extends PacerState {
  final int maybeExecuteCount;
  final List<dynamic>? lastArgs;
  final bool isPending;

  DebouncerState({
    super.executionCount = 0,
    super.status = PacerStatus.idle,
    this.maybeExecuteCount = 0,
    this.lastArgs,
    this.isPending = false,
  });

  DebouncerState copyWith({
    int? executionCount,
    PacerStatus? status,
    int? maybeExecuteCount,
    List<dynamic>? lastArgs,
    bool? isPending,
  }) {
    return DebouncerState(
      executionCount: executionCount ?? this.executionCount,
      status: status ?? this.status,
      maybeExecuteCount: maybeExecuteCount ?? this.maybeExecuteCount,
      lastArgs: lastArgs ?? this.lastArgs,
      isPending: isPending ?? this.isPending,
    );
  }
}

class Debouncer extends ChangeNotifier {
  final AnyFunction fn;
  DebouncerOptions _options;
  DebouncerState _state;
  Timer? _timer;
  bool _leadingExecuted = false;

  Debouncer(this.fn, DebouncerOptions options)
      : _options = options,
        _state = DebouncerState() {
    if (!_options.enabled) {
      _state = _state.copyWith(status: PacerStatus.disabled);
    }
  }

  DebouncerOptions get options => _options;
  DebouncerState get state => _state;

  void maybeExecute(List<dynamic> args) {
    if (!_options.enabled) return;

    _state = _state.copyWith(
      maybeExecuteCount: _state.maybeExecuteCount + 1,
      lastArgs: args,
      isPending: true,
      status: PacerStatus.pending,
    );
    notifyListeners();

    _timer?.cancel();

    if (_options.leading && !_leadingExecuted) {
      _execute(args);
      _leadingExecuted = true;
    } else {
      _timer = Timer(_options.wait, () {
        if (_options.trailing) {
          _execute(args);
        }
        _state = _state.copyWith(isPending: false, status: PacerStatus.idle);
        _leadingExecuted = false;
        notifyListeners();
      });
    }
  }

  void _execute(List<dynamic> args) {
    try {
      fn(args);
      _options.onExecute?.call(args);
      _state = _state.copyWith(executionCount: _state.executionCount + 1);
    } catch (e) {
      // Handle error if needed
    }
  }

  void cancel() {
    _timer?.cancel();
    _state = _state.copyWith(isPending: false, status: PacerStatus.idle);
    _leadingExecuted = false;
    notifyListeners();
  }

  void flush() {
    if (_state.isPending && _options.trailing) {
      _timer?.cancel();
      _execute(_state.lastArgs!);
      _state = _state.copyWith(isPending: false, status: PacerStatus.idle);
      _leadingExecuted = false;
      notifyListeners();
    }
  }

  void setOptions(DebouncerOptions options) {
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