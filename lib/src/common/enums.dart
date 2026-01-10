/// Types of backoff strategies for retry delays.
///
/// Used by [AsyncRetryer] to determine how long to wait between retry attempts.
enum BackoffType {
  /// Exponential backoff: wait time doubles with each attempt (1s, 2s, 4s, 8s...)
  ///
  /// Best for network operations where congestion might be causing failures.
  exponential,

  /// Linear backoff: wait time increases linearly with each attempt (1s, 2s, 3s, 4s...)
  ///
  /// Good for predictable delays or when you want gradual backoff.
  linear,

  /// Fixed backoff: same wait time between all attempts (1s, 1s, 1s, 1s...)
  ///
  /// Useful when you want consistent retry intervals.
  fixed,
}

/// Status of a pacer operation.
///
/// Provides a consistent way to track the current state of any pacer
/// across the GnrllyBttrPacer package.
enum PacerStatus {
  /// Pacer is disabled and will not execute operations.
  ///
  /// When disabled, pacers ignore execution requests and maintain
  /// their disabled state until re-enabled.
  disabled,

  /// Pacer is enabled but not currently executing anything.
  ///
  /// This is the normal ready state for most pacers.
  idle,

  /// Operation is queued and waiting for execution.
  ///
  /// Used by pacers that queue operations for later processing.
  pending,

  /// Operation is currently being executed.
  ///
  /// The pacer is actively running a function or operation.
  executing,

  /// Background process is running continuously.
  ///
  /// Used for pacers that maintain ongoing background operations
  /// (like continuous batching or monitoring).
  running,
}

/// Position in a queue where items can be added.
///
/// Used by queuing pacers to determine where new items should be inserted.
enum QueuePosition {
  /// Add items to the front of the queue (highest priority).
  ///
  /// Items added to the front will be processed before items already in the queue.
  front,

  /// Add items to the back of the queue (normal priority).
  ///
  /// Items added to the back will be processed after existing items.
  back,
}

/// The type of time window to use for rate limiting.
///
/// Determines how the rate limiter calculates whether the limit has been exceeded.
/// Each type has different characteristics for precision and behavior.
enum WindowType {
  /// Fixed window: Counts executions within fixed time intervals.
  ///
  /// Window resets at fixed intervals regardless of when executions occur.
  /// Simple but can allow bursts at window boundaries.
  ///
  /// Example: 10 requests per minute, resetting at :00, :01, :02, etc.
  fixed,

  /// Sliding window: Counts executions within a rolling time window.
  ///
  /// Window moves based on each execution time, providing more precise limiting.
  /// More complex but prevents boundary bursts.
  ///
  /// Example: 10 requests per minute, window slides with each request.
  sliding
}
