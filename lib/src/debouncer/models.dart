import 'package:gnrllybttr_pacer/src/common/common.dart';

/// Configuration options for [AsyncDebouncer].
///
/// Defines debouncing behavior including timing, execution triggers (leading/trailing),
/// and event callbacks.
///
/// Example:
/// ```dart
/// final options = AsyncDebouncerOptions<String>(
///   wait: Duration(milliseconds: 500),
///   leading: false,
///   trailing: true,
///   onExecute: (value) => print('Executing with: $value'),
///   onSuccess: (result) => print('Success: $result'),
/// );
/// ```
class AsyncDebouncerOptions<T> extends PacerOptions {
  const AsyncDebouncerOptions({
    required this.wait,
    super.enabled = true,
    super.key,
    this.leading = false,
    this.trailing = true,
    this.onExecute,
    this.onSuccess,
    this.onError,
    this.onSettled,
    this.throwOnError = false,
  });

  /// Duration to wait before executing the debounced function.
  ///
  /// The timer resets each time [maybeExecute] is called.
  final Duration wait;

  /// Whether to execute on the leading edge of the timeout.
  ///
  /// If true, executes immediately on the first call, then waits for the timeout period.
  final bool leading;

  /// Whether to execute on the trailing edge of the timeout.
  ///
  /// If true, executes after the wait period has elapsed since the last call.
  final bool trailing;

  /// Callback invoked when the debounced function executes.
  ///
  /// Receives the arguments passed to the execution.
  final void Function(T args)? onExecute;

  /// Callback invoked when execution completes successfully.
  ///
  /// Receives the result returned by the debounced function.
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

/// State information for [AsyncDebouncer].
///
/// Tracks debouncing statistics, pending state, and execution results.
///
/// Example usage:
/// ```dart
/// final debouncer = AsyncDebouncer<String>(
///   (value) async => processValue(value),
///   AsyncDebouncerOptions<String>(wait: Duration(milliseconds: 300)),
/// );
///
/// print(debouncer.state.isPending); // Is a call pending?
/// print(debouncer.state.maybeExecuteCount); // How many times was maybeExecute called?
/// print(debouncer.state.executionCount); // How many times did it actually execute?
/// ```
class AsyncDebouncerState<T> extends PacerState {
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

  /// Total number of times [maybeExecute] has been called.
  final int maybeExecuteCount;

  /// The most recent arguments passed to [maybeExecute].
  final T? lastArgs;

  /// Whether a debounced execution is currently waiting to run.
  final bool isPending;

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
  AsyncDebouncerState<T> copyWith({
    int? executionCount,
    PacerStatus? status,
    int? maybeExecuteCount,
    T? lastArgs,
    bool? isPending,
    int? errorCount,
    int? successCount,
    int? settleCount,
    bool? isExecuting,
    dynamic lastResult,
  }) {
    return AsyncDebouncerState<T>(
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

/// Configuration options for [Debouncer].
///
/// Defines debouncing behavior including timing and execution triggers (leading/trailing).
/// This is the synchronous version of [AsyncDebouncerOptions].
///
/// Example:
/// ```dart
/// final options = DebouncerOptions<String>(
///   wait: Duration(milliseconds: 500),
///   leading: false,
///   trailing: true,
///   onExecute: (value) => print('Executing with: $value'),
/// );
/// ```
class DebouncerOptions<T> extends PacerOptions {
  const DebouncerOptions({
    required this.wait,
    super.enabled = true,
    super.key,
    this.leading = false,
    this.trailing = true,
    this.onExecute,
  });

  /// Duration to wait before executing the debounced function.
  ///
  /// The timer resets each time [maybeExecute] is called.
  final Duration wait;

  /// Whether to execute on the leading edge of the timeout.
  ///
  /// If true, executes immediately on the first call, then waits for the timeout period.
  final bool leading;

  /// Whether to execute on the trailing edge of the timeout.
  ///
  /// If true, executes after the wait period has elapsed since the last call.
  final bool trailing;

  /// Callback invoked when the debounced function executes.
  ///
  /// Receives the arguments passed to the execution.
  final void Function(T args)? onExecute;
}

/// State information for [Debouncer].
///
/// Tracks debouncing statistics and pending state. This is the synchronous
/// version of [AsyncDebouncerState].
///
/// Example usage:
/// ```dart
/// final debouncer = Debouncer<String>(
///   (value) => print('Processing: $value'),
///   DebouncerOptions<String>(wait: Duration(milliseconds: 300)),
/// );
///
/// print(debouncer.state.isPending); // Is a call pending?
/// print(debouncer.state.maybeExecuteCount); // Total calls to maybeExecute
/// print(debouncer.state.executionCount); // Actual executions
/// ```
class DebouncerState<T> extends PacerState {
  DebouncerState({
    super.executionCount = 0,
    super.status = PacerStatus.idle,
    this.maybeExecuteCount = 0,
    this.lastArgs,
    this.isPending = false,
  });

  /// Total number of times [maybeExecute] has been called.
  final int maybeExecuteCount;

  /// The most recent arguments passed to [maybeExecute].
  final T? lastArgs;

  /// Whether a debounced execution is currently waiting to run.
  final bool isPending;

  /// Creates a copy of this state with the given fields replaced with new values.
  DebouncerState<T> copyWith({
    int? executionCount,
    PacerStatus? status,
    int? maybeExecuteCount,
    T? lastArgs,
    bool? isPending,
  }) {
    return DebouncerState<T>(
      executionCount: executionCount ?? this.executionCount,
      status: status ?? this.status,
      maybeExecuteCount: maybeExecuteCount ?? this.maybeExecuteCount,
      lastArgs: lastArgs ?? this.lastArgs,
      isPending: isPending ?? this.isPending,
    );
  }
}
