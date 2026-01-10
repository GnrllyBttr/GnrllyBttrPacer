// 🎯 Dart imports:
import 'dart:async';

// 🐦 Flutter imports:
import 'package:flutter/foundation.dart';

// 🌎 Project imports:
import 'package:gnrllybttr_pacer/src/batcher/models.dart';
import 'package:gnrllybttr_pacer/src/common/common.dart';

/// A batch processor that accumulates items and executes them together.
///
/// [AsyncBatcher] collects items over time or until a size threshold is reached,
/// then processes them as a single batch. This is useful for optimizing operations
/// that benefit from bulk processing, such as network requests or database writes.
///
/// The batcher can be configured to execute based on:
/// - Maximum batch size ([AsyncBatcherOptions.maxSize])
/// - Time duration ([AsyncBatcherOptions.wait])
/// - Custom condition ([AsyncBatcherOptions.getShouldExecute])
/// - Manual trigger ([execute])
///
/// ## Features
///
/// - Automatic batching based on size or time
/// - Manual flush and execution control
/// - Comprehensive state tracking and statistics
/// - Error handling with optional error propagation
/// - Integration with Flutter's [ChangeNotifier] for reactive UI updates
///
/// ## Example: Basic Usage
///
/// ```dart
/// // Create a batcher that processes up to 5 items or waits 2 seconds
/// final batcher = AsyncBatcher<String>(
///   (items) async {
///     print('Processing batch: $items');
///     await Future.delayed(Duration(milliseconds: 500));
///     return 'Processed ${items.length} items';
///   },
///   AsyncBatcherOptions<String>(
///     maxSize: 5,
///     wait: Duration(seconds: 2),
///     onSuccess: (result) => print('Success: $result'),
///   ),
/// );
///
/// // Add items to the batch
/// await batcher.addItem('item1');
/// await batcher.addItem('item2');
/// await batcher.addItem('item3');
/// // Batch executes after 2 seconds or when 5 items are added
/// ```
///
/// ## Example: With Flutter Widget
///
/// ```dart
/// class BatcherWidget extends StatefulWidget {
///   @override
///   _BatcherWidgetState createState() => _BatcherWidgetState();
/// }
///
/// class _BatcherWidgetState extends State<BatcherWidget> {
///   late AsyncBatcher<String> batcher;
///
///   @override
///   void initState() {
///     super.initState();
///     batcher = AsyncBatcher<String>(
///       (items) async => uploadToServer(items),
///       AsyncBatcherOptions<String>(
///         maxSize: 10,
///         wait: Duration(seconds: 3),
///       ),
///     );
///     batcher.addListener(() => setState(() {}));
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return Column(
///       children: [
///         Text('Items in batch: ${batcher.state.size}'),
///         Text('Total processed: ${batcher.state.totalItemsProcessed}'),
///         ElevatedButton(
///           onPressed: () => batcher.addItem('data'),
///           child: Text('Add Item'),
///         ),
///         ElevatedButton(
///           onPressed: () => batcher.flush(),
///           child: Text('Flush Now'),
///         ),
///       ],
///     );
///   }
///
///   @override
///   void dispose() {
///     batcher.dispose();
///     super.dispose();
///   }
/// }
/// ```
///
/// ## Example: Error Handling
///
/// ```dart
/// final batcher = AsyncBatcher<int>(
///   (items) async {
///     if (items.any((item) => item < 0)) {
///       throw Exception('Negative numbers not allowed');
///     }
///     return items.reduce((a, b) => a + b);
///   },
///   AsyncBatcherOptions<int>(
///     maxSize: 5,
///     throwOnError: true,
///     onError: (error) => print('Error: $error'),
///     onSettled: (result, error) {
///       if (error != null) {
///         print('Batch failed');
///       } else {
///         print('Batch succeeded with result: $result');
///       }
///     },
///   ),
/// );
///
/// try {
///   await batcher.addItem(5);
///   await batcher.addItem(-1); // Will trigger error
/// } catch (e) {
///   print('Caught error: $e');
/// }
/// ```
///
/// ## Example: Custom Execution Condition
///
/// ```dart
/// final batcher = AsyncBatcher<Map<String, dynamic>>(
///   (items) async => saveToDatabase(items),
///   AsyncBatcherOptions<Map<String, dynamic>>(
///     // Execute when high-priority items exist
///     getShouldExecute: (items) {
///       return items.any((item) => item['priority'] == 'high');
///     },
///     wait: Duration(seconds: 5), // Fallback timeout
///     onItemsChange: (items) {
///       print('Current batch has ${items.length} items');
///     },
///   ),
/// );
///
/// await batcher.addItem({'priority': 'low', 'data': 'A'});
/// await batcher.addItem({'priority': 'high', 'data': 'B'}); // Triggers immediate execution
/// ```
class AsyncBatcher<T> extends ChangeNotifier {
  /// Creates an [AsyncBatcher] with the given batch processing function and options.
  ///
  /// The [fn] parameter is called with the accumulated items when the batch executes.
  /// The [options] parameter configures batch behavior, timing, and callbacks.
  ///
  /// Example:
  /// ```dart
  /// final batcher = AsyncBatcher<String>(
  ///   (items) async => processItems(items),
  ///   AsyncBatcherOptions<String>(
  ///     maxSize: 10,
  ///     wait: Duration(seconds: 2),
  ///   ),
  /// );
  /// ```
  AsyncBatcher(this.fn, AsyncBatcherOptions<T> options)
      : _options = options,
        _state = const AsyncBatcherState() {
    if (!_options.enabled) {
      _state = _state.copyWith(status: PacerStatus.disabled);
    }
  }

  /// The function to execute when processing a batch of items.
  final AnyAsyncFunction fn;

  AsyncBatcherOptions<T> _options;
  AsyncBatcherState<T> _state;
  Timer? _batchTimer;
  Completer<List<T>>? _completer;
  bool _aborted = false;

  /// The current configuration options for this batcher.
  AsyncBatcherOptions<T> get options => _options;

  /// The current state of this batcher, including accumulated items and statistics.
  AsyncBatcherState<T> get state => _state;

  /// Adds an item to the batch and potentially triggers execution.
  ///
  /// The item is added to the batch immediately. If the batch should execute
  /// (based on [AsyncBatcherOptions.maxSize], [AsyncBatcherOptions.getShouldExecute],
  /// or other conditions), execution begins immediately. Otherwise, a timer is
  /// started (if [AsyncBatcherOptions.wait] is set) to execute the batch later.
  ///
  /// Returns a [Future] that completes when the batch containing this item is executed.
  /// The future resolves to the list of items that were processed in the batch.
  ///
  /// Throws an [Exception] if the batcher is disabled.
  /// May throw if [AsyncBatcherOptions.throwOnError] is true and execution fails.
  ///
  /// Example:
  /// ```dart
  /// final batcher = AsyncBatcher<String>(
  ///   (items) async => print('Processing: $items'),
  ///   AsyncBatcherOptions<String>(maxSize: 3),
  /// );
  ///
  /// await batcher.addItem('first');
  /// await batcher.addItem('second');
  /// await batcher.addItem('third'); // Triggers execution
  /// ```
  Future<dynamic> addItem(T item) async {
    if (!_options.enabled) {
      throw Exception('Batcher is disabled');
    }

    _completer = Completer<List<T>>();

    _state = _state.copyWith(
      items: [..._state.items, item],
      isEmpty: false,
      size: _state.size + 1,
    );
    _options.onItemsChange?.call(_state.items);

    notifyListeners();

    if (_shouldExecute()) {
      return execute();
    } else if (_options.wait != null && !_state.isPending) {
      _scheduleExecute();
    }

    return _completer!.future;
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

    _batchTimer = Timer(
      _options.wait!,
      () => execute().then((result) {
        if (_completer != null && !_completer!.isCompleted) {
          _completer!.complete(result);
        }
      }).catchError((Object e) {
        if (_completer != null && !_completer!.isCompleted) {
          _completer!.completeError(e);
        }
      }),
    );
  }

  /// Immediately executes the batch with all currently accumulated items.
  ///
  /// Cancels any pending timer and processes all items in the batch.
  /// The batch is cleared before execution begins, so new items added during
  /// execution will be part of the next batch.
  ///
  /// Returns a [Future] that completes with the list of items that were processed.
  /// Returns an empty list if the batch was empty.
  ///
  /// This method updates [state] to reflect execution status and results.
  /// Callbacks [onExecute], [onSuccess], [onError], and [onSettled] are invoked
  /// as appropriate during execution.
  ///
  /// Throws if [AsyncBatcherOptions.throwOnError] is true and the batch function throws.
  ///
  /// Example:
  /// ```dart
  /// final batcher = AsyncBatcher<String>(
  ///   (items) async => uploadItems(items),
  ///   AsyncBatcherOptions<String>(wait: Duration(minutes: 5)),
  /// );
  ///
  /// await batcher.addItem('data1');
  /// await batcher.addItem('data2');
  /// // Don't want to wait 5 minutes
  /// await batcher.execute(); // Process immediately
  /// ```
  Future<List<T>> execute() async {
    if (_state.items.isEmpty) {
      return <T>[];
    }

    _batchTimer?.cancel();

    final itemsToExecute = List<T>.from(_state.items);

    _state = _state.copyWith(
      items: <T>[],
      isEmpty: true,
      isPending: false,
      size: 0,
      status: PacerStatus.executing,
      isExecuting: true,
    );
    notifyListeners();

    try {
      final result = await fn(itemsToExecute);

      if (!_aborted) {
        _options.onExecute?.call(itemsToExecute);
        _options.onSuccess?.call(result);
        _state = _state.copyWith(
          executionCount: _state.executionCount + 1,
          successCount: _state.successCount + 1,
          settleCount: _state.settleCount + 1,
          lastResult: result,
          totalItemsProcessed:
              _state.totalItemsProcessed + itemsToExecute.length,
          isExecuting: false,
          status: PacerStatus.idle,
        );

        if (_completer != null && !_completer!.isCompleted) {
          _completer!.complete(itemsToExecute);
        }
        
        return itemsToExecute;
      } else {
        throw Exception('Aborted');
      }
    } catch (e) {
      if (!_aborted) {
        _options.onError?.call(e);
        _state = _state.copyWith(
          errorCount: _state.errorCount + 1,
          settleCount: _state.settleCount + 1,
          failedItems: [..._state.failedItems, ...itemsToExecute],
          isExecuting: false,
          status: PacerStatus.idle,
        );

        if (_options.throwOnError) {
          if (_completer != null && !_completer!.isCompleted) {
            _completer!.completeError(e);
          }
        
          rethrow;
        } else {
          if (_completer != null && !_completer!.isCompleted) {
            _completer!.complete(<T>[]);
          }
        
          return <T>[];
        }
      } else {
        throw Exception('Aborted');
      }
    } finally {
      _options.onSettled?.call(_state.lastResult, null);
      notifyListeners();
    }
  }

  /// Stops any pending batch execution without processing items.
  ///
  /// Cancels the execution timer if one is active. Items remain in the batch
  /// and can be executed later with [execute] or [flush].
  ///
  /// Example:
  /// ```dart
  /// await batcher.addItem('data');
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
  /// await batcher.addItem('item1');
  /// await batcher.addItem('item2');
  /// final items = batcher.peekAllItems();
  /// print('Current batch: $items'); // [item1, item2]
  /// ```
  List<T> peekAllItems() => _state.items;

  /// Aborts the batcher, canceling any pending execution and clearing state.
  ///
  /// Cancels the execution timer, sets the status to idle, and completes any
  /// pending futures with an error. The batch items are preserved but will not
  /// be automatically executed.
  ///
  /// Call this method to stop all batcher activity, typically before disposal
  /// or when the batcher is no longer needed.
  ///
  /// Example:
  /// ```dart
  /// final batcher = AsyncBatcher<String>(
  ///   (items) async => processItems(items),
  ///   AsyncBatcherOptions<String>(wait: Duration(seconds: 10)),
  /// );
  ///
  /// await batcher.addItem('data');
  /// // Something went wrong, cancel everything
  /// batcher.abort();
  /// ```
  void abort() {
    _aborted = true;
    _batchTimer?.cancel();
    _state = _state.copyWith(status: PacerStatus.idle);

    if (_completer != null && !_completer!.isCompleted) {
      _completer!.completeError('Aborted');
    }
    
    notifyListeners();
  }

  /// Updates the batcher configuration with new options.
  ///
  /// Applies the new options immediately. If the new options disable the batcher
  /// ([AsyncBatcherOptions.enabled] is false), the batcher is aborted and its
  /// status set to disabled. Otherwise, the status is set to idle.
  ///
  /// This allows dynamic reconfiguration of batch size limits, timing, and callbacks
  /// without recreating the batcher.
  ///
  /// Example:
  /// ```dart
  /// final batcher = AsyncBatcher<int>(
  ///   (items) async => sum(items),
  ///   AsyncBatcherOptions<int>(maxSize: 5),
  /// );
  ///
  /// // Later, change the batch size
  /// batcher.setOptions(
  ///   AsyncBatcherOptions<int>(
  ///     maxSize: 10,
  ///     wait: Duration(seconds: 3),
  ///   ),
  /// );
  /// ```
  void setOptions(AsyncBatcherOptions<T> options) {
    _options = options;

    if (!_options.enabled) {
      abort();
      _state = _state.copyWith(status: PacerStatus.disabled);
    } else {
      _state = _state.copyWith(status: PacerStatus.idle);
    }
    
    notifyListeners();
  }
}
