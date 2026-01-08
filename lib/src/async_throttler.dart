import 'dart:async';
import 'package:flutter/foundation.dart';
import 'common.dart';

class AsyncThrottlerOptions extends PacerOptions {
  final Duration wait;
  final bool leading;
  final bool trailing;
  final void Function(List<dynamic> args)? onExecute;
  final void Function(dynamic result)? onSuccess;
  final void Function(dynamic error)? onError;
  final void Function(dynamic result, dynamic error)? onSettled;
  final bool throwOnError;

  AsyncThrottlerOptions({
    super.enabled = true,
    super.key,
    required this.wait,
    this.leading = true,
    this.trailing = true,
    this.onExecute,
    this.onSuccess,
    this.onError,
    this.onSettled,
    this.throwOnError = false,
  });
}

class AsyncThrottlerState extends PacerState {
  final int maybeExecuteCount;
  final List<dynamic>? lastArgs;
  final DateTime? lastExecutionTime;
  final DateTime? nextExecutionTime;
  final int errorCount;
  final int successCount;
  final int settleCount;
  final bool isExecuting;
  final dynamic lastResult;

  AsyncThrottlerState({
    super.executionCount = 0,
    super.status = PacerStatus.idle,
    this.maybeExecuteCount = 0,
    this.lastArgs,
    this.lastExecutionTime,
    this.nextExecutionTime,
    this.errorCount = 0,
    this.successCount = 0,
    this.settleCount = 0,
    this.isExecuting = false,
    this.lastResult,
  });

  AsyncThrottlerState copyWith({
    int? executionCount,
    PacerStatus? status,
    int? maybeExecuteCount,
    List<dynamic>? lastArgs,
    DateTime? lastExecutionTime,
    DateTime? nextExecutionTime,
    int? errorCount,
    int? successCount,
    int? settleCount,
    bool? isExecuting,
    dynamic lastResult,
  }) {
    return AsyncThrottlerState(
      executionCount: executionCount ?? this.executionCount,
      status: status ?? this.status,
      maybeExecuteCount: maybeExecuteCount ?? this.maybeExecuteCount,
      lastArgs: lastArgs ?? this.lastArgs,
      lastExecutionTime: lastExecutionTime ?? this.lastExecutionTime,
      nextExecutionTime: nextExecutionTime ?? this.nextExecutionTime,
      errorCount: errorCount ?? this.errorCount,
      successCount: successCount ?? this.successCount,
      settleCount: settleCount ?? this.settleCount,
      isExecuting: isExecuting ?? this.isExecuting,
      lastResult: lastResult ?? this.lastResult,
    );
  }
}

class AsyncThrottler<T> extends ChangeNotifier {
  final AnyAsyncFunction fn;
  AsyncThrottlerOptions _options;
  AsyncThrottlerState _state;
  Timer? _timer;
  Completer? _completer;
  bool _aborted = false;

  AsyncThrottler(this.fn, AsyncThrottlerOptions options)
      : _options = options,
        _state = AsyncThrottlerState() {
    if (!_options.enabled) {
      _state = _state.copyWith(status: PacerStatus.disabled);
    }
  }

  AsyncThrottlerOptions get options => _options;
  AsyncThrottlerState get state => _state;

  Future maybeExecute(List<dynamic> args) {
    if (!_options.enabled) {
      throw Exception('Throttler is disabled');
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
      _executeAsync(args, now);
      return _completer!.future;
    } else if (_options.trailing) {
      final remaining = _options.wait - timeSinceLast;
      _state = _state.copyWith(nextExecutionTime: now.add(remaining));
      _completer = Completer();
      _timer?.cancel();
      _timer = Timer(remaining, () => _executeAsync(args, DateTime.now()).then((result) {
        if (!_completer!.isCompleted) _completer!.complete(result);
      }).catchError((e) {
        if (!_completer!.isCompleted) _completer!.completeError(e);
      }));
      return _completer!.future;
    } else {
      throw Exception('Cannot execute now');
    }
  }

  Future _executeAsync(List<dynamic> args, DateTime executionTime) async {
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
          lastExecutionTime: executionTime,
          nextExecutionTime: null,
          isExecuting: false,
        );
        return result;
      } else {
        throw Exception('Aborted');
      }
    } catch (e) {
      if (!_aborted) {
        _options.onError?.call(e);
        _state = _state.copyWith(
          errorCount: _state.errorCount + 1,
          settleCount: _state.settleCount + 1,
          isExecuting: false,
        );
        if (_options.throwOnError) {
          _completer!.completeError(e);
        } else {
          _completer!.complete(null);
        }
      } else {
        throw Exception('Aborted');
      }
    } finally {
      _options.onSettled?.call(_state.lastResult, null);
      notifyListeners();
    }
  }

  void abort() {
    _aborted = true;
    _timer?.cancel();
    _state = _state.copyWith(nextExecutionTime: null);
    if (_completer != null && !_completer!.isCompleted) {
      _completer!.completeError('Aborted');
    }
    notifyListeners();
  }

  void cancel() {
    abort();
  }

  void flush() {
    if (_state.nextExecutionTime != null) {
      _timer?.cancel();
      _executeAsync(_state.lastArgs!, DateTime.now()).then((result) {
        if (_completer != null && !_completer!.isCompleted) {
          _completer!.complete(result);
        }
      }).catchError((e) {
        if (_completer != null && !_completer!.isCompleted) {
          _completer!.completeError(e);
        }
      });
    }
  }

  void setOptions(AsyncThrottlerOptions options) {
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