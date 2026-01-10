// 🎯 Dart imports:
import 'dart:async';
import 'dart:collection';

// 🐦 Flutter imports:
import 'package:flutter/foundation.dart';

// 🌎 Project imports:
import 'package:gnrllybttr_pacer/src/common/common.dart';
import 'package:gnrllybttr_pacer/src/queuer/models.dart';

/// A queue-based task processor with configurable concurrency and ordering.
///
/// [AsyncQueuer] manages a queue of items and processes them according to
/// configured rules for ordering (FIFO/LIFO), concurrency, timing, capacity,
/// and expiration. This is useful for managing task execution, rate-limiting
/// operations, or ensuring sequential processing of async operations.
///
/// The queuer can be configured with:
/// - Queue capacity and overflow handling
/// - Processing order (FIFO, LIFO, or priority-based)
/// - Concurrent execution of multiple items
/// - Minimum wait time between processing
/// - Item expiration timeouts
///
/// ## Features
///
/// - Configurable FIFO/LIFO queue ordering
/// - Concurrent processing with configurable parallelism
/// - Queue capacity limits with rejection callbacks
/// - Item expiration with automatic cleanup
/// - Start/stop control for processing
/// - Comprehensive state tracking
/// - Error handling with optional error propagation
/// - Integration with Flutter's [ChangeNotifier]
///
/// ## Example: Basic Sequential Queue
///
/// ```dart
/// final queuer = AsyncQueuer<String>(
///   (item) async {
///     print('Processing: $item');
///     await Future.delayed(Duration(milliseconds: 100));
///     return 'Processed: $item';
///   },
///   AsyncQueuerOptions<String>(
///     started: true, // Start processing immediately
///     onExecute: (item) => print('Started: $item'),
///     onSuccess: (result) => print('Completed: $result'),
///   ),
/// );
///
/// // Add items to the queue
/// await queuer.addItem('task1');
/// await queuer.addItem('task2');
/// await queuer.addItem('task3');
/// // Items are processed sequentially in order
/// ```
///
/// ## Example: Concurrent Processing
///
/// ```dart
/// // Process up to 3 items simultaneously
/// final queuer = AsyncQueuer<Map<String, dynamic>>(
///   (item) async => uploadFile(item['file']),
///   AsyncQueuerOptions<Map<String, dynamic>>(
///     concurrency: 3, // Process 3 items at once
///     maxSize: 50,    // Max 50 items in queue
///     started: true,
///     onReject: (item) {
///       print('Queue full, rejected: ${item['file']}');
///     },
///   ),
/// );
///
/// // Add multiple files
/// for (final file in files) {
///   try {
///     await queuer.addItem({'file': file});
///   } catch (e) {
///     print('Queue is full');
///   }
/// }
/// ```
///
/// ## Example: With Flutter Widget
///
/// ```dart
/// class QueueStatusWidget extends StatefulWidget {
///   @override
///   _QueueStatusWidgetState createState() => _QueueStatusWidgetState();
/// }
///
/// class _QueueStatusWidgetState extends State<QueueStatusWidget> {
///   late AsyncQueuer<Task> taskQueuer;
///
///   @override
///   void initState() {
///     super.initState();
///     taskQueuer = AsyncQueuer<Task>(
///       (task) async => executeTask(task),
///       AsyncQueuerOptions<Task>(
///         concurrency: 2,
///         maxSize: 20,
///         wait: Duration(milliseconds: 500),
///       ),
///     );
///     taskQueuer.addListener(() => setState(() {}));
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return Column(
///       children: [
///         Text('Queue size: ${taskQueuer.state.size}'),
///         Text('Processing: ${taskQueuer.state.activeItems.length}'),
///         Text('Completed: ${taskQueuer.state.executionCount}'),
///         ElevatedButton(
///           onPressed: taskQueuer.state.isRunning
///               ? () => taskQueuer.stop()
///               : () => taskQueuer.start(),
///           child: Text(taskQueuer.state.isRunning ? 'Pause' : 'Resume'),
///         ),
///         ElevatedButton(
///           onPressed: () => taskQueuer.addItem(Task()),
///           child: Text('Add Task'),
///         ),
///       ],
///     );
///   }
///
///   @override
///   void dispose() {
///     taskQueuer.dispose();
///     super.dispose();
///   }
/// }
/// ```
///
/// ## Example: Item Expiration
///
/// ```dart
/// final queuer = AsyncQueuer<Request>(
///   (request) async => processRequest(request),
///   AsyncQueuerOptions<Request>(
///     expirationDuration: Duration(seconds: 30),
///     onExpire: (request) {
///       print('Request timed out: ${request.id}');
///       notifyUser('Request ${request.id} expired');
///     },
///     started: true,
///   ),
/// );
///
/// await queuer.addItem(Request(id: '123'));
/// // If not processed within 30 seconds, item expires
/// ```
///
/// ## Example: LIFO/Stack Behavior
///
/// ```dart
/// // Process most recent items first (stack/LIFO)
/// final queuer = AsyncQueuer<String>(
///   (item) async => handleItem(item),
///   AsyncQueuerOptions<String>(
///     addItemsTo: QueuePosition.front,   // Add to front
///     getItemsFrom: QueuePosition.front, // Remove from front
///     started: true,
///   ),
/// );
///
/// await queuer.addItem('first');
/// await queuer.addItem('second');
/// await queuer.addItem('third');
/// // Processes: third, second, first (LIFO order)
/// ```
///
/// ## Example: Rate-Limited Processing
///
/// ```dart
/// // Process items with minimum delay between executions
/// final queuer = AsyncQueuer<ApiRequest>(
///   (request) async => callAPI(request),
///   AsyncQueuerOptions<ApiRequest>(
///     wait: Duration(milliseconds: 200), // Min 200ms between calls
///     concurrency: 1,
///     started: true,
///     onError: (error) => print('API call failed: $error'),
///   ),
/// );
///
/// // Rapid fire requests - queuer ensures spacing
/// for (int i = 0; i < 100; i++) {
///   await queuer.addItem(ApiRequest(id: i));
/// }
/// ```
class AsyncQueuer<T> extends ChangeNotifier {
  /// Creates an [AsyncQueuer] with the given processing function and options.
  ///
  /// The [fn] parameter is called for each item when it's dequeued for processing.
  /// The [options] parameter configures queue behavior, capacity, and callbacks.
  ///
  /// If [AsyncQueuerOptions.started] is true, the queue begins processing
  /// items immediately. Otherwise, call [start] to begin processing.
  ///
  /// Example:
  /// ```dart
  /// final queuer = AsyncQueuer<int>(
  ///   (number) async => number * 2,
  ///   AsyncQueuerOptions<int>(
  ///     concurrency: 2,
  ///     started: true,
  ///   ),
  /// );
  /// ```
  AsyncQueuer(this.fn, AsyncQueuerOptions<T> options)
      : _options = options,
        _state = AsyncQueuerState() {
    if (!_options.enabled) {
      _state = _state.copyWith(status: PacerStatus.disabled);
    } else if (_options.started) {
      start();
    }
  }

  /// The function to execute for each queued item.
  final AnyAsyncFunction fn;

  AsyncQueuerOptions<T> _options;
  AsyncQueuerState<T> _state;
  Timer? _processTimer;
  final Queue<T> _queue = Queue<T>();
  final List<DateTime> _timestamps = [];
  final Set<Completer<dynamic>> _activeCompleters = {};
  bool _aborted = false;

  /// The current configuration options for this queuer.
  AsyncQueuerOptions<T> get options => _options;

  /// The current state of this queuer, including queue contents and statistics.
  AsyncQueuerState<T> get state => _state;

  /// Adds an item to the queue for processing.
  ///
  /// The item is added according to [AsyncQueuerOptions.addItemsTo] configuration.
  /// If the queue is at capacity ([maxSize]), the item is rejected, [onReject]
  /// is called, and an exception is thrown.
  ///
  /// Returns a [Future] that completes when the item finishes processing.
  /// The future resolves to the result of processing, or null if an error occurred
  /// and [throwOnError] is false.
  ///
  /// If the queue is running, processing is scheduled automatically. Otherwise,
  /// the item waits until [start] is called.
  ///
  /// Parameters:
  /// - [item]: The item to add to the queue
  /// - [position]: Override the default add position for this item
  /// - [runOnItemsChange]: Internal parameter for state management
  ///
  /// Throws an [Exception] if the queuer is disabled or the queue is full.
  ///
  /// Example:
  /// ```dart
  /// final queuer = AsyncQueuer<String>(
  ///   (item) async => processItem(item),
  ///   AsyncQueuerOptions<String>(
  ///     maxSize: 10,
  ///     started: true,
  ///   ),
  /// );
  ///
  /// try {
  ///   final result = await queuer.addItem('task1');
  ///   print('Completed with: $result');
  /// } catch (e) {
  ///   print('Queue is full');
  /// }
  /// ```
  Future<dynamic> addItem(
    T item, {
    QueuePosition position = QueuePosition.back,
    bool runOnItemsChange = true,
  }) async {
    if (!_options.enabled) {
      throw Exception('Queuer is disabled');
    }

    if (_options.maxSize != null && _queue.length >= _options.maxSize!) {
      _options.onReject?.call(item);
      _state = _state.copyWith(rejectionCount: _state.rejectionCount + 1);
      notifyListeners();
      throw Exception('Queue is full');
    }

    final completer = Completer<dynamic>();
    _activeCompleters.add(completer);

    if (_options.addItemsTo == QueuePosition.back) {
      _queue.add(item);
    } else {
      _queue.addFirst(item);
    }
    _timestamps.add(DateTime.now());

    _state = _state.copyWith(
      addItemCount: _state.addItemCount + 1,
      items: _queue.toList(),
      itemTimestamps: List.from(_timestamps),
      pendingItems: [..._state.pendingItems, item],
      isEmpty: _queue.isEmpty,
      isFull: _options.maxSize != null && _queue.length >= _options.maxSize!,
      size: _queue.length,
    );
    notifyListeners();

    if (_state.isRunning) {
      _scheduleNext();
    }

    return completer.future;
  }

  /// Retrieves the next item from the queue for processing.
  ///
  /// Items are retrieved according to [AsyncQueuerOptions.getItemsFrom] configuration.
  /// Expired items are automatically removed before retrieval.
  ///
  /// Returns the next item, or null if the queue is empty.
  T? getNextItem() {
    if (_queue.isEmpty) {
      return null;
    }

    _expireItems();

    if (_queue.isEmpty) {
      return null;
    }

    T item;
    if (_options.getItemsFrom == QueuePosition.front) {
      item = _queue.removeFirst();
    } else {
      item = _queue.removeLast();
    }
    _timestamps.removeAt(0);

    _state = _state.copyWith(
      items: _queue.toList(),
      itemTimestamps: List.from(_timestamps),
      pendingItems: _state.pendingItems.where((i) => i != item).toList(),
      activeItems: [..._state.activeItems, item],
      isEmpty: _queue.isEmpty,
      isFull: _options.maxSize != null && _queue.length >= _options.maxSize!,
      size: _queue.length,
    );
    notifyListeners();

    return item;
  }

  /// Internal method to check for and remove expired items from the queue.
  void _expireItems() {
    if (_options.expirationDuration == null) {
      return;
    }

    final now = DateTime.now();
    final expiredIndices = <int>[];

    for (int i = 0; i < _timestamps.length; i++) {
      if (now.difference(_timestamps[i]) > _options.expirationDuration!) {
        expiredIndices.add(i);
      }
    }

    for (int i = expiredIndices.length - 1; i >= 0; i--) {
      final index = expiredIndices[i];
      final expiredItem = _queue.elementAt(index);
      _options.onExpire?.call(expiredItem);
      _queue.remove(expiredItem);
      _timestamps.removeAt(index);
      _state = _state.copyWith(expirationCount: _state.expirationCount + 1);
    }

    if (expiredIndices.isNotEmpty) {
      _state = _state.copyWith(
        items: _queue.toList(),
        itemTimestamps: List.from(_timestamps),
        isEmpty: _queue.isEmpty,
        isFull: _options.maxSize != null && _queue.length >= _options.maxSize!,
        size: _queue.length,
      );
      notifyListeners();
    }
  }

  /// Starts processing items in the queue.
  ///
  /// If already running, this method does nothing. Once started, items are
  /// processed according to the configured concurrency, wait time, and ordering.
  ///
  /// Example:
  /// ```dart
  /// final queuer = AsyncQueuer<String>(
  ///   (item) async => process(item),
  ///   AsyncQueuerOptions<String>(started: false),
  /// );
  ///
  /// await queuer.addItem('item1');
  /// await queuer.addItem('item2');
  /// // Items are queued but not processed yet
  ///
  /// queuer.start(); // Begin processing
  /// ```
  void start() {
    if (_state.isRunning) {
      return;
    }

    _state = _state.copyWith(isRunning: true, status: PacerStatus.running);
    notifyListeners();
    _scheduleNext();
  }

  /// Stops processing items in the queue.
  ///
  /// Currently processing items will complete, but no new items will be started.
  /// Items remain in the queue and will resume processing when [start] is called.
  ///
  /// Example:
  /// ```dart
  /// queuer.stop(); // Pause processing
  /// // ... later ...
  /// queuer.start(); // Resume processing
  /// ```
  void stop() {
    _processTimer?.cancel();
    _state = _state.copyWith(isRunning: false, status: PacerStatus.idle);
    notifyListeners();
  }

  /// Internal method to schedule the next item for processing.
  void _scheduleNext() {
    if (!_state.isRunning || _queue.isEmpty || _aborted) {
      return;
    }

    final activeCount = _state.activeItems.length;
    if (_options.concurrency != null && activeCount >= _options.concurrency!) {
      return;
    }

    if (_options.wait != null) {
      _processTimer = Timer(_options.wait!, _processNext);
    } else {
      _processNext();
    }
  }

  /// Internal method to process the next item in the queue.
  Future<void> _processNext() async {
    final item = getNextItem();
    if (item == null || _aborted) {
      return;
    }

    _state = _state.copyWith(isExecuting: true, status: PacerStatus.executing);
    notifyListeners();

    try {
      final result = await fn(item);
      if (!_aborted) {
        _options.onExecute?.call(item);
        _options.onSuccess?.call(result);
        _state = _state.copyWith(
          executionCount: _state.executionCount + 1,
          successCount: _state.successCount + 1,
          settleCount: _state.settleCount + 1,
          lastResult: result,
          activeItems: _state.activeItems.where((i) => i != item).toList(),
          isExecuting: false,
        );
        // Complete the corresponding completer
        final completer = _activeCompleters.firstWhere((c) => !c.isCompleted);
        completer.complete(result);
        _activeCompleters.remove(completer);
      }
    } catch (e) {
      if (!_aborted) {
        _options.onError?.call(e);
        _state = _state.copyWith(
          errorCount: _state.errorCount + 1,
          settleCount: _state.settleCount + 1,
          activeItems: _state.activeItems.where((i) => i != item).toList(),
          isExecuting: false,
        );
        final completer = _activeCompleters.firstWhere((c) => !c.isCompleted);
        if (_options.throwOnError) {
          completer.completeError(e);
        } else {
          completer.complete(null);
        }
        _activeCompleters.remove(completer);
      }
    } finally {
      _options.onSettled?.call(_state.lastResult, null);
      notifyListeners();
      _scheduleNext();
    }
  }

  /// Removes all items from the queue.
  ///
  /// Clears both pending and active items. Does not affect currently executing tasks.
  ///
  /// Example:
  /// ```dart
  /// queuer.clear(); // Remove all queued items
  /// ```
  void clear() {
    _queue.clear();
    _timestamps.clear();
    _state = _state.copyWith(
      items: [],
      itemTimestamps: [],
      activeItems: [],
      pendingItems: [],
      isEmpty: true,
      isFull: false,
      size: 0,
    );
    notifyListeners();
  }

  /// Resets the queuer to initial state, clearing queue and statistics.
  ///
  /// Clears all items and resets all counters (execution, rejection, expiration).
  ///
  /// Example:
  /// ```dart
  /// queuer.reset(); // Fresh start
  /// ```
  void reset() {
    clear();
    _state = _state.copyWith(
      addItemCount: 0,
      executionCount: 0,
      expirationCount: 0,
      rejectionCount: 0,
      errorCount: 0,
      successCount: 0,
      settleCount: 0,
    );
    notifyListeners();
  }

  /// Processes all queued items immediately, ignoring wait times.
  ///
  /// Items are still subject to concurrency limits. This method returns
  /// immediately and does not wait for processing to complete.
  ///
  /// Example:
  /// ```dart
  /// // Process everything now
  /// queuer.flush();
  /// ```
  void flush() {
    while (_queue.isNotEmpty && !_aborted) {
      _processNext();
    }
  }

  /// Returns a copy of all items currently in the queue.
  ///
  /// Does not include items currently being processed.
  List<T> peekAllItems() => _queue.toList();

  /// Returns a copy of all items currently being processed.
  List<T> peekActiveItems() => _state.activeItems;

  /// Returns a copy of all items waiting in the queue.
  List<T> peekPendingItems() => _state.pendingItems;

  /// Aborts the queuer, canceling all pending operations.
  ///
  /// Stops processing, completes all pending futures with errors, and clears
  /// internal state. The queuer can be restarted with [start].
  ///
  /// Example:
  /// ```dart
  /// queuer.abort(); // Stop everything
  /// ```
  void abort() {
    _aborted = true;
    _processTimer?.cancel();
    _state = _state.copyWith(status: PacerStatus.idle);
    for (final completer in _activeCompleters) {
      if (!completer.isCompleted) {
        completer.completeError('Aborted');
      }
    }
    _activeCompleters.clear();
    notifyListeners();
  }

  /// Updates the queuer configuration with new options.
  ///
  /// Applies the new options immediately. If the new options disable the queuer,
  /// it is aborted. If the new options enable auto-start and the queuer isn't
  /// running, it starts automatically.
  ///
  /// Example:
  /// ```dart
  /// queuer.setOptions(
  ///   AsyncQueuerOptions<String>(
  ///     concurrency: 5, // Increase parallelism
  ///     maxSize: 200,   // Increase capacity
  ///   ),
  /// );
  /// ```
  void setOptions(AsyncQueuerOptions<T> options) {
    _options = options;
    if (!_options.enabled) {
      abort();
      _state = _state.copyWith(status: PacerStatus.disabled);
    } else if (_options.started && !_state.isRunning) {
      start();
    }
    notifyListeners();
  }
}
