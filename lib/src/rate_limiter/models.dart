import 'package:gnrllybttr_pacer/src/common/common.dart';

/// Configuration options for [AsyncRateLimiter].
///
/// Defines rate limiting behavior including the maximum number of executions
/// allowed within a time window, window type (fixed or sliding), and event callbacks.
///
/// Example:
/// ```dart
/// final options = AsyncRateLimiterOptions<String>(
///   limit: 10,
///   window: Duration(seconds: 60),
///   windowType: WindowType.fixed,
///   onReject: (value) => print('Rate limit exceeded for: $value'),
///   onSuccess: (result) => print('Success: $result'),
/// );
/// ```
class AsyncRateLimiterOptions<T> extends PacerOptions {
  const AsyncRateLimiterOptions({
    required this.limit,
    required this.window,
    super.enabled = true,
    super.key,
    this.windowType = WindowType.fixed,
    this.onExecute,
    this.onReject,
    this.onSuccess,
    this.onError,
    this.onSettled,
    this.throwOnError = false,
  });

  /// Maximum number of executions allowed within the time window.
  final int limit;

  /// Duration of the time window for rate limiting.
  final Duration window;

  /// Type of time window to use for rate limiting.
  ///
  /// - [WindowType.fixed]: Window resets at fixed intervals from a reference point
  /// - [WindowType.sliding]: Window slides with each execution, using the time
  ///   of the most recent execution as the reference
  final WindowType windowType;

  /// Callback invoked when a rate-limited function executes successfully.
  ///
  /// Receives the arguments passed to the execution.
  final void Function(T args)? onExecute;

  /// Callback invoked when execution is rejected due to rate limit.
  ///
  /// Receives the arguments that were rejected.
  final void Function(T args)? onReject;

  /// Callback invoked when execution completes successfully.
  ///
  /// Receives the result returned by the function.
  final void Function(dynamic result)? onSuccess;

  /// Callback invoked when execution encounters an error.
  ///
  /// Receives the error object.
  final void Function(dynamic error)? onError;

  /// Callback invoked after execution completes, regardless of success or failure.
  ///
  /// Receives the result (if successful) and error (if failed).
  final void Function(dynamic result, dynamic error)? onSettled;

  /// Whether to rethrow errors after invoking [onError].
  ///
  /// If true, errors will propagate to callers of [maybeExecute].
  /// If false, errors are caught and the future completes with null.
  final bool throwOnError;
}

/// State information for [AsyncRateLimiter].
///
/// Tracks rate limiting statistics, execution history, and current limit status.
///
/// Example usage:
/// ```dart
/// final limiter = AsyncRateLimiter<String>(
///   (value) async => apiCall(value),
///   AsyncRateLimiterOptions<String>(
///     limit: 5,
///     window: Duration(seconds: 10),
///   ),
/// );
///
/// print(limiter.state.executionCount); // Successful executions
/// print(limiter.state.rejectionCount); // Rejected attempts
/// print(limiter.state.isExceeded); // Currently at limit?
/// print(limiter.state.executionTimes); // History of execution times
/// ```
class AsyncRateLimiterState<T> extends PacerState {
  const AsyncRateLimiterState({
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

  /// Total number of times [maybeExecute] has been called.
  final int maybeExecuteCount;

  /// Total number of execution attempts that were rejected due to rate limit.
  final int rejectionCount;

  /// Timestamps of recent executions within the current window.
  final List<DateTime> executionTimes;

  /// Whether the rate limit is currently exceeded.
  final bool isExceeded;

  /// Total number of executions that resulted in errors.
  final int errorCount;

  /// Total number of executions that completed successfully.
  final int successCount;

  /// Total number of executions that have settled (success or error).
  final int settleCount;

  /// Whether an execution is currently in progress.
  final bool isExecuting;

  /// The result from the most recent successful execution.
  final dynamic lastResult;

  /// Creates a copy of this state with the given fields replaced with new values.
  ///
  /// All parameters are optional. Fields not provided will retain their current values.
  AsyncRateLimiterState<T> copyWith({
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

/// Configuration options for [RateLimiter].
///
/// Controls rate limiting behavior including limits, window type, and callbacks.
/// This is the synchronous version of [AsyncRateLimiterOptions].
///
/// Example:
/// ```dart
/// final options = RateLimiterOptions<Map<String, dynamic>>(
///   limit: 100,                          // 100 requests
///   window: Duration(seconds: 60),       // per minute
///   windowType: WindowType.sliding,      // sliding window
///   onReject: (params) => print('Rejected: $params'),
/// );
/// ```
class RateLimiterOptions<T> extends PacerOptions {
  /// Creates rate limiter options.
  ///
  /// The [limit] specifies maximum executions allowed within the [window] duration.
  /// [windowType] determines whether to use fixed or sliding windows.
  const RateLimiterOptions({
    required this.limit,
    required this.window,
    super.enabled = true,
    super.key,
    this.windowType = WindowType.fixed,
    this.onExecute,
    this.onReject,
  });

  /// Maximum number of executions allowed within the time window.
  final int limit;

  /// Duration of the time window for rate limiting.
  final Duration window;

  /// Type of window to use (fixed or sliding).
  final WindowType windowType;

  /// Optional callback invoked before each successful execution.
  final void Function(T args)? onExecute;

  /// Optional callback invoked when execution is rejected due to rate limit.
  final void Function(T args)? onReject;
}

/// State information for [RateLimiter].
///
/// Tracks rate limiting statistics and execution history. This is the synchronous
/// version of [AsyncRateLimiterState].
///
/// Example usage:
/// ```dart
/// final rateLimiter = RateLimiter<void>(
///   () => print('Executed'),
///   RateLimiterOptions<void>(limit: 5, window: Duration(minutes: 1)),
/// );
///
/// rateLimiter.maybeExecute(null);
/// print(rateLimiter.state.executionCount);    // Successful executions
/// print(rateLimiter.state.rejectionCount);    // Rejected attempts
/// print(rateLimiter.state.isExceeded);        // Is limit exceeded?
/// print(rateLimiter.state.executionTimes);    // When executions occurred
/// ```
class RateLimiterState<T> extends PacerState {
  /// Creates rate limiter state.
  ///
  /// Tracks various rate limiting metrics and current status.
  const RateLimiterState({
    super.executionCount = 0,
    super.status = PacerStatus.idle,
    this.maybeExecuteCount = 0,
    this.rejectionCount = 0,
    this.executionTimes = const [],
    this.isExceeded = false,
  });

  /// Total number of times [maybeExecute] has been called.
  final int maybeExecuteCount;

  /// Number of executions rejected due to rate limit.
  final int rejectionCount;

  /// Timestamps of all recent executions within the current window.
  final List<DateTime> executionTimes;

  /// Whether the rate limit is currently exceeded.
  final bool isExceeded;

  /// Creates a copy of this state with the given fields replaced with new values.
  RateLimiterState<T> copyWith({
    int? executionCount,
    PacerStatus? status,
    int? maybeExecuteCount,
    int? rejectionCount,
    List<DateTime>? executionTimes,
    bool? isExceeded,
  }) {
    return RateLimiterState<T>(
      executionCount: executionCount ?? this.executionCount,
      status: status ?? this.status,
      maybeExecuteCount: maybeExecuteCount ?? this.maybeExecuteCount,
      rejectionCount: rejectionCount ?? this.rejectionCount,
      executionTimes: executionTimes ?? this.executionTimes,
      isExceeded: isExceeded ?? this.isExceeded,
    );
  }
}
