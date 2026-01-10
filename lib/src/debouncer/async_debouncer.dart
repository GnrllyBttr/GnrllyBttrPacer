// 🎯 Dart imports:
import 'dart:async';

// 🐦 Flutter imports:
import 'package:flutter/foundation.dart';

// 🌎 Project imports:
import 'package:gnrllybttr_pacer/src/common/common.dart';
import 'package:gnrllybttr_pacer/src/debouncer/models.dart';

/// Debounces function execution, delaying invocation until after a specified wait period.
///
/// [AsyncDebouncer] delays executing a function until a specified amount of time has passed
/// since the last time it was invoked. This is useful for limiting the rate of execution
/// for frequently triggered events like search input, window resizing, or scroll events.
///
/// The debouncer can execute on the leading edge (immediately on first call), trailing edge
/// (after the wait period), or both, depending on configuration.
///
/// ## Features
///
/// - Leading and/or trailing execution modes
/// - Automatic timer management
/// - Comprehensive state tracking and statistics
/// - Error handling with optional error propagation
/// - Integration with Flutter's [ChangeNotifier] for reactive UI updates
///
/// ## Example: Search Input Debouncing
///
/// ```dart
/// class SearchWidget extends StatefulWidget {
///   @override
///   _SearchWidgetState createState() => _SearchWidgetState();
/// }
///
/// class _SearchWidgetState extends State<SearchWidget> {
///   late AsyncDebouncer<String> searchDebouncer;
///
///   @override
///   void initState() {
///     super.initState();
///     searchDebouncer = AsyncDebouncer<String>(
///       (query) async {
///         final results = await searchAPI(query);
///         return results;
///       },
///       AsyncDebouncerOptions<String>(
///         wait: Duration(milliseconds: 500),
///         trailing: true,
///         onSuccess: (results) => setState(() {
///           // Update UI with search results
///         }),
///       ),
///     );
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return TextField(
///       onChanged: (value) => searchDebouncer.maybeExecute(value),
///       decoration: InputDecoration(
///         hintText: 'Search...',
///         suffixIcon: searchDebouncer.state.isPending
///             ? CircularProgressIndicator()
///             : Icon(Icons.search),
///       ),
///     );
///   }
///
///   @override
///   void dispose() {
///     searchDebouncer.dispose();
///     super.dispose();
///   }
/// }
/// ```
///
/// ## Example: Leading Edge Execution
///
/// ```dart
/// // Execute immediately on first call, then wait for quiet period
/// final debouncer = AsyncDebouncer<int>(
///   (value) async {
///     print('Processing: $value');
///     await Future.delayed(Duration(milliseconds: 100));
///     return value * 2;
///   },
///   AsyncDebouncerOptions<int>(
///     wait: Duration(seconds: 2),
///     leading: true,
///     trailing: false,
///   ),
/// );
///
/// await debouncer.maybeExecute(1); // Executes immediately
/// await debouncer.maybeExecute(2); // Ignored (within wait period)
/// await debouncer.maybeExecute(3); // Ignored (within wait period)
/// // After 2 seconds of no calls, next call will execute immediately
/// ```
///
/// ## Example: Both Leading and Trailing
///
/// ```dart
/// final debouncer = AsyncDebouncer<String>(
///   (text) async => saveToServer(text),
///   AsyncDebouncerOptions<String>(
///     wait: Duration(milliseconds: 1000),
///     leading: true,  // Execute immediately on first call
///     trailing: true, // Also execute after quiet period
///     onExecute: (text) => print('Saving: $text'),
///   ),
/// );
///
/// await debouncer.maybeExecute('H');      // Executes immediately (leading)
/// await debouncer.maybeExecute('He');     // Resets timer
/// await debouncer.maybeExecute('Hel');    // Resets timer
/// await debouncer.maybeExecute('Hello');  // Resets timer
/// // After 1 second: executes with 'Hello' (trailing)
/// ```
///
/// ## Example: Error Handling
///
/// ```dart
/// final debouncer = AsyncDebouncer<Map<String, dynamic>>(
///   (data) async {
///     if (!data.containsKey('required')) {
///       throw Exception('Missing required field');
///     }
///     return await submitForm(data);
///   },
///   AsyncDebouncerOptions<Map<String, dynamic>>(
///     wait: Duration(milliseconds: 500),
///     throwOnError: true,
///     onError: (error) => print('Error: $error'),
///     onSettled: (result, error) {
///       if (error != null) {
///         showErrorSnackbar();
///       } else {
///         showSuccessSnackbar();
///       }
///     },
///   ),
/// );
///
/// try {
///   await debouncer.maybeExecute({'data': 'value'});
/// } catch (e) {
///   print('Caught: $e');
/// }
/// ```
///
/// ## Example: Manual Control
///
/// ```dart
/// final debouncer = AsyncDebouncer<String>(
///   (text) async => processText(text),
///   AsyncDebouncerOptions<String>(wait: Duration(seconds: 5)),
/// );
///
/// await debouncer.maybeExecute('typing...');
/// await debouncer.maybeExecute('still typing...');
///
/// // User clicks "Save" button - execute immediately
/// debouncer.flush();
///
/// // User navigates away - cancel pending execution
/// debouncer.cancel();
/// ```
class AsyncDebouncer<T> extends ChangeNotifier {
  /// Creates an [AsyncDebouncer] with the given function and options.
  ///
  /// The [fn] parameter is called when the debounce period completes.
  /// The [options] parameter configures debouncing behavior and callbacks.
  ///
  /// Example:
  /// ```dart
  /// final debouncer = AsyncDebouncer<String>(
  ///   (query) async => searchDatabase(query),
  ///   AsyncDebouncerOptions<String>(
  ///     wait: Duration(milliseconds: 300),
  ///     trailing: true,
  ///   ),
  /// );
  /// ```
  AsyncDebouncer(this.fn, AsyncDebouncerOptions<T> options)
      : _options = options,
        _state = AsyncDebouncerState() {
    if (!_options.enabled) {
      _state = _state.copyWith(status: PacerStatus.disabled);
    }
  }

  /// The function to execute when the debounce period completes.
  final AnyAsyncFunction fn;

  AsyncDebouncerOptions<T> _options;
  AsyncDebouncerState<T> _state;
  Timer? _timer;
  Completer<T?>? _completer;
  bool _leadingExecuted = false;
  bool _aborted = false;

  /// The current configuration options for this debouncer.
  AsyncDebouncerOptions<T> get options => _options;

  /// The current state of this debouncer, including pending status and statistics.
  AsyncDebouncerState<T> get state => _state;

  /// Attempts to execute the debounced function with the given arguments.
  ///
  /// Each call to [maybeExecute] resets the internal timer. The function will only
  /// execute based on the [leading] and [trailing] options:
  /// - If [leading] is true: executes immediately on the first call in a series
  /// - If [trailing] is true: executes after [wait] duration of no calls
  ///
  /// Returns a [Future] that completes when execution finishes (or is aborted).
  /// The future resolves to the result of the function, or null if an error occurred
  /// and [throwOnError] is false.
  ///
  /// Throws an [Exception] if the debouncer is disabled.
  /// May throw if [throwOnError] is true and execution fails.
  ///
  /// Example:
  /// ```dart
  /// final debouncer = AsyncDebouncer<String>(
  ///   (text) async => saveData(text),
  ///   AsyncDebouncerOptions<String>(
  ///     wait: Duration(milliseconds: 500),
  ///     trailing: true,
  ///   ),
  /// );
  ///
  /// // Each call resets the timer
  /// await debouncer.maybeExecute('a');
  /// await debouncer.maybeExecute('ab');
  /// await debouncer.maybeExecute('abc');
  /// // Executes once with 'abc' after 500ms of no calls
  /// ```
  Future<T?> maybeExecute(T args) {
    if (!_options.enabled) {
      throw Exception('Debouncer is disabled');
    }

    _state = _state.copyWith(
      maybeExecuteCount: _state.maybeExecuteCount + 1,
      lastArgs: args,
      isPending: true,
      status: PacerStatus.pending,
    );

    notifyListeners();

    _timer?.cancel();
    _completer = Completer<T?>();
    _aborted = false;

    if (_options.leading && !_leadingExecuted) {
      _executeAsync(args);
      _leadingExecuted = true;
    } else {
      _timer = Timer(_options.wait, () {
        if (_options.trailing && !_aborted) {
          _executeAsync(args);
        } else {
          _state = _state.copyWith(isPending: false, status: PacerStatus.idle);
          _leadingExecuted = false;

          if (!_completer!.isCompleted) {
            _completer!.completeError('Aborted');
          }

          notifyListeners();
        }
      });
    }

    return _completer!.future;
  }

  /// Internal method to execute the debounced function.
  Future<void> _executeAsync(T args) async {
    _state = _state.copyWith(isExecuting: true, status: PacerStatus.executing);

    notifyListeners();

    try {
      final result = await fn(args);

      if (!_aborted) {
        _options.onExecute?.call(args);
        _options.onSuccess?.call(result);
        _state = _state.copyWith(
          executionCount: _state.executionCount + 1,
          successCount: _state.successCount + 1,
          settleCount: _state.settleCount + 1,
          lastResult: result,
          isExecuting: false,
          isPending: false,
          status: PacerStatus.idle,
        );
        _leadingExecuted = false;
        _completer!.complete(result as T?);
      }
    } catch (e) {
      if (!_aborted) {
        _options.onError?.call(e);
        _state = _state.copyWith(
          errorCount: _state.errorCount + 1,
          settleCount: _state.settleCount + 1,
          isExecuting: false,
          isPending: false,
          status: PacerStatus.idle,
        );

        _leadingExecuted = false;
        
        if (_options.throwOnError) {
          _completer!.completeError(e);
        } else {
          _completer!.complete(null);
        }
      }
    } finally {
      _options.onSettled?.call(_state.lastResult, null);

      notifyListeners();
    }
  }

  /// Aborts any pending execution and resets the debouncer.
  ///
  /// Cancels the internal timer and completes any pending futures with an error.
  /// The debouncer returns to idle state and can be used again immediately.
  ///
  /// Example:
  /// ```dart
  /// await debouncer.maybeExecute('data');
  /// // Timer is counting down...
  /// debouncer.abort(); // Cancel the pending execution
  /// ```
  void abort() {
    _aborted = true;
    _timer?.cancel();
    _state = _state.copyWith(isPending: false, status: PacerStatus.idle);

    if (_completer != null && !_completer!.isCompleted) {
      _completer!.completeError('Aborted');
    }

    notifyListeners();
  }

  /// Alias for [abort]. Cancels any pending execution.
  ///
  /// Identical to calling [abort]. Provided for convenience and API consistency.
  void cancel() {
    abort();
  }

  /// Immediately executes any pending debounced call.
  ///
  /// If there is a pending execution (timer active) and [trailing] is true,
  /// cancels the timer and executes immediately with the last arguments.
  /// Does nothing if no execution is pending.
  ///
  /// Useful when you want to force immediate execution, such as when a user
  /// clicks a "Submit" button or navigates away from a form.
  ///
  /// Example:
  /// ```dart
  /// final debouncer = AsyncDebouncer<String>(
  ///   (text) async => saveForm(text),
  ///   AsyncDebouncerOptions<String>(
  ///     wait: Duration(seconds: 3),
  ///     trailing: true,
  ///   ),
  /// );
  ///
  /// await debouncer.maybeExecute('user input');
  /// // Timer is counting down...
  ///
  /// // User clicks "Save Now" button
  /// debouncer.flush(); // Executes immediately instead of waiting
  /// ```
  void flush() {
    if (_state.isPending && _options.trailing && _state.lastArgs != null) {
      _timer?.cancel();
      _executeAsync(_state.lastArgs as T);
    }
  }

  /// Updates the debouncer configuration with new options.
  ///
  /// Applies the new options immediately. If the new options disable the debouncer
  /// ([AsyncDebouncerOptions.enabled] is false), any pending execution is aborted
  /// and the status is set to disabled. Otherwise, the status is set to idle.
  ///
  /// This allows dynamic reconfiguration of wait duration, execution modes, and
  /// callbacks without recreating the debouncer.
  ///
  /// Example:
  /// ```dart
  /// final debouncer = AsyncDebouncer<String>(
  ///   (text) async => process(text),
  ///   AsyncDebouncerOptions<String>(
  ///     wait: Duration(milliseconds: 500),
  ///   ),
  /// );
  ///
  /// // Later, change the wait duration
  /// debouncer.setOptions(
  ///   AsyncDebouncerOptions<String>(
  ///     wait: Duration(milliseconds: 1000),
  ///     leading: true, // Also enable leading execution
  ///   ),
  /// );
  /// ```
  void setOptions(AsyncDebouncerOptions<T> options) {
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
