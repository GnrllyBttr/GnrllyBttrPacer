import 'package:flutter/foundation.dart';
import 'common.dart';

enum WindowType { fixed, sliding }

class RateLimiterOptions extends PacerOptions {
  final int limit;
  final Duration window;
  final WindowType windowType;
  final void Function(List<dynamic> args)? onExecute;
  final void Function(List<dynamic> args)? onReject;

  RateLimiterOptions({
    super.enabled = true,
    super.key,
    required this.limit,
    required this.window,
    this.windowType = WindowType.fixed,
    this.onExecute,
    this.onReject,
  });
}

class RateLimiterState extends PacerState {
  final int maybeExecuteCount;
  final int rejectionCount;
  final List<DateTime> executionTimes;
  final bool isExceeded;

  RateLimiterState({
    super.executionCount = 0,
    super.status = PacerStatus.idle,
    this.maybeExecuteCount = 0,
    this.rejectionCount = 0,
    this.executionTimes = const [],
    this.isExceeded = false,
  });

  RateLimiterState copyWith({
    int? executionCount,
    PacerStatus? status,
    int? maybeExecuteCount,
    int? rejectionCount,
    List<DateTime>? executionTimes,
    bool? isExceeded,
  }) {
    return RateLimiterState(
      executionCount: executionCount ?? this.executionCount,
      status: status ?? this.status,
      maybeExecuteCount: maybeExecuteCount ?? this.maybeExecuteCount,
      rejectionCount: rejectionCount ?? this.rejectionCount,
      executionTimes: executionTimes ?? this.executionTimes,
      isExceeded: isExceeded ?? this.isExceeded,
    );
  }
}

class RateLimiter extends ChangeNotifier {
  final AnyFunction fn;
  RateLimiterOptions _options;
  RateLimiterState _state;


  RateLimiter(this.fn, RateLimiterOptions options)
      : _options = options,
        _state = RateLimiterState() {
    if (!_options.enabled) {
      _state = _state.copyWith(status: PacerStatus.disabled);
    }
  }

  RateLimiterOptions get options => _options;
  RateLimiterState get state => _state;

  bool maybeExecute(List<dynamic> args) {
    if (!_options.enabled) return false;

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
      _execute(args, now);
      return true;
    } else {
      _reject(args);
      return false;
    }
  }

  void _execute(List<dynamic> args, DateTime executionTime) {
    try {
      fn(args);
      _options.onExecute?.call(args);
      _state = _state.copyWith(
        executionCount: _state.executionCount + 1,
        executionTimes: [..._state.executionTimes, executionTime],
        isExceeded: false,
      );
    } catch (e) {
      // Handle error if needed
    }
    notifyListeners();
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

  void setOptions(RateLimiterOptions options) {
    _options = options;
    if (!_options.enabled) {
      _state = _state.copyWith(status: PacerStatus.disabled);
    } else {
      _state = _state.copyWith(status: PacerStatus.idle);
    }
    notifyListeners();
  }
}