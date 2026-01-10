// 🎯 Dart imports:
import 'dart:async';

// 🐦 Flutter imports:
import 'package:flutter/foundation.dart';
import 'package:gnrllybttr_pacer/src/batcher/models.dart';

// 🌎 Project imports:
import 'package:gnrllybttr_pacer/src/common/common.dart';

/// A synchronous batch processor that accumulates items and executes them together.
///
/// [Batcher] is the synchronous version of [AsyncBatcher]. It collects items over
/// time or until a size threshold is reached, then processes them as a single batch
/// using a synchronous function. This is useful for optimizing operations that
/// benefit from bulk processing but don't require async execution.
///
/// Unlike [AsyncBatcher], this class executes synchronously and doesn't return
/// futures from [addItem]. Use this when your batch processing function doesn't
/// need to perform async operations.
///
/// ## Features
///
/// - Automatic batching based on size or time
/// - Manual flush and execution control
/// - Comprehensive state tracking
/// - Integration with Flutter's [ChangeNotifier]
///
/// ## Example: Basic Usage
///
/// ```dart
/// // Batch log entries for efficient writing
/// final logBatcher = Batcher<String>(
///   (entries) {
///     print('Writing ${entries.length} log entries');
///     writeLogsToFile(entries);
///   },
///   BatcherOptions<String>(
///     maxSize: 50,
///     wait: Duration(seconds: 5),
///     onExecute: (entries) => print('Flushing logs...'),
///   ),
/// );
///
/// logBatcher.addItem('Log entry 1');
/// logBatcher.addItem('Log entry 2');
/// // Executes after 50 items or 5 seconds
/// ```
///
/// ## Example: With Flutter Widget
///
/// ```dart
/// class BatchCollector extends StatefulWidget {
///   @override
///   _BatchCollectorState createState() => _BatchCollectorState();
/// }
///
/// class _BatchCollectorState extends State<BatchCollector> {
///   late Batcher<int> numberBatcher;
///
///   @override
///   void initState() {
///     super.initState();
///     numberBatcher = Batcher<int>(
///       (numbers) {
///         final sum = numbers.reduce((a, b) => a + b);
///         print('Batch sum: $sum');
///       },
///       BatcherOptions<int>(
///         maxSize: 10,
///         wait: Duration(seconds: 3),
///       ),
///     );
///     numberBatcher.addListener(() => setState(() {}));
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return Column(
///       children: [
///         Text('Batch size: ${numberBatcher.state.size}'),
///         Text('Total processed: ${numberBatcher.state.totalItemsProcessed}'),
///         ElevatedButton(
///           onPressed: () => numberBatcher.addItem(Random().nextInt(100)),
///           child: Text('Add Number'),
///         ),
///         ElevatedButton(
///           onPressed: () => numberBatcher.flush(),
///           child: Text('Process Now'),
///         ),
///       ],
///     );
///   }
///
///   @override
///   void dispose() {
///     numberBatcher.dispose();
///     super.dispose();
///   }
/// }
/// ```
///
/// ## Example: Custom Execution Condition
///
/// ```dart
/// final customBatcher = Batcher<Map<String, dynamic>>(
///   (items) {
///     print('Processing ${items.length} items');
///     processItems(items);
///   },
///   BatcherOptions<Map<String, dynamic>>(
///     // Execute when any high-priority item exists
///     getShouldExecute: (items) {
///       return items.any((item) => item['priority'] == 'high');
///     },
///     wait: Duration(seconds: 10), // Fallback timeout
///     onItemsChange: (items) {
///       print('Batch now has ${items.length} items');
///     },
///   ),
/// );
///
/// customBatcher.addItem({'priority': 'low', 'data': 'A'});
/// customBatcher.addItem({'priority': 'high', 'data': 'B'}); // Triggers execution
/// ```
class Batcher<T> extends ChangeNotifier {
  /// Creates a [Batcher] with the given batch processing function and options.
  ///
  /// The [fn] parameter is called with the accumulated items when the batch executes.
  /// The [options] parameter configures batch behavior, timing, and callbacks.
  ///
  /// Example:
  /// ```dart
  /// final batcher = Batcher<String>(
  ///   (items) => processItems(items),
  ///   BatcherOptions<String>(
  ///     maxSize: 10,
  ///     wait: Duration(seconds: 2),
  ///   ),
  /// );
  /// ```
  Batcher(this.fn, BatcherOptions<T> options)
      : _options = options,
        _state = const BatcherState() {
    if (!_options.enabled) {
      _state = _state.copyWith(status: PacerStatus.disabled);
    }
  }

  /// The synchronous function to execute when processing a batch of items.
  final AnyFunction fn;

  BatcherOptions<T> _options;
  BatcherState<T> _state;
  Timer? _batchTimer;

  /// The current configuration options for this batcher.
  BatcherOptions<T> get options => _options;

  /// The current state of this batcher, including accumulated items and statistics.
  BatcherState<T> get state => _state;

  /// Adds an item to the batch.
  ///
  /// The item is added to the batch immediately. If the batch should execute
  /// (based on [maxSize], [getShouldExecute], or other conditions), execution
  /// begins immediately. Otherwise, a timer is started (if [wait] is set) to
  /// execute the batch later.
  ///
  /// Unlike [AsyncBatcher.addItem], this method returns void and executes
  /// synchronously when triggered.
  ///
  /// Does nothing if the batcher is disabled.
  ///
  /// Example:
  /// ```dart
  /// final batcher = Batcher<String>(
  ///   (items) => print('Processing: $items'),
  ///   BatcherOptions<String>(maxSize: 3),
  /// );
  ///
  /// batcher.addItem('first');
  /// batcher.addItem('second');
  /// batcher.addItem('third'); // Triggers execution
  /// ```
  void addItem(T item) {
    if (!_options.enabled) {
      return;
    }

    _state = _state.copyWith(
      items: <T>[..._state.items, item],
      isEmpty: false,
      size: _state.size + 1,
    );

    _options.onItemsChange?.call(_state.items);

    notifyListeners();

    if (_shouldExecute()) {
      execute();
    } else if (_options.wait != null && !_state.isPending) {
      _scheduleExecute();
    }
  }

  /// Internal method to determine if the batch should execute now.
  bool _shouldExecute() {
    if (_options.getShouldExecute != null) {
      return _options.getShouldExecute!(_state.items);
    }

    return _options.maxSize != null && _state.size >= _options.maxSize!;
  }

  /// Internal method to schedule delayed batch execution.
  void _scheduleExecute() {
    _state = _state.copyWith(isPending: true, status: PacerStatus.pending);

    notifyListeners();

    _batchTimer = Timer(_options.wait!, execute);
  }

  /// Immediately executes the batch with all currently accumulated items.
  ///
  /// Cancels any pending timer and processes all items in the batch.
  /// The batch is cleared before execution begins, so new items added during
  /// execution will be part of the next batch.
  ///
  /// Does nothing if the batch is empty.
  ///
  /// Example:
  /// ```dart
  /// final batcher = Batcher<String>(
  ///   (items) => processItems(items),
  ///   BatcherOptions<String>(wait: Duration(minutes: 5)),
  /// );
  ///
  /// batcher.addItem('data1');
  /// batcher.addItem('data2');
  /// // Don't want to wait 5 minutes
  /// batcher.execute(); // Process immediately
  /// ```
  void execute() {
    if (_state.items.isEmpty) {
      return;
    }

    _batchTimer?.cancel();

    final itemsToExecute = List<T>.from(_state.items);

    _state = _state.copyWith(
      items: <T>[],
      isEmpty: true,
      isPending: false,
      size: 0,
      status: PacerStatus.idle,
    );

    notifyListeners();

    _options.onExecute?.call(itemsToExecute);

    notifyListeners();
  }

  /// Stops any pending batch execution without processing items.
  ///
  /// Cancels the execution timer if one is active. Items remain in the batch
  /// and can be executed later with [execute] or [flush].
  ///
  /// Example:
  /// ```dart
  /// batcher.addItem('data');
  /// // Timer is counting down...
  /// batcher.stop(); // Cancel the timer
  /// // Item still in batch, can call flush() to process
  /// ```
  void stop() {
    _batchTimer?.cancel();
    _state = _state.copyWith(isPending: false, status: PacerStatus.idle);

    notifyListeners();
  }

  /// Executes the batch immediately if it contains any items.
  ///
  /// This is a convenience method that calls [execute] only if the batch is not empty.
  /// Useful for ensuring all pending items are processed before shutdown or transition.
  ///
  /// Example:
  /// ```dart
  /// // Before closing the app, process any remaining items
  /// @override
  /// void dispose() {
  ///   batcher.flush();
  ///   batcher.dispose();
  ///   super.dispose();
  /// }
  /// ```
  void flush() {
    if (_state.items.isNotEmpty) {
      execute();
    }
  }

  /// Returns a copy of all items currently in the batch without executing.
  ///
  /// This allows inspection of the batch contents without triggering execution
  /// or modifying the batch state.
  ///
  /// Example:
  /// ```dart
  /// batcher.addItem('item1');
  /// batcher.addItem('item2');
  /// final items = batcher.peekAllItems();
  /// print('Current batch: $items'); // [item1, item2]
  /// ```
  List<T> peekAllItems() => _state.items;

  /// Updates the batcher configuration with new options.
  ///
  /// Applies the new options immediately. If the new options disable the batcher,
  /// any pending execution is stopped and the status is set to disabled. Otherwise,
  /// the status is set to idle.
  ///
  /// This allows dynamic reconfiguration of batch size limits, timing, and callbacks
  /// without recreating the batcher.
  ///
  /// Example:
  /// ```dart
  /// final batcher = Batcher<int>(
  ///   (items) => sum(items),
  ///   BatcherOptions<int>(maxSize: 5),
  /// );
  ///
  /// // Later, change the batch size
  /// batcher.setOptions(
  ///   BatcherOptions<int>(
  ///     maxSize: 10,
  ///     wait: Duration(seconds: 3),
  ///   ),
  /// );
  /// ```
  void setOptions(BatcherOptions<T> options) {
    _options = options;

    if (!_options.enabled) {
      stop();
      _state = _state.copyWith(status: PacerStatus.disabled);
    } else {
      _state = _state.copyWith(status: PacerStatus.idle);
    }
    
    notifyListeners();
  }
}
