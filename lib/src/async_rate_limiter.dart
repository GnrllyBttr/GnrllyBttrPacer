import 'dart:async';
import 'package:flutter/foundation.dart';
import 'common.dart';
import 'rate_limiter.dart';

class AsyncRateLimiterOptions extends PacerOptions {
  final int limit;
  final Duration window;
  final WindowType windowType;
  final void Function(List<dynamic> args)? onExecute;
  final void Function(List<dynamic> args)? onReject;
  final void Function(dynamic result)? onSuccess;
  final void Function(dynamic error)? onError;
  final void Function(dynamic result, dynamic error)? onSettled;
  final bool throwOnError;

  AsyncRateLimiterOptions({
    super.enabled = true,
    super.key,
    required this.limit,
    required this.window,
    this.windowType = WindowType.fixed,
    this.onExecute,
    this.onReject,
    this.onSuccess,
    this.onError,
    this.onSettled,
    this.throwOnError = false,
  });
}

class AsyncRateLimiterState extends PacerState {
  final int maybeExecuteCount;
  final int rejectionCount;
  final List<DateTime> executionTimes;
  final bool isExceeded;
  final int errorCount;
  final int successCount;
  final int settleCount;
  final bool isExecuting;
  final dynamic lastResult;

  AsyncRateLimiterState({
    super.executionCount = 0,
    super.status = PacerStatus.idle,
    this.maybeExecuteCount = 0,
    this.rejectionCount = 0,
    this.executionTimes = const [],
    this.isExceeded = false,
    this.errorCount = 0,
    this.successCount = 0,
    this.settleCount = 0,
    this.isExecuting = false,
    this.lastResult,
  });

  AsyncRateLimiterState copyWith({
    int? executionCount,
    PacerStatus? status,
    int? maybeExecuteCount,
    int? rejectionCount,
    List<DateTime>? executionTimes,
    bool? isExceeded,
    int? errorCount,
    int? successCount,
    int? settleCount,
    bool? isExecuting,
    dynamic lastResult,
  }) {
    return AsyncRateLimiterState(
      executionCount: executionCount ?? this.executionCount,
      status: status ?? this.status,
      maybeExecuteCount: maybeExecuteCount ?? this.maybeExecuteCount,
      rejectionCount: rejectionCount ?? this.rejectionCount,
      executionTimes: executionTimes ?? this.executionTimes,
      isExceeded: isExceeded ?? this.isExceeded,
      errorCount: errorCount ?? this.errorCount,
      successCount: successCount ?? this.successCount,
      settleCount: settleCount ?? this.settleCount,
      isExecuting: isExecuting ?? this.isExecuting,
      lastResult: lastResult ?? this.lastResult,
    );
  }
}

class AsyncRateLimiter<T> extends ChangeNotifier {
  final AnyAsyncFunction fn;
  AsyncRateLimiterOptions _options;
  AsyncRateLimiterState _state;
  bool _aborted = false;

  AsyncRateLimiter(this.fn, AsyncRateLimiterOptions options)
      : _options = options,
        _state = AsyncRateLimiterState() {
    if (!_options.enabled) {
      _state = _state.copyWith(status: PacerStatus.disabled);
    }
  }

  AsyncRateLimiterOptions get options => _options;
  AsyncRateLimiterState get state => _state;

  Future maybeExecute(List<dynamic> args) async {
    if (!_options.enabled) {
      throw Exception('RateLimiter is disabled');
    }

    final now = DateTime.now();
    final windowStart = _options.windowType == WindowType.fixed
        ? now.subtract(_options.window)
        : _state.executionTimes.isNotEmpty
            ? _state.executionTimes.last.subtract(_options.window)
            : now.subtract(_options.window);

    final validExecutions = _state.executionTimes.where((t) => t.isAfter(windowStart)).toList();

    _state = _state.copyWith(
      maybeExecuteCount: _state.maybeExecuteCount + 1,
      executionTimes: validExecutions,
    );

    if (validExecutions.length < _options.limit) {
      return _executeAsync(args, now);
    } else {
      _reject(args);
      return Future.value(null);
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
          executionTimes: [..._state.executionTimes, executionTime],
          isExecuting: false,
          isExceeded: false,
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
          rethrow;
        } else {
          return null;
        }
      } else {
        throw Exception('Aborted');
      }
    } finally {
      _options.onSettled?.call(_state.lastResult, null);
      notifyListeners();
    }
  }

  void _reject(List<dynamic> args) {
    _options.onReject?.call(args);
    _state = _state.copyWith(
      rejectionCount: _state.rejectionCount + 1,
      isExceeded: true,
    );
    notifyListeners();
  }

  int getRemainingInWindow() {
    final now = DateTime.now();
    final windowStart = now.subtract(_options.window);

    final validExecutions = _state.executionTimes.where((t) => t.isAfter(windowStart)).length;
    return _options.limit - validExecutions;
  }

  Duration getMsUntilNextWindow() {
    if (_state.executionTimes.isEmpty) return Duration.zero;

    final now = DateTime.now();
    final nextWindow = _state.executionTimes.last.add(_options.window);
    return nextWindow.difference(now);
  }

  void reset() {
    _state = _state.copyWith(
      executionTimes: [],
      isExceeded: false,
      status: PacerStatus.idle,
    );
    notifyListeners();
  }

  void abort() {
    _aborted = true;
    _state = _state.copyWith(status: PacerStatus.idle);
    notifyListeners();
  }

  void setOptions(AsyncRateLimiterOptions options) {
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