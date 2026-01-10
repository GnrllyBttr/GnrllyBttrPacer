import 'package:gnrllybttr_pacer/src/common/common.dart';

/// Configuration options for [AsyncQueuer].
///
/// Defines queue behavior including capacity, ordering, timing, concurrency,
/// priority, expiration, and event callbacks.
///
/// Example:
/// ```dart
/// final options = AsyncQueuerOptions<String>(
///   maxSize: 100,
///   concurrency: 3,
///   wait: Duration(milliseconds: 100),
///   started: true,
///   onExecute: (item) => print('Processing: $item'),
///   onReject: (item) => print('Queue full, rejected: $item'),
/// );
/// ```
class AsyncQueuerOptions<T> extends PacerOptions {
  const AsyncQueuerOptions({
    super.enabled = true,
    super.key,
    this.wait,
    this.maxSize,
    this.addItemsTo = QueuePosition.back,
    this.getItemsFrom = QueuePosition.front,
    this.getPriority,
    this.expirationDuration,
    this.onExecute,
    this.onExpire,
    this.onReject,
    this.started = false,
    this.concurrency = 1,
    this.onSuccess,
    this.onError,
    this.onSettled,
    this.throwOnError = false,
  });

  /// Minimum duration to wait between processing items.
  ///
  /// If null, items are processed as fast as possible (subject to concurrency limits).
  final Duration? wait;

  /// Maximum number of items allowed in the queue.
  ///
  /// When the queue is full, new items are rejected and [onReject] is called.
  /// If null, the queue has unlimited capacity.
  final int? maxSize;

  /// Where new items are added to the queue.
  ///
  /// - [QueuePosition.back]: Add to the end (FIFO behavior)
  /// - [QueuePosition.front]: Add to the beginning (LIFO/stack behavior)
  final QueuePosition addItemsTo;

  /// Where items are retrieved from for processing.
  ///
  /// - [QueuePosition.front]: Process from the beginning (FIFO behavior)
  /// - [QueuePosition.back]: Process from the end (LIFO/stack behavior)
  final QueuePosition getItemsFrom;

  /// Function to determine item priority for custom ordering.
  ///
  /// Higher priority values are processed first. If null, items are processed
  /// in the order determined by [addItemsTo] and [getItemsFrom].
  final PriorityGetter<T>? getPriority;

  /// Duration after which queued items expire and are removed.
  ///
  /// Expired items trigger the [onExpire] callback. If null, items never expire.
  final Duration? expirationDuration;

  /// Callback invoked when an item begins processing.
  ///
  /// Receives the item being processed.
  final void Function(T item)? onExecute;

  /// Callback invoked when an item expires before being processed.
  ///
  /// Receives the expired item.
  final void Function(T item)? onExpire;

  /// Callback invoked when an item is rejected due to queue being full.
  ///
  /// Receives the rejected item.
  final void Function(T item)? onReject;

  /// Whether the queue should start processing items immediately.
  ///
  /// If false, call [start] to begin processing.
  final bool started;

  /// Maximum number of items to process concurrently.
  ///
  /// If null or 1, items are processed sequentially. Higher values allow
  /// parallel processing of multiple items.
  final int? concurrency;

  /// Callback invoked when an item is processed successfully.
  ///
  /// Receives the result returned by the processing function.
  final void Function(dynamic result)? onSuccess;

  /// Callback invoked when processing an item encounters an error.
  ///
  /// Receives the error object.
  final void Function(dynamic error)? onError;

  /// Callback invoked after processing completes, regardless of success or failure.
  ///
  /// Receives the result (if successful) and error (if failed).
  final void Function(dynamic result, dynamic error)? onSettled;

  /// Whether to rethrow errors after invoking [onError].
  ///
  /// If true, errors will propagate to callers of [addItem].
  /// If false, errors are caught and the future completes with null.
  final bool throwOnError;
}

/// State information for [AsyncQueuer].
///
/// Tracks queue contents, processing statistics, and execution status.
///
/// Example usage:
/// ```dart
/// final queuer = AsyncQueuer<String>(
///   (item) async => processItem(item),
///   AsyncQueuerOptions<String>(concurrency: 2),
/// );
///
/// print(queuer.state.size); // Items waiting in queue
/// print(queuer.state.activeItems); // Items currently being processed
/// print(queuer.state.isRunning); // Is the queue processing?
/// print(queuer.state.isFull); // Is the queue at capacity?
/// ```
class AsyncQueuerState<T> extends PacerState {
  AsyncQueuerState({
    super.executionCount = 0,
    super.status = PacerStatus.idle,
    this.addItemCount = 0,
    this.expirationCount = 0,
    this.rejectionCount = 0,
    List<T>? items,
    List<DateTime>? itemTimestamps,
    this.isEmpty = true,
    this.isFull = false,
    this.isRunning = false,
    this.size = 0,
    List<T>? activeItems,
    List<T>? pendingItems,
    this.errorCount = 0,
    this.successCount = 0,
    this.settleCount = 0,
    this.isExecuting = false,
    this.lastResult,
  }) :
    items = items ?? <T>[],
    itemTimestamps = itemTimestamps ?? <DateTime>[],
    activeItems = activeItems ?? <T>[],
    pendingItems = pendingItems ?? <T>[];

  /// Total number of items that have been added to the queue.
  final int addItemCount;

  /// Total number of items that expired before being processed.
  final int expirationCount;

  /// Total number of items rejected due to queue being full.
  final int rejectionCount;

  /// Current items in the queue waiting to be processed.
  final List<T> items;

  /// Timestamps when each queued item was added.
  final List<DateTime> itemTimestamps;

  /// Whether the queue is currently empty.
  final bool isEmpty;

  /// Whether the queue is at maximum capacity.
  final bool isFull;

  /// Whether the queue is actively processing items.
  final bool isRunning;

  /// Number of items currently in the queue.
  final int size;

  /// Items currently being processed.
  final List<T> activeItems;

  /// Items waiting in the queue to be processed.
  final List<T> pendingItems;

  /// Total number of processing operations that resulted in errors.
  final int errorCount;

  /// Total number of processing operations that completed successfully.
  final int successCount;

  /// Total number of processing operations that have settled (success or error).
  final int settleCount;

  /// Whether an item is currently being processed.
  final bool isExecuting;

  /// The result from the most recent successful processing operation.
  final dynamic lastResult;

  /// Creates a copy of this state with the given fields replaced with new values.
  ///
  /// All parameters are optional. Fields not provided will retain their current values.
  AsyncQueuerState<T> copyWith({
    int? executionCount,
    PacerStatus? status,
    int? addItemCount,
    int? expirationCount,
    int? rejectionCount,
    List<T>? items,
    List<DateTime>? itemTimestamps,
    bool? isEmpty,
    bool? isFull,
    bool? isRunning,
    int? size,
    List<T>? activeItems,
    List<T>? pendingItems,
    int? errorCount,
    int? successCount,
    int? settleCount,
    bool? isExecuting,
    dynamic lastResult,
  }) {
    return AsyncQueuerState<T>(
      executionCount: executionCount ?? this.executionCount,
      status: status ?? this.status,
      addItemCount: addItemCount ?? this.addItemCount,
      expirationCount: expirationCount ?? this.expirationCount,
      rejectionCount: rejectionCount ?? this.rejectionCount,
      items: items ?? this.items,
      itemTimestamps: itemTimestamps ?? this.itemTimestamps,
      isEmpty: isEmpty ?? this.isEmpty,
      isFull: isFull ?? this.isFull,
      isRunning: isRunning ?? this.isRunning,
      size: size ?? this.size,
      activeItems: activeItems ?? this.activeItems,
      pendingItems: pendingItems ?? this.pendingItems,
      errorCount: errorCount ?? this.errorCount,
      successCount: successCount ?? this.successCount,
      settleCount: settleCount ?? this.settleCount,
      isExecuting: isExecuting ?? this.isExecuting,
      lastResult: lastResult ?? this.lastResult,
    );
  }
}

/// Configuration options for [Queuer].
///
/// Controls queue processing behavior including ordering, size limits,
/// expiration, and timing. This is the synchronous version of [AsyncQueuerOptions].
///
/// Example:
/// ```dart
/// final options = QueuerOptions<Task>(
///   maxSize: 100,                    // Max 100 items
///   wait: Duration(milliseconds: 200), // Process every 200ms
///   addItemsTo: QueuePosition.back,   // Add to end (FIFO)
///   getItemsFrom: QueuePosition.front, // Process from front
///   expirationDuration: Duration(minutes: 5), // Expire old items
///   started: true,                   // Auto-start processing
/// );
/// ```
class QueuerOptions<T> extends PacerOptions {
  /// Creates queuer options.
  ///
  /// [wait] specifies the minimum time between processing items.
  /// [maxSize] limits the queue size (null = unlimited).
  /// [addItemsTo] and [getItemsFrom] control queue behavior.
  /// [getPriority] enables priority-based ordering.
  /// [expirationDuration] automatically removes old items.
  /// [started] begins processing immediately when true.
  const QueuerOptions({
    super.enabled = true,
    super.key,
    this.wait,
    this.maxSize,
    this.addItemsTo = QueuePosition.back,
    this.getItemsFrom = QueuePosition.front,
    this.getPriority,
    this.expirationDuration,
    this.onExecute,
    this.onExpire,
    this.onReject,
    this.started = false,
  });

  /// Minimum time between processing items. If null, processes immediately.
  final Duration? wait;

  /// Maximum number of items the queue can hold. If null, unlimited.
  final int? maxSize;

  /// Where to add new items (back for FIFO, front for LIFO).
  final QueuePosition addItemsTo;

  /// Where to get items for processing (front for FIFO, back for LIFO).
  final QueuePosition getItemsFrom;

  /// Function to determine item priority for priority queue ordering.
  final PriorityGetter<T>? getPriority;

  /// Duration after which queued items expire and are removed.
  final Duration? expirationDuration;

  /// Callback invoked before processing each item.
  final void Function(T item)? onExecute;

  /// Callback invoked when an item expires.
  final void Function(T item)? onExpire;

  /// Callback invoked when an item is rejected (queue full).
  final void Function(T item)? onReject;

  /// Whether the queue should start processing immediately.
  final bool started;
}

/// State information for [Queuer].
///
/// Tracks queue statistics, contents, and processing status. This is the synchronous
/// version of [AsyncQueuerState].
///
/// Example usage:
/// ```dart
/// final queuer = Queuer<String>((item) => print(item), QueuerOptions<String>());
///
/// queuer.addItem('Task 1');
/// print(queuer.state.size);        // Current queue size
/// print(queuer.state.isEmpty);     // Is queue empty?
/// print(queuer.state.isRunning);   // Is processing active?
/// print(queuer.state.executionCount); // Items processed
/// print(queuer.state.rejectionCount); // Items rejected
/// ```
class QueuerState<T> extends PacerState {
  /// Creates queuer state.
  ///
  /// Tracks various queue metrics and current status.
  QueuerState({
    super.executionCount = 0,
    super.status = PacerStatus.idle,
    this.addItemCount = 0,
    this.expirationCount = 0,
    this.rejectionCount = 0,
    List<T>? items,
    List<DateTime>? itemTimestamps,
    this.isEmpty = true,
    this.isFull = false,
    this.isRunning = false,
    this.size = 0,
  }) : 
    items = items ?? <T>[],
    itemTimestamps = itemTimestamps ?? <DateTime>[];

  /// Total number of items added to the queue.
  final int addItemCount;

  /// Number of items that expired and were removed.
  final int expirationCount;

  /// Number of items rejected due to queue being full.
  final int rejectionCount;

  /// Current items in the queue (copy, not modifiable).
  final List<T> items;

  /// Timestamps when each item was added to the queue.
  final List<DateTime> itemTimestamps;

  /// Whether the queue is currently empty.
  final bool isEmpty;

  /// Whether the queue has reached its maximum size.
  final bool isFull;

  /// Whether the queue is actively processing items.
  final bool isRunning;

  /// Current number of items in the queue.
  final int size;

  /// Creates a copy of this state with the given fields replaced with new values.
  QueuerState<T> copyWith({
    int? executionCount,
    PacerStatus? status,
    int? addItemCount,
    int? expirationCount,
    int? rejectionCount,
    List<T>? items,
    List<DateTime>? itemTimestamps,
    bool? isEmpty,
    bool? isFull,
    bool? isRunning,
    int? size,
  }) {
    return QueuerState<T>(
      executionCount: executionCount ?? this.executionCount,
      status: status ?? this.status,
      addItemCount: addItemCount ?? this.addItemCount,
      expirationCount: expirationCount ?? this.expirationCount,
      rejectionCount: rejectionCount ?? this.rejectionCount,
      items: items ?? this.items,
      itemTimestamps: itemTimestamps ?? this.itemTimestamps,
      isEmpty: isEmpty ?? this.isEmpty,
      isFull: isFull ?? this.isFull,
      isRunning: isRunning ?? this.isRunning,
      size: size ?? this.size,
    );
  }
}
