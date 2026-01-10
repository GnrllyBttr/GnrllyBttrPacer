// 🌎 Project imports:
import 'package:gnrllybttr_pacer/src/common/common.dart';

/// Configuration options for [AsyncBatcher].
///
/// Defines the behavior of batch processing including size limits, timing,
/// execution conditions, and event callbacks.
///
/// Example:
/// ```dart
/// final options = AsyncBatcherOptions<String>(
///   maxSize: 10,
///   wait: Duration(seconds: 2),
///   onExecute: (items) => print('Processing ${items.length} items'),
///   onSuccess: (result) => print('Batch completed successfully'),
///   throwOnError: true,
/// );
/// ```
class AsyncBatcherOptions<T> extends PacerOptions {
  const AsyncBatcherOptions({
    super.enabled = true,
    super.key,
    this.maxSize,
    this.wait,
    this.getShouldExecute,
    this.onExecute,
    this.onItemsChange,
    this.started = false,
    this.onSuccess,
    this.onError,
    this.onSettled,
    this.throwOnError = false,
  });

  /// Maximum number of items to accumulate before automatically executing.
  ///
  /// When the batch reaches this size, it will execute immediately.
  /// If null, only [wait] duration or manual [execute] will trigger execution.
  final int? maxSize;

  /// Maximum duration to wait before executing accumulated items.
  ///
  /// Timer starts when the first item is added to an empty batch.
  /// If null, only [maxSize] or manual [execute] will trigger execution.
  final Duration? wait;

  /// Custom function to determine if batch should execute.
  ///
  /// Receives the current list of items and returns true if execution should proceed.
  /// Takes precedence over [maxSize] when provided.
  final ShouldExecuteGetter<T>? getShouldExecute;

  /// Callback invoked when batch execution begins.
  ///
  /// Receives the list of items being processed.
  final void Function(List<T> items)? onExecute;

  /// Callback invoked whenever items are added or removed from the batch.
  ///
  /// Receives the current list of items.
  final void Function(List<T> items)? onItemsChange;

  /// Whether the batcher should start in an active state.
  final bool started;

  /// Callback invoked when batch execution completes successfully.
  ///
  /// Receives the result returned by the batch function.
  final void Function(dynamic result)? onSuccess;

  /// Callback invoked when batch execution encounters an error.
  ///
  /// Receives the error object.
  final void Function(dynamic error)? onError;

  /// Callback invoked after batch execution completes, regardless of success or failure.
  ///
  /// Receives the result (if successful) and error (if failed).
  final void Function(dynamic result, dynamic error)? onSettled;

  /// Whether to rethrow errors after invoking [onError].
  ///
  /// If true, errors will propagate to callers of [addItem].
  /// If false, errors are caught and logged but don't propagate.
  final bool throwOnError;
}

/// State information for [AsyncBatcher].
///
/// Tracks the current batch items, execution statistics, and processing status.
/// This class extends [ChangeNotifier] indirectly through [AsyncBatcher],
/// allowing widgets to rebuild when state changes.
///
/// Example usage:
/// ```dart
/// final batcher = AsyncBatcher<int>(
///   (items) async => print('Processing: $items'),
///   AsyncBatcherOptions<int>(),
/// );
///
/// print(batcher.state.size); // Current batch size
/// print(batcher.state.totalItemsProcessed); // Total items processed
/// print(batcher.state.isExecuting); // Is currently executing
/// ```
class AsyncBatcherState<T> extends PacerState {
  const AsyncBatcherState({
    super.executionCount = 0,
    super.status = PacerStatus.idle,
    this.items = const [],
    this.isEmpty = true,
    this.isPending = false,
    this.size = 0,
    this.totalItemsProcessed = 0,
    this.failedItems = const [],
    this.errorCount = 0,
    this.successCount = 0,
    this.settleCount = 0,
    this.isExecuting = false,
    this.lastResult,
  });

  /// Current items accumulated in the batch awaiting execution.
  final List<T> items;

  /// Whether the batch is currently empty (no items).
  final bool isEmpty;

  /// Whether a timer is active waiting to execute the batch.
  final bool isPending;

  /// Number of items currently in the batch.
  final int size;

  /// Total number of items that have been processed across all executions.
  final int totalItemsProcessed;

  /// Items that failed during processing.
  final List<T> failedItems;

  /// Total number of batch executions that resulted in errors.
  final int errorCount;

  /// Total number of batch executions that completed successfully.
  final int successCount;

  /// Total number of batch executions that have settled (success or error).
  final int settleCount;

  /// Whether a batch execution is currently in progress.
  final bool isExecuting;

  /// The result from the most recent successful batch execution.
  final dynamic lastResult;

  /// Creates a copy of this state with the given fields replaced with new values.
  ///
  /// All parameters are optional. Fields not provided will retain their current values.
  AsyncBatcherState<T> copyWith({
    int? executionCount,
    PacerStatus? status,
    List<T>? items,
    bool? isEmpty,
    bool? isPending,
    int? size,
    int? totalItemsProcessed,
    List<T>? failedItems,
    int? errorCount,
    int? successCount,
    int? settleCount,
    bool? isExecuting,
    dynamic lastResult,
  }) {
    return AsyncBatcherState<T>(
      executionCount: executionCount ?? this.executionCount,
      status: status ?? this.status,
      items: items ?? this.items,
      isEmpty: isEmpty ?? this.isEmpty,
      isPending: isPending ?? this.isPending,
      size: size ?? this.size,
      totalItemsProcessed: totalItemsProcessed ?? this.totalItemsProcessed,
      failedItems: failedItems ?? this.failedItems,
      errorCount: errorCount ?? this.errorCount,
      successCount: successCount ?? this.successCount,
      settleCount: settleCount ?? this.settleCount,
      isExecuting: isExecuting ?? this.isExecuting,
      lastResult: lastResult ?? this.lastResult,
    );
  }
}

/// Configuration options for [Batcher].
///
/// Defines batch behavior including size limits, timing, execution conditions,
/// and event callbacks. This is the synchronous version of [AsyncBatcherOptions].
///
/// Example:
/// ```dart
/// final options = BatcherOptions<String>(
///   maxSize: 10,
///   wait: Duration(seconds: 2),
///   onExecute: (items) => print('Processing ${items.length} items'),
/// );
/// ```
class BatcherOptions<T> extends PacerOptions {
  const BatcherOptions({
    super.enabled = true,
    super.key,
    this.maxSize,
    this.wait,
    this.getShouldExecute,
    this.onExecute,
    this.onItemsChange,
    this.started = false,
  });

  /// Maximum number of items to accumulate before automatically executing.
  ///
  /// When the batch reaches this size, it will execute immediately.
  /// If null, only [wait] duration or manual [execute] will trigger execution.
  final int? maxSize;

  /// Maximum duration to wait before executing accumulated items.
  ///
  /// Timer starts when the first item is added to an empty batch.
  /// If null, only [maxSize] or manual [execute] will trigger execution.
  final Duration? wait;

  /// Custom function to determine if batch should execute.
  ///
  /// Receives the current list of items and returns true if execution should proceed.
  /// Takes precedence over [maxSize] when provided.
  final ShouldExecuteGetter<T>? getShouldExecute;

  /// Callback invoked when batch execution occurs.
  ///
  /// Receives the list of items being processed.
  final void Function(List<T> items)? onExecute;

  /// Callback invoked whenever items are added to the batch.
  ///
  /// Receives the current list of items.
  final void Function(List<T> items)? onItemsChange;

  /// Whether the batcher should start in an active state.
  final bool started;
}

/// State information for [Batcher].
///
/// Tracks the current batch items and execution statistics. This is the
/// synchronous version of [AsyncBatcherState].
///
/// Example usage:
/// ```dart
/// final batcher = Batcher<int>(
///   (items) => print('Processing: $items'),
///   BatcherOptions<int>(),
/// );
///
/// print(batcher.state.size); // Current batch size
/// print(batcher.state.totalItemsProcessed); // Total items processed
/// print(batcher.state.isPending); // Is execution scheduled?
/// ```
class BatcherState<T> extends PacerState {
  const BatcherState({
    super.executionCount = 0,
    super.status = PacerStatus.idle,
    this.items = const [],
    this.isEmpty = true,
    this.isPending = false,
    this.size = 0,
    this.totalItemsProcessed = 0,
  });

  /// Current items accumulated in the batch awaiting execution.
  final List<T> items;

  /// Whether the batch is currently empty (no items).
  final bool isEmpty;

  /// Whether a timer is active waiting to execute the batch.
  final bool isPending;

  /// Number of items currently in the batch.
  final int size;

  /// Total number of items that have been processed across all executions.
  final int totalItemsProcessed;

  /// Creates a copy of this state with the given fields replaced with new values.
  ///
  /// All parameters are optional. Fields not provided will retain their current values.
  BatcherState<T> copyWith({
    int? executionCount,
    PacerStatus? status,
    List<T>? items,
    bool? isEmpty,
    bool? isPending,
    int? size,
    int? totalItemsProcessed,
  }) {
    return BatcherState<T>(
      executionCount: executionCount ?? this.executionCount,
      status: status ?? this.status,
      items: items ?? this.items,
      isEmpty: isEmpty ?? this.isEmpty,
      isPending: isPending ?? this.isPending,
      size: size ?? this.size,
      totalItemsProcessed: totalItemsProcessed ?? this.totalItemsProcessed,
    );
  }
}
