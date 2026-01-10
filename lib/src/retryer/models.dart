import 'package:gnrllybttr_pacer/src/common/common.dart';

/// Configuration options for [AsyncRetryer].
///
/// Controls retry behavior, backoff strategies, timeouts, and callback functions.
/// Extends [PacerOptions] to inherit common pacing configuration.
class AsyncRetryerOptions<T> extends PacerOptions {
  /// Creates retry configuration with customizable behavior.
  ///
  /// Example:
  /// ```dart
  /// final options = AsyncRetryerOptions<String>(
  ///   maxAttempts: 5,
  ///   backoff: BackoffType.exponential,
  ///   baseWait: Duration(seconds: 1),
  ///   jitter: Duration(milliseconds: 500),
  ///   maxTotalExecutionTime: Duration(minutes: 1),
  ///   onRetry: (attempt, error) => print('Attempt $attempt failed: $error'),
  ///   onSuccess: (result) => print('Success: $result'),
  ///   throwOnError: false,
  /// );
  /// ```
  const AsyncRetryerOptions({
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

  /// Maximum number of retry attempts (including the initial attempt).
  ///
  /// For example, if maxAttempts is 3, the operation will be tried up to 3 times
  /// total (1 initial + 2 retries).
  final int maxAttempts;

  /// The backoff strategy to use for calculating delays between retries.
  ///
  /// See [BackoffType] for available options.
  final BackoffType backoff;

  /// Base duration for calculating retry delays.
  ///
  /// - For exponential backoff: delays are baseWait * (2 ^ (attempt - 1))
  /// - For linear backoff: delays are baseWait * attempt
  /// - For fixed backoff: delays are always baseWait
  final Duration baseWait;

  /// Random jitter to add to retry delays to prevent thundering herd.
  ///
  /// If specified, a random duration between 0 and jitter is added to each delay.
  /// Helps distribute retry attempts when many operations fail simultaneously.
  final Duration? jitter;

  /// Maximum time allowed for a single execution attempt.
  ///
  /// If an attempt takes longer than this, it will be considered failed
  /// and may be retried depending on other settings.
  final Duration? maxExecutionTime;

  /// Maximum total time allowed for all attempts combined.
  ///
  /// If the total execution time exceeds this limit, retrying will stop
  /// even if maxAttempts hasn't been reached.
  final Duration? maxTotalExecutionTime;

  /// Called before each retry attempt with the attempt number and last error.
  ///
  /// Useful for logging, updating UI, or implementing custom retry logic.
  final void Function(int attempt, dynamic error)? onRetry;

  /// Called when the operation ultimately succeeds.
  ///
  /// Receives the successful result as a parameter.
  final void Function(dynamic result)? onSuccess;

  /// Called when an attempt fails (but retries may continue).
  ///
  /// Useful for logging errors or updating progress indicators.
  final void Function(dynamic error)? onError;

  /// Called when the retry operation is manually aborted.
  ///
  /// Useful for cleanup or notifying other parts of the application.
  final void Function()? onAbort;

  /// Whether to rethrow the final error after all retries are exhausted.
  ///
  /// If true, the last error will be thrown. If false, null will be returned
  /// and the error can be accessed via [AsyncRetryerState.lastError].
  final bool throwOnError;
}

/// State information for [AsyncRetryer].
///
/// Tracks retry execution statistics, current status, and results.
/// This is the asynchronous version of retry state tracking.
///
/// Example usage:
/// ```dart
/// final retryer = AsyncRetryer<String>(
///   (input) async => throw Exception('Always fails'),
///   AsyncRetryerOptions<String>(maxAttempts: 3),
/// );
///
/// await retryer.execute('test');
/// print(retryer.state.currentAttempt);    // Current attempt number
/// print(retryer.state.errorCount);        // Number of failed attempts
/// print(retryer.state.isExecuting);       // Whether currently executing
/// print(retryer.state.lastError);         // Last error that occurred
/// ```
class AsyncRetryerState<T> extends PacerState {
  /// Creates retry state with initial values.
  ///
  /// Tracks various retry metrics and execution status.
  const AsyncRetryerState({
    super.executionCount = 0,
    super.status = PacerStatus.idle,
    this.attemptCount = 0,
    this.currentAttempt = 0,
    this.errorCount = 0,
    this.successCount = 0,
    this.settleCount = 0,
    this.isExecuting = false,
    this.lastExecutionTime,
    this.totalExecutionTime,
    this.lastResult,
    this.lastError,
  });

  /// Total number of attempts made (including successful ones).
  ///
  /// This counts every execution attempt, whether it succeeds or fails.
  final int attemptCount;

  /// The current attempt number being executed (1-based).
  ///
  /// 0 when not executing, 1 for initial attempt, 2+ for retries.
  final int currentAttempt;

  /// Number of attempts that resulted in errors.
  final int errorCount;

  /// Number of attempts that succeeded.
  ///
  /// For retry logic, this will typically be 0 or 1 (the final successful attempt).
  final int successCount;

  /// Number of attempts that have completed (either success or failure).
  ///
  /// Useful for tracking progress through retry attempts.
  final int settleCount;

  /// Whether the retryer is currently executing an attempt.
  final bool isExecuting;

  /// Timestamp of the last execution attempt.
  final DateTime? lastExecutionTime;

  /// Total time spent on all attempts for the current operation.
  final Duration? totalExecutionTime;

  /// The result from the last successful execution.
  final dynamic lastResult;

  /// The error from the last failed attempt.
  final dynamic lastError;

  /// Creates a copy of this state with the given fields replaced with new values.
  ///
  /// Useful for updating state immutably.
  AsyncRetryerState<T> copyWith({
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
    return AsyncRetryerState<T>(
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
