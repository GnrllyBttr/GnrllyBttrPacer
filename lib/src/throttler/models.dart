import 'package:gnrllybttr_pacer/src/common/common.dart';

/// Configuration options for [AsyncThrottler].
///
/// Defines throttling behavior including timing, execution triggers (leading/trailing),
/// and event callbacks.
///
/// Example:
/// ```dart
/// final options = AsyncThrottlerOptions<String>(
///   wait: Duration(seconds: 1),
///   leading: true,
///   trailing: true,
///   onExecute: (value) => print('Executing with: $value'),
///   onSuccess: (result) => print('Success: $result'),
/// );
/// ```
class AsyncThrottlerOptions<T> extends PacerOptions {
  const AsyncThrottlerOptions({
    required this.wait,
    super.enabled = true,
    super.key,
    this.leading = true,
    this.trailing = true,
    this.onExecute,
    this.onSuccess,
    this.onError,
    this.onSettled,
    this.throwOnError = false,
  });

  /// Minimum duration to wait between executions.
  ///
  /// Once executed, subsequent calls within this duration will be throttled.
  final Duration wait;

  /// Whether to execute on the leading edge of the wait period.
  ///
  /// If true, executes immediately on the first call, then throttles for the wait duration.
  final bool leading;

  /// Whether to execute on the trailing edge of the wait period.
  ///
  /// If true, executes with the most recent arguments after the wait period.
  final bool trailing;

  /// Callback invoked when the throttled function executes.
  ///
  /// Receives the arguments passed to the execution.
  final void Function(T args)? onExecute;

  /// Callback invoked when execution completes successfully.
  ///
  /// Receives the result returned by the throttled function.
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

/// State information for [AsyncThrottler].
///
/// Tracks throttling statistics, execution timing, and status.
///
/// Example usage:
/// ```dart
/// final throttler = AsyncThrottler<int>(
///   (value) async => processValue(value),
///   AsyncThrottlerOptions<int>(wait: Duration(seconds: 1)),
/// );
///
/// print(throttler.state.maybeExecuteCount); // Total calls to maybeExecute
/// print(throttler.state.executionCount); // Actual executions
/// print(throttler.state.lastExecutionTime); // When last executed
/// print(throttler.state.nextExecutionTime); // When next execution allowed
/// ```
class AsyncThrottlerState<T> extends PacerState {
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

  /// Total number of times [maybeExecute] has been called.
  final int maybeExecuteCount;

  /// The most recent arguments passed to [maybeExecute].
  final T? lastArgs;

  /// The timestamp of the most recent execution.
  final DateTime? lastExecutionTime;

  /// The timestamp when the next execution is scheduled (for trailing execution).
  final DateTime? nextExecutionTime;

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
  AsyncThrottlerState<T> copyWith({
    int? executionCount,
    PacerStatus? status,
    int? maybeExecuteCount,
    T? lastArgs,
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

class ThrottlerOptions<T> extends PacerOptions {
  const ThrottlerOptions({
    required this.wait,
    super.enabled = true,
    super.key,
    this.leading = true,
    this.trailing = true,
    this.onExecute,
  });

  final Duration wait;
  final bool leading;
  final bool trailing;
  final void Function(T args)? onExecute;
}

class ThrottlerState<T> extends PacerState {
  ThrottlerState({
    super.executionCount = 0,
    super.status = PacerStatus.idle,
    this.maybeExecuteCount = 0,
    this.lastArgs,
    this.lastExecutionTime,
    this.nextExecutionTime,
  });

  final int maybeExecuteCount;
  final T? lastArgs;
  final DateTime? lastExecutionTime;
  final DateTime? nextExecutionTime;

  ThrottlerState<T> copyWith({
    int? executionCount,
    PacerStatus? status,
    int? maybeExecuteCount,
    T? lastArgs,
    DateTime? lastExecutionTime,
    DateTime? nextExecutionTime,
  }) {
    return ThrottlerState<T>(
      executionCount: executionCount ?? this.executionCount,
      status: status ?? this.status,
      maybeExecuteCount: maybeExecuteCount ?? this.maybeExecuteCount,
      lastArgs: lastArgs ?? this.lastArgs,
      lastExecutionTime: lastExecutionTime ?? this.lastExecutionTime,
      nextExecutionTime: nextExecutionTime ?? this.nextExecutionTime,
    );
  }
}
