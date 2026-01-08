import 'dart:async';
import 'package:flutter/foundation.dart';
import 'common.dart';

enum BackoffType { exponential, linear, fixed }

class AsyncRetryerOptions extends PacerOptions {
  final int maxAttempts;
  final BackoffType backoff;
  final Duration baseWait;
  final double? jitter;
  final Duration? maxExecutionTime;
  final Duration? maxTotalExecutionTime;
  final void Function(int attempt, dynamic error)? onRetry;
  final void Function(dynamic result)? onSuccess;
  final void Function(dynamic error)? onError;
  final void Function()? onAbort;
  final bool throwOnError;

  AsyncRetryerOptions({
    super.enabled = true,
    super.key,
    this.maxAttempts = 3,
    this.backoff = BackoffType.exponential,
    this.baseWait = const Duration(milliseconds: 100),
    this.jitter,
    this.maxExecutionTime,
    this.maxTotalExecutionTime,
    this.onRetry,
    this.onSuccess,
    this.onError,
    this.onAbort,
    this.throwOnError = true,
  });
}

class AsyncRetryerState extends PacerState {
  final int currentAttempt;
  final int errorCount;
  final int successCount;
  final int settleCount;
  final bool isExecuting;
  final DateTime? lastExecutionTime;
  final Duration? totalExecutionTime;
  final dynamic lastError;
  final dynamic lastResult;

  AsyncRetryerState({
    super.executionCount = 0,
    super.status = PacerStatus.idle,
    this.currentAttempt = 0,
    this.errorCount = 0,
    this.successCount = 0,
    this.settleCount = 0,
    this.isExecuting = false,
    this.lastExecutionTime,
    this.totalExecutionTime,
    this.lastError,
    this.lastResult,
  });

  AsyncRetryerState copyWith({
    int? executionCount,
    PacerStatus? status,
    int? currentAttempt,
    int? errorCount,
    int? successCount,
    int? settleCount,
    bool? isExecuting,
    DateTime? lastExecutionTime,
    Duration? totalExecutionTime,
    dynamic lastError,
    dynamic lastResult,
  }) {
    return AsyncRetryerState(
      executionCount: executionCount ?? this.executionCount,
      status: status ?? this.status,
      currentAttempt: currentAttempt ?? this.currentAttempt,
      errorCount: errorCount ?? this.errorCount,
      successCount: successCount ?? this.successCount,
      settleCount: settleCount ?? this.settleCount,
      isExecuting: isExecuting ?? this.isExecuting,
      lastExecutionTime: lastExecutionTime ?? this.lastExecutionTime,
      totalExecutionTime: totalExecutionTime ?? this.totalExecutionTime,
      lastError: lastError ?? this.lastError,
      lastResult: lastResult ?? this.lastResult,
    );
  }
}

class AsyncRetryer<T> extends ChangeNotifier {
  final AnyAsyncFunction fn;
  AsyncRetryerOptions _options;
  AsyncRetryerState _state;
  Timer? _retryTimer;
  Completer<T>? _completer;
  bool _aborted = false;
  DateTime? _startTime;

  AsyncRetryer(this.fn, AsyncRetryerOptions options)
      : _options = options,
        _state = AsyncRetryerState() {
    if (!_options.enabled) {
      _state = _state.copyWith(status: PacerStatus.disabled);
    }
  }

  AsyncRetryerOptions get options => _options;
  AsyncRetryerState get state => _state;

  Future<T> execute(List<dynamic> args) async {
    if (!_options.enabled) {
      throw Exception('Retryer is disabled');
    }

    _completer = Completer<T>();
    _aborted = false;
    _startTime = DateTime.now();
    _state = _state.copyWith(
      currentAttempt: 0,
      status: PacerStatus.executing,
      totalExecutionTime: Duration.zero,
    );
    notifyListeners();

    await _attempt(args, 1);
    return _completer!.future;
  }

  Future<void> _attempt(List<dynamic> args, int attempt) async {
    if (_aborted) return;

    final attemptStart = DateTime.now();
    _state = _state.copyWith(currentAttempt: attempt);
    notifyListeners();

    try {
      final result = await fn(args);
      if (!_aborted) {
        _options.onSuccess?.call(result);
        _state = _state.copyWith(
          executionCount: _state.executionCount + 1,
          successCount: _state.successCount + 1,
          lastResult: result,
          lastExecutionTime: attemptStart,
          totalExecutionTime: DateTime.now().difference(_startTime!),
          status: PacerStatus.idle,
        );
        _completer!.complete(result);
      }
    } catch (e) {
      if (_aborted) return;

      _options.onError?.call(e);
        _state = _state.copyWith(
          errorCount: _state.errorCount + 1,
          settleCount: _state.settleCount + 1,
          isExecuting: false,
        );
        if (_options.throwOnError) {
          rethrow;
        } else {
          _completer!.complete(null);
        }
      notifyListeners();
    }
  }



  void abort() {
    _aborted = true;
    _retryTimer?.cancel();
    _options.onAbort?.call();
    _state = _state.copyWith(status: PacerStatus.idle);
    if (_completer != null && !_completer!.isCompleted) {
      _completer!.completeError('Aborted');
    }
    notifyListeners();
  }

  void setOptions(AsyncRetryerOptions options) {
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