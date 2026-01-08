import 'dart:async';
import 'package:flutter/foundation.dart';
import 'common.dart';

class AsyncDebouncerOptions extends PacerOptions {
  final Duration wait;
  final bool leading;
  final bool trailing;
  final void Function(List<dynamic> args)? onExecute;
  final void Function(dynamic result)? onSuccess;
  final void Function(dynamic error)? onError;
  final void Function(dynamic result, dynamic error)? onSettled;
  final bool throwOnError;

  AsyncDebouncerOptions({
    super.enabled = true,
    super.key,
    required this.wait,
    this.leading = false,
    this.trailing = true,
    this.onExecute,
    this.onSuccess,
    this.onError,
    this.onSettled,
    this.throwOnError = false,
  });
}

class AsyncDebouncerState extends PacerState {
  final int maybeExecuteCount;
  final List<dynamic>? lastArgs;
  final bool isPending;
  final int errorCount;
  final int successCount;
  final int settleCount;
  final bool isExecuting;
  final dynamic lastResult;

  AsyncDebouncerState({
    super.executionCount = 0,
    super.status = PacerStatus.idle,
    this.maybeExecuteCount = 0,
    this.lastArgs,
    this.isPending = false,
    this.errorCount = 0,
    this.successCount = 0,
    this.settleCount = 0,
    this.isExecuting = false,
    this.lastResult,
  });

  AsyncDebouncerState copyWith({
    int? executionCount,
    PacerStatus? status,
    int? maybeExecuteCount,
    List<dynamic>? lastArgs,
    bool? isPending,
    int? errorCount,
    int? successCount,
    int? settleCount,
    bool? isExecuting,
    dynamic lastResult,
  }) {
    return AsyncDebouncerState(
      executionCount: executionCount ?? this.executionCount,
      status: status ?? this.status,
      maybeExecuteCount: maybeExecuteCount ?? this.maybeExecuteCount,
      lastArgs: lastArgs ?? this.lastArgs,
      isPending: isPending ?? this.isPending,
      errorCount: errorCount ?? this.errorCount,
      successCount: successCount ?? this.successCount,
      settleCount: settleCount ?? this.settleCount,
      isExecuting: isExecuting ?? this.isExecuting,
      lastResult: lastResult ?? this.lastResult,
    );
  }
}

class AsyncDebouncer<T> extends ChangeNotifier {
  final AnyAsyncFunction fn;
  AsyncDebouncerOptions _options;
  AsyncDebouncerState _state;
  Timer? _timer;
  Completer? _completer;
  bool _leadingExecuted = false;
  bool _aborted = false;

  AsyncDebouncer(this.fn, AsyncDebouncerOptions options)
      : _options = options,
        _state = AsyncDebouncerState() {
    if (!_options.enabled) {
      _state = _state.copyWith(status: PacerStatus.disabled);
    }
  }

  AsyncDebouncerOptions get options => _options;
  AsyncDebouncerState get state => _state;

  Future maybeExecute(List<dynamic> args) {
    if (!_options.enabled) {
      throw Exception('Debouncer is disabled');
    }

    _state = _state.copyWith(
      maybeExecuteCount: _state.maybeExecuteCount + 1,
      lastArgs: args,
      isPending: true,
      status: PacerStatus.pending,
    );
    notifyListeners();

    _timer?.cancel();
    _completer = Completer();
    _aborted = false;

    if (_options.leading && !_leadingExecuted) {
      _executeAsync(args);
      _leadingExecuted = true;
    } else {
      _timer = Timer(_options.wait, () {
        if (_options.trailing && !_aborted) {
          _executeAsync(args);
        } else {
          _state = _state.copyWith(isPending: false, status: PacerStatus.idle);
          _leadingExecuted = false;
          if (!_completer!.isCompleted) {
            _completer!.completeError('Aborted');
          }
          notifyListeners();
        }
      });
    }

    return _completer!.future;
  }

  Future<void> _executeAsync(List<dynamic> args) async {
    _state = _state.copyWith(isExecuting: true, status: PacerStatus.executing);
    notifyListeners();

    try {
      final result = await fn(args);
      if (!_aborted) {
        _options.onExecute?.call(args);
        _options.onSuccess?.call(result);
        _state = _state.copyWith(
          executionCount: _state.executionCount + 1,
          successCount: _state.successCount + 1,
          settleCount: _state.settleCount + 1,
          lastResult: result,
          isExecuting: false,
          isPending: false,
          status: PacerStatus.idle,
        );
        _leadingExecuted = false;
        _completer!.complete(result);
      }
    } catch (e) {
      if (!_aborted) {
        _options.onError?.call(e);
        _state = _state.copyWith(
          errorCount: _state.errorCount + 1,
          settleCount: _state.settleCount + 1,
          isExecuting: false,
          isPending: false,
          status: PacerStatus.idle,
        );
        _leadingExecuted = false;
        if (_options.throwOnError) {
          _completer!.completeError(e);
        } else {
          _completer!.complete(null);
        }
      }
    } finally {
      _options.onSettled?.call(_state.lastResult, null);
      notifyListeners();
    }
  }

  void abort() {
    _aborted = true;
    _timer?.cancel();
    _state = _state.copyWith(isPending: false, status: PacerStatus.idle);
    if (_completer != null && !_completer!.isCompleted) {
      _completer!.completeError('Aborted');
    }
    notifyListeners();
  }

  void cancel() {
    abort();
  }

  void flush() {
    if (_state.isPending && _options.trailing) {
      _timer?.cancel();
      _executeAsync(_state.lastArgs!);
    }
  }

  void setOptions(AsyncDebouncerOptions options) {
    _options = options;
    if (!_options.enabled) {
      abort();
      _state = _state.copyWith(status: PacerStatus.disabled);
    } else {
      _state = _state.copyWith(status: PacerStatus.idle);
    }
    notifyListeners();
  }
}