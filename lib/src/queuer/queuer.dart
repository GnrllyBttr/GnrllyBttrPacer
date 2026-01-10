// 🎯 Dart imports:
import 'dart:async';
import 'dart:collection';

// 🐦 Flutter imports:
import 'package:flutter/foundation.dart';

// 🌎 Project imports:
import 'package:gnrllybttr_pacer/src/common/common.dart';
import 'package:gnrllybttr_pacer/src/queuer/models.dart';

/// A queue processor that manages and processes items with configurable ordering and timing.
///
/// [Queuer] is the synchronous version of [AsyncQueuer]. It manages a queue of items
/// and processes them according to configurable rules. Supports FIFO, LIFO, priority-based
/// ordering, size limits, expiration, and rate limiting.
///
/// ## Basic Example - Task Processing
///
/// ```dart
/// class TaskProcessor extends StatefulWidget {
///   @override
///   State<TaskProcessor> createState() => _TaskProcessorState();
/// }
///
/// class _TaskProcessorState extends State<TaskProcessor> {
///   late final Queuer<String> _queuer;
///   final List<String> _completedTasks = [];
///
///   @override
///   void initState() {
///     super.initState();
///     _queuer = Queuer<String>(
///       (task) {
///         setState(() => _completedTasks.add(task));
///       },
///       QueuerOptions<String>(
///         wait: Duration(milliseconds: 500),
///         maxSize: 10,
///         started: true,
///       ),
///     );
///   }
///
///   @override
///   void dispose() {
///     _queuer.dispose();
///     super.dispose();
///   }
///
///   void addTask(String task) {
///     final added = _queuer.addItem(task);
///     if (!added) {
///       print('Task rejected: queue full');
///     }
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return ListenableBuilder(
///       listenable: _queuer,
///       builder: (context, _) => Column(
///         children: [
///           Text('Queue size: ${_queuer.state.size}'),
///           Text('Completed: ${_completedTasks.length}'),
///           ElevatedButton(
///             onPressed: () => addTask('Task ${DateTime.now()}'),
///             child: Text('Add Task'),
///           ),
///         ],
///       ),
///     );
///   }
/// }
/// ```
///
/// ## Example - LIFO Stack
///
/// Process items in reverse order (most recent first):
/// ```dart
/// final stackQueuer = Queuer<int>(
///   (number) => print('Processing: $number'),
///   QueuerOptions<int>(
///     addItemsTo: QueuePosition.back,
///     getItemsFrom: QueuePosition.back, // Get from same end = LIFO
///     wait: Duration(milliseconds: 100),
///     started: true,
///   ),
/// );
///
/// stackQueuer.addItem(1);
/// stackQueuer.addItem(2);
/// stackQueuer.addItem(3);
/// // Processes: 3, 2, 1 (reverse order)
/// ```
///
/// ## Example - Priority Queue
///
/// Process items based on priority:
/// ```dart
/// enum Priority { low, medium, high }
///
/// class PriorityTask {
///   final String name;
///   final Priority priority;
///   PriorityTask(this.name, this.priority);
/// }
///
/// final priorityQueuer = Queuer<PriorityTask>(
///   (task) => print('Processing: ${task.name}'),
///   QueuerOptions<PriorityTask>(
///     getPriority: (task) => task.priority.index,
///     wait: Duration(milliseconds: 200),
///     started: true,
///   ),
/// );
///
/// priorityQueuer.addItem(PriorityTask('Low', Priority.low));
/// priorityQueuer.addItem(PriorityTask('High', Priority.high));
/// priorityQueuer.addItem(PriorityTask('Medium', Priority.medium));
/// // Processes by priority: High (0), Medium (1), Low (2)
/// ```
///
/// ## Example - Item Expiration
///
/// Remove old items that haven't been processed:
/// ```dart
/// final expiringQueuer = Queuer<String>(
///   (item) => print('Processed: $item'),
///   QueuerOptions<String>(
///     expirationDuration: Duration(seconds: 30),
///     onExpire: (item) => print('Expired: $item'),
///     wait: Duration(seconds: 5),
///     started: true,
///   ),
/// );
///
/// expiringQueuer.addItem('Time-sensitive task');
/// // If not processed within 30 seconds, will expire
/// ```
///
/// ## Example - Queue Control
///
/// Start, stop, and manage queue processing:
/// ```dart
/// final queuer = Queuer<String>(
///   (item) => print(item),
///   QueuerOptions<String>(
///     wait: Duration(milliseconds: 100),
///     started: false, // Don't auto-start
///   ),
/// );
///
/// // Add items while stopped
/// queuer.addItem('Task 1');
/// queuer.addItem('Task 2');
/// print(queuer.state.size); // 2
///
/// // Start processing
/// queuer.start();
/// print(queuer.state.isRunning); // true
///
/// // Pause processing
/// queuer.stop();
///
/// // Clear all items
/// queuer.clear();
/// print(queuer.state.isEmpty); // true
/// ```
class Queuer<T> extends ChangeNotifier {
  /// Creates a [Queuer] with the given function and options.
  ///
  /// The [fn] will be called for each item when processing.
  /// If [QueuerOptions.started] is true, processing begins immediately.
  Queuer(this.fn, QueuerOptions<T> options)
      : _options = options,
        _state = QueuerState() {
    if (!_options.enabled) {
      _state = _state.copyWith(status: PacerStatus.disabled);
    } else if (_options.started) {
      start();
    }
  }

  /// The function to execute for each queued item.
  final AnyFunction fn;

  QueuerOptions<T> _options;
  QueuerState<T> _state;
  Timer? _processTimer;
  final Queue<T> _queue = Queue<T>();
  final List<DateTime> _timestamps = [];

  /// Current configuration options for this queuer.
  QueuerOptions<T> get options => _options;

  /// Current state of this queuer.
  QueuerState<T> get state => _state;

  /// Adds an item to the queue.
  ///
  /// Returns true if the item was added, false if rejected (queue full).
  /// The [position] parameter can override the default add position.
  /// [runOnItemsChange] controls whether listeners are notified.
  bool addItem(
    T item, {
    QueuePosition position = QueuePosition.back,
    bool runOnItemsChange = true,
  }) {
    if (!_options.enabled) {
      return false;
    }

    if (_options.maxSize != null && _queue.length >= _options.maxSize!) {
      _options.onReject?.call(item);
      _state = _state.copyWith(rejectionCount: _state.rejectionCount + 1);
      notifyListeners();
      return false;
    }

    if (position == QueuePosition.back) {
      _queue.add(item);
    } else {
      _queue.addFirst(item);
    }
    _timestamps.add(DateTime.now());

    _state = _state.copyWith(
      addItemCount: _state.addItemCount + 1,
      items: _queue.toList(),
      itemTimestamps: List.from(_timestamps),
      isEmpty: _queue.isEmpty,
      isFull: _options.maxSize != null && _queue.length >= _options.maxSize!,
      size: _queue.length,
    );
    notifyListeners();

    if (_state.isRunning) {
      _scheduleNext();
    }

    return true;
  }

  /// Retrieves and removes the next item from the queue.
  ///
  /// Returns null if the queue is empty. Automatically expires old items
  /// before retrieving. The item is retrieved from the position specified
  /// by [QueuerOptions.getItemsFrom].
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
      isEmpty: _queue.isEmpty,
      isFull: _options.maxSize != null && _queue.length >= _options.maxSize!,
      size: _queue.length,
    );
    notifyListeners();

    return item;
  }

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

  /// Starts processing items from the queue.
  ///
  /// If [QueuerOptions.wait] is specified, items are processed at that interval.
  /// Otherwise, items are processed as fast as possible.
  void start() {
    if (_state.isRunning) {
      return;
    }

    _state = _state.copyWith(isRunning: true, status: PacerStatus.running);
    notifyListeners();
    _scheduleNext();
  }

  /// Stops processing items from the queue.
  ///
  /// Items remain in the queue and can be processed later by calling [start].
  void stop() {
    _processTimer?.cancel();
    _state = _state.copyWith(isRunning: false, status: PacerStatus.idle);
    notifyListeners();
  }

  void _scheduleNext() {
    if (!_state.isRunning || _queue.isEmpty) {
      return;
    }

    if (_options.wait != null) {
      _processTimer = Timer(_options.wait!, _processNext);
    } else {
      _processNext();
    }
  }

  void _processNext() {
    final item = getNextItem();
    if (item != null) {
      fn(item);
      _options.onExecute?.call(item);
      _state = _state.copyWith(executionCount: _state.executionCount + 1);
      notifyListeners();
      _scheduleNext();
    }
  }

  /// Removes all items from the queue.
  ///
  /// Processing continues if the queue was running, but with no items to process.
  void clear() {
    _queue.clear();
    _timestamps.clear();
    _state = _state.copyWith(
      items: [],
      itemTimestamps: [],
      isEmpty: true,
      isFull: false,
      size: 0,
    );
    notifyListeners();
  }

  /// Clears the queue and resets all counters.
  ///
  /// Resets [addItemCount], [executionCount], [expirationCount], and [rejectionCount].
  void reset() {
    clear();
    _state = _state.copyWith(
      addItemCount: 0,
      executionCount: 0,
      expirationCount: 0,
      rejectionCount: 0,
    );
    notifyListeners();
  }

  /// Immediately processes all remaining items in the queue.
  ///
  /// Ignores the [wait] duration and processes items synchronously.
  void flush() {
    while (_queue.isNotEmpty) {
      _processNext();
    }
  }

  /// Returns a copy of all items currently in the queue without removing them.
  ///
  /// Useful for inspecting queue contents without modifying the queue.
  List<T> peekAllItems() => _queue.toList();

  /// Updates the queuer options at runtime.
  ///
  /// If [enabled] is set to false, processing will stop.
  /// If [started] is true and queue isn't running, it will start.
  void setOptions(QueuerOptions<T> options) {
    _options = options;
    if (!_options.enabled) {
      stop();
      _state = _state.copyWith(status: PacerStatus.disabled);
    } else {
      _state = _state.copyWith(status: PacerStatus.idle);
      if (_options.started && !_state.isRunning) {
        start();
      }
    }
    notifyListeners();
  }
}
