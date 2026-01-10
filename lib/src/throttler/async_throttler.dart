// 🎯 Dart imports:
import 'dart:async';

// 🐦 Flutter imports:
import 'package:flutter/foundation.dart';

// 🌎 Project imports:
import 'package:gnrllybttr_pacer/src/common/common.dart';
import 'package:gnrllybttr_pacer/src/throttler/models.dart';

/// Throttles function execution, ensuring a minimum time interval between calls.
///
/// [AsyncThrottler] limits how often a function can execute by enforcing a minimum
/// wait period between invocations. Unlike debouncing (which delays execution),
/// throttling ensures the function runs at most once per time period, regardless
/// of how many times it's called.
///
/// This is ideal for limiting resource-intensive operations triggered by high-frequency
/// events like scrolling, mouse movement, or real-time data updates.
///
/// ## Features
///
/// - Leading and/or trailing execution modes
/// - Automatic timer management for trailing execution
/// - Comprehensive state tracking with timing information
/// - Error handling with optional error propagation
/// - Integration with Flutter's [ChangeNotifier]
///
/// ## Example: Scroll Event Throttling
///
/// ```dart
/// class ScrollableWidget extends StatefulWidget {
///   @override
///   _ScrollableWidgetState createState() => _ScrollableWidgetState();
/// }
///
/// class _ScrollableWidgetState extends State<ScrollableWidget> {
///   late AsyncThrottler<double> scrollThrottler;
///
///   @override
///   void initState() {
///     super.initState();
///     scrollThrottler = AsyncThrottler<double>(
///       (position) async {
///         await updateScrollPosition(position);
///         return position;
///       },
///       AsyncThrottlerOptions<double>(
///         wait: Duration(milliseconds: 200),
///         leading: true,  // Execute immediately on first scroll
///         trailing: true, // Execute again after scrolling stops
///       ),
///     );
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return ListView(
///       controller: ScrollController()
///         ..addListener(() {
///           scrollThrottler.maybeExecute(controller.position.pixels);
///         }),
///       children: [...],
///     );
///   }
///
///   @override
///   void dispose() {
///     scrollThrottler.dispose();
///     super.dispose();
///   }
/// }
/// ```
///
/// ## Example: Window Resize Throttling
///
/// ```dart
/// // Throttle expensive layout calculations during window resize
/// final resizeThrottler = AsyncThrottler<Size>(
///   (size) async {
///     await recalculateLayout(size);
///     await renderViewport(size);
///     return 'Layout updated';
///   },
///   AsyncThrottlerOptions<Size>(
///     wait: Duration(milliseconds: 100),
///     leading: true,
///     trailing: true,
///     onSuccess: (result) => print(result),
///   ),
/// );
///
/// // In your resize handler
/// void onWindowResize(Size newSize) {
///   resizeThrottler.maybeExecute(newSize);
/// }
/// ```
///
/// ## Example: Leading vs Trailing vs Both
///
/// ```dart
/// // Leading only: Execute immediately, ignore subsequent calls
/// final leadingOnly = AsyncThrottler<String>(
///   (text) async => saveData(text),
///   AsyncThrottlerOptions<String>(
///     wait: Duration(seconds: 2),
///     leading: true,
///     trailing: false,
///   ),
/// );
///
/// // Trailing only: Wait for quiet period, then execute once
/// final trailingOnly = AsyncThrottler<String>(
///   (text) async => saveData(text),
///   AsyncThrottlerOptions<String>(
///     wait: Duration(seconds: 2),
///     leading: false,
///     trailing: true,
///   ),
/// );
///
/// // Both: Execute immediately AND after throttle period
/// final both = AsyncThrottler<String>(
///   (text) async => saveData(text),
///   AsyncThrottlerOptions<String>(
///     wait: Duration(seconds: 2),
///     leading: true,
///     trailing: true,
///   ),
/// );
/// ```
///
/// ## Example: Real-time Search with Throttling
///
/// ```dart
/// class ThrottledSearch extends StatefulWidget {
///   @override
///   _ThrottledSearchState createState() => _ThrottledSearchState();
/// }
///
/// class _ThrottledSearchState extends State<ThrottledSearch> {
///   late AsyncThrottler<String> searchThrottler;
///   List<String> results = [];
///
///   @override
///   void initState() {
///     super.initState();
///     searchThrottler = AsyncThrottler<String>(
///       (query) async {
///         if (query.isEmpty) return [];
///         final searchResults = await searchAPI(query);
///         return searchResults;
///       },
///       AsyncThrottlerOptions<String>(
///         wait: Duration(milliseconds: 500),
///         leading: false,
///         trailing: true,
///         onSuccess: (results) {
///           setState(() {
///             this.results = results as List<String>;
///           });
///         },
///       ),
///     );
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return Column(
///       children: [
///         TextField(
///           onChanged: (value) => searchThrottler.maybeExecute(value),
///           decoration: InputDecoration(
///             hintText: 'Search...',
///             suffix: searchThrottler.state.isExecuting
///                 ? SizedBox(
///                     width: 16,
///                     height: 16,
///                     child: CircularProgressIndicator(strokeWidth: 2),
///                   )
///                 : Icon(Icons.search),
///           ),
///         ),
///         Expanded(
///           child: ListView.builder(
///             itemCount: results.length,
///             itemBuilder: (context, index) => ListTile(
///               title: Text(results[index]),
///             ),
///           ),
///         ),
///       ],
///     );
///   }
///
///   @override
///   void dispose() {
///     searchThrottler.dispose();
///     super.dispose();
///   }
/// }
/// ```
///
/// ## Example: Mouse Movement Tracking
///
/// ```dart
/// final mouseMoveThrottler = AsyncThrottler<Offset>(
///   (position) async {
///     await updateCursorPosition(position);
///     await checkHoverState(position);
///     return position;
///   },
///   AsyncThrottlerOptions<Offset>(
///     wait: Duration(milliseconds: 50), // Max 20 updates per second
///     leading: true,
///     trailing: false,
///   ),
/// );
///
/// Widget build(BuildContext context) {
///   return MouseRegion(
///     onHover: (event) {
///       mouseMoveThrottler.maybeExecute(event.position);
///     },
///     child: YourWidget(),
///   );
/// }
/// ```
///
/// ## Example: Auto-save with Throttling
///
/// ```dart
/// final autoSaveThrottler = AsyncThrottler<String>(
///   (content) async {
///     await saveToCloud(content);
///     return 'Saved at ${DateTime.now()}';
///   },
///   AsyncThrottlerOptions<String>(
///     wait: Duration(seconds: 5),
///     leading: false,
///     trailing: true,
///     onSuccess: (message) {
///       showSnackBar(message);
///     },
///     onError: (error) {
///       showError('Auto-save failed: $error');
///     },
///   ),
/// );
///
/// // In your text editor
/// TextField(
///   onChanged: (text) {
///     autoSaveThrottler.maybeExecute(text);
///   },
/// );
/// ```
class AsyncThrottler<T> extends ChangeNotifier {
  /// Creates an [AsyncThrottler] with the given function and options.
  ///
  /// The [fn] parameter is called when throttle conditions allow execution.
  /// The [options] parameter configures throttling behavior and callbacks.
  ///
  /// Example:
  /// ```dart
  /// final throttler = AsyncThrottler<double>(
  ///   (value) async => processValue(value),
  ///   AsyncThrottlerOptions<double>(
  ///     wait: Duration(milliseconds: 200),
  ///     leading: true,
  ///   ),
  /// );
  /// ```
  AsyncThrottler(this.fn, AsyncThrottlerOptions<T> options)
      : _options = options,
        _state = AsyncThrottlerState() {
    if (!_options.enabled) {
      _state = _state.copyWith(status: PacerStatus.disabled);
    }
  }

  /// The function to execute when throttle allows.
  final AnyAsyncFunction fn;

  AsyncThrottlerOptions<T> _options;
  AsyncThrottlerState<T> _state;
  Timer? _timer;
  Completer<T?>? _completer;
  bool _aborted = false;

  /// The current configuration options for this throttler.
  AsyncThrottlerOptions<T> get options => _options;

  /// The current state of this throttler, including timing and statistics.
  AsyncThrottlerState<T> get state => _state;

  /// Attempts to execute the throttled function with the given arguments.
  ///
  /// Execution behavior depends on the time since last execution and the
  /// [leading]/[trailing] configuration:
  /// - If enough time has passed since last execution: executes immediately (if [leading] is true)
  /// - If within throttle period and [trailing] is true: schedules execution for later
  /// - If within throttle period and [trailing] is false: throws an exception
  ///
  /// Returns a [Future] that completes when execution finishes. For trailing execution,
  /// the future completes after the wait period when the function actually runs.
  ///
  /// Throws an [Exception] if the throttler is disabled or if called within the
  /// throttle period when [trailing] is false.
  ///
  /// Example:
  /// ```dart
  /// final throttler = AsyncThrottler<String>(
  ///   (text) async => processText(text),
  ///   AsyncThrottlerOptions<String>(
  ///     wait: Duration(seconds: 1),
  ///     leading: true,
  ///     trailing: true,
  ///   ),
  /// );
  ///
  /// await throttler.maybeExecute('first');  // Executes immediately
  /// await throttler.maybeExecute('second'); // Scheduled for 1s later
  /// await throttler.maybeExecute('third');  // Replaces 'second', scheduled for 1s later
  /// ```
  Future<T?> maybeExecute(T args) {
    if (!_options.enabled) {
      throw Exception('Throttler is disabled');
    }

    final now = DateTime.now();
    final timeSinceLast = _state.lastExecutionTime != null
        ? now.difference(_state.lastExecutionTime!)
        : _options.wait;

    _state = _state.copyWith(
      maybeExecuteCount: _state.maybeExecuteCount + 1,
      lastArgs: args,
    );
    notifyListeners();

    if (timeSinceLast >= _options.wait) {
      _executeAsync(args, now);
      return _completer!.future;
    } else if (_options.trailing) {
      final remaining = _options.wait - timeSinceLast;
      _state = _state.copyWith(nextExecutionTime: now.add(remaining));
      _completer = Completer<T?>();
      _timer?.cancel();
      _timer = Timer(
        remaining,
        () => _executeAsync(args, DateTime.now()).then((result) {
          if (!_completer!.isCompleted) {
            _completer!.complete(result);
          }
        }).catchError((Object e) {
          if (!_completer!.isCompleted) {
            _completer!.completeError(e);
          }
        }),
      );
      return _completer!.future;
    } else {
      throw Exception('Cannot execute now');
    }
  }

  /// Internal method to execute the throttled function.
  Future<T?> _executeAsync(T args, DateTime executionTime) async {
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
          lastExecutionTime: executionTime,
          isExecuting: false,
        );
        return result as T?;
      } else {
        throw Exception('Aborted');
      }
    } catch (e) {
      if (!_aborted) {
        _options.onError?.call(e);
        _state = _state.copyWith(
          errorCount: _state.errorCount + 1,
          settleCount: _state.settleCount + 1,
          isExecuting: false,
        );
        if (_options.throwOnError) {
          _completer!.completeError(e);
        } else {
          _completer!.complete(null);
        }
      } else {
        throw Exception('Aborted');
      }
    } finally {
      _options.onSettled?.call(_state.lastResult, null);
      notifyListeners();
    }
    return null;
  }

  /// Aborts any pending throttled execution and resets the throttler.
  ///
  /// Cancels the internal timer and completes any pending futures with an error.
  /// The throttler returns to idle state and can be used again immediately.
  ///
  /// Example:
  /// ```dart
  /// await throttler.maybeExecute('data');
  /// // Timer is counting down...
  /// throttler.abort(); // Cancel the pending execution
  /// ```
  void abort() {
    _aborted = true;
    _timer?.cancel();
    _state = _state.copyWith();
    if (_completer != null && !_completer!.isCompleted) {
      _completer!.completeError('Aborted');
    }
    notifyListeners();
  }

  /// Alias for [abort]. Cancels any pending throttled execution.
  ///
  /// Identical to calling [abort]. Provided for convenience and API consistency.
  void cancel() {
    abort();
  }

  /// Immediately executes any pending throttled call.
  ///
  /// If there is a pending trailing execution scheduled, cancels the timer
  /// and executes immediately with the last arguments. Does nothing if no
  /// execution is pending.
  ///
  /// Useful when you want to force immediate execution, such as when a user
  /// completes an action or navigates away.
  ///
  /// Example:
  /// ```dart
  /// final throttler = AsyncThrottler<String>(
  ///   (text) async => saveData(text),
  ///   AsyncThrottlerOptions<String>(
  ///     wait: Duration(seconds: 2),
  ///     leading: false,
  ///     trailing: true,
  ///   ),
  /// );
  ///
  /// await throttler.maybeExecute('user input');
  /// // Timer is counting down...
  ///
  /// // User clicks "Save Now" button
  /// throttler.flush(); // Execute immediately instead of waiting
  /// ```
  void flush() {
    if (_state.nextExecutionTime != null && _state.lastArgs != null) {
      _timer?.cancel();
      _executeAsync(_state.lastArgs as T, DateTime.now()).then((result) {
        if (_completer != null && !_completer!.isCompleted) {
          _completer!.complete(result);
        }
      }).catchError((Object e) {
        if (_completer != null && !_completer!.isCompleted) {
          _completer!.completeError(e);
        }
      });
    }
  }

  /// Updates the throttler configuration with new options.
  ///
  /// Applies the new options immediately. If the new options disable the throttler,
  /// any pending execution is aborted and the status is set to disabled. Otherwise,
  /// the status is set to idle.
  ///
  /// This allows dynamic reconfiguration of wait duration and execution modes
  /// without recreating the throttler.
  ///
  /// Example:
  /// ```dart
  /// final throttler = AsyncThrottler<String>(
  ///   (text) async => process(text),
  ///   AsyncThrottlerOptions<String>(
  ///     wait: Duration(milliseconds: 200),
  ///   ),
  /// );
  ///
  /// // Later, change the throttle interval
  /// throttler.setOptions(
  ///   AsyncThrottlerOptions<String>(
  ///     wait: Duration(milliseconds: 500),
  ///     leading: true,
  ///     trailing: false,
  ///   ),
  /// );
  /// ```
  void setOptions(AsyncThrottlerOptions<T> options) {
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
