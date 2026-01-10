// 🎯 Dart imports:
import 'dart:async';

// 🐦 Flutter imports:
import 'package:flutter/foundation.dart';

// 🌎 Project imports:
import 'package:gnrllybttr_pacer/src/common/common.dart';
import 'package:gnrllybttr_pacer/src/rate_limiter/models.dart';

/// Limits the rate of function execution to a maximum number within a time window.
///
/// [AsyncRateLimiter] enforces rate limits by tracking execution history and
/// rejecting calls that would exceed the configured limit within the time window.
/// This is essential for API rate limiting, preventing abuse, and managing resource
/// consumption.
///
/// The rate limiter supports two window types:
/// - Fixed: Resets at regular intervals (e.g., 100 requests per minute)
/// - Sliding: Continuously evaluates based on recent execution history
///
/// ## Features
///
/// - Fixed and sliding window rate limiting
/// - Execution rejection with callbacks
/// - Automatic window cleanup
/// - Detailed statistics and remaining capacity tracking
/// - Error handling with optional error propagation
/// - Integration with Flutter's [ChangeNotifier]
///
/// ## Example: API Rate Limiting (Fixed Window)
///
/// ```dart
/// // Allow 100 API calls per minute
/// final apiLimiter = AsyncRateLimiter<ApiRequest>(
///   (request) async {
///     final response = await http.get(request.url);
///     return response.data;
///   },
///   AsyncRateLimiterOptions<ApiRequest>(
///     limit: 100,
///     window: Duration(minutes: 1),
///     windowType: WindowType.fixed,
///     onReject: (request) {
///       print('Rate limit exceeded, request rejected');
///       showRateLimitError();
///     },
///   ),
/// );
///
/// // Make API calls
/// try {
///   final result = await apiLimiter.maybeExecute(ApiRequest('https://...'));
///   print('API response: $result');
/// } catch (e) {
///   // Rate limit exceeded or other error
/// }
/// ```
///
/// ## Example: With Flutter Widget
///
/// ```dart
/// class RateLimitedButton extends StatefulWidget {
///   @override
///   _RateLimitedButtonState createState() => _RateLimitedButtonState();
/// }
///
/// class _RateLimitedButtonState extends State<RateLimitedButton> {
///   late AsyncRateLimiter<void> clickLimiter;
///
///   @override
///   void initState() {
///     super.initState();
///     clickLimiter = AsyncRateLimiter<void>(
///       (_) async => await performAction(),
///       AsyncRateLimiterOptions<void>(
///         limit: 3,
///         window: Duration(seconds: 10),
///         onReject: (_) {
///           ScaffoldMessenger.of(context).showSnackBar(
///             SnackBar(content: Text('Too many clicks! Please wait.')),
///           );
///         },
///       ),
///     );
///     clickLimiter.addListener(() => setState(() {}));
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     final remaining = clickLimiter.getRemainingInWindow();
///     return Column(
///       children: [
///         ElevatedButton(
///           onPressed: () => clickLimiter.maybeExecute(null),
///           child: Text('Action ($remaining remaining)'),
///         ),
///         if (clickLimiter.state.isExceeded)
///           Text('Rate limit exceeded. Wait ${clickLimiter.getMsUntilNextWindow().inSeconds}s'),
///       ],
///     );
///   }
///
///   @override
///   void dispose() {
///     clickLimiter.dispose();
///     super.dispose();
///   }
/// }
/// ```
///
/// ## Example: Sliding Window Rate Limiting
///
/// ```dart
/// // More strict: Limit based on last execution, not fixed intervals
/// final slidingLimiter = AsyncRateLimiter<String>(
///   (data) async => uploadData(data),
///   AsyncRateLimiterOptions<String>(
///     limit: 10,
///     window: Duration(seconds: 60),
///     windowType: WindowType.sliding, // Uses time of last execution
///     onSuccess: (result) => print('Upload complete'),
///     onReject: (data) => print('Upload rate limit exceeded'),
///   ),
/// );
///
/// // Each execution starts a new 60-second window
/// for (int i = 0; i < 15; i++) {
///   final result = await slidingLimiter.maybeExecute('data_$i');
///   if (result == null) {
///     print('Request $i was rejected');
///   }
/// }
/// ```
///
/// ## Example: Checking Remaining Capacity
///
/// ```dart
/// final limiter = AsyncRateLimiter<int>(
///   (value) async => processValue(value),
///   AsyncRateLimiterOptions<int>(
///     limit: 5,
///     window: Duration(seconds: 10),
///   ),
/// );
///
/// // Check before attempting execution
/// final remaining = limiter.getRemainingInWindow();
/// if (remaining > 0) {
///   print('$remaining requests available');
///   await limiter.maybeExecute(42);
/// } else {
///   final waitTime = limiter.getMsUntilNextWindow();
///   print('Rate limited. Wait ${waitTime.inSeconds} seconds');
/// }
/// ```
///
/// ## Example: Error Handling
///
/// ```dart
/// final limiter = AsyncRateLimiter<Map<String, dynamic>>(
///   (data) async {
///     if (!data.containsKey('token')) {
///       throw Exception('Missing authentication token');
///     }
///     return await authenticatedRequest(data);
///   },
///   AsyncRateLimiterOptions<Map<String, dynamic>>(
///     limit: 20,
///     window: Duration(minutes: 1),
///     throwOnError: true,
///     onError: (error) => logError('Request failed: $error'),
///     onSettled: (result, error) {
///       if (error != null) {
///         showErrorNotification();
///       }
///     },
///   ),
/// );
///
/// try {
///   await limiter.maybeExecute({'token': 'abc123', 'data': 'value'});
/// } catch (e) {
///   print('Request failed: $e');
/// }
/// ```
///
/// ## Example: Resetting Rate Limit
///
/// ```dart
/// final limiter = AsyncRateLimiter<String>(
///   (msg) async => sendMessage(msg),
///   AsyncRateLimiterOptions<String>(
///     limit: 5,
///     window: Duration(minutes: 1),
///   ),
/// );
///
/// // ... after some executions ...
///
/// // Admin action: reset rate limit for this user
/// limiter.reset();
/// print('Rate limit cleared');
/// ```
class AsyncRateLimiter<T> extends ChangeNotifier {
  /// Creates an [AsyncRateLimiter] with the given function and options.
  ///
  /// The [fn] parameter is called when an execution is allowed by the rate limiter.
  /// The [options] parameter configures the rate limit, window type, and callbacks.
  ///
  /// Example:
  /// ```dart
  /// final limiter = AsyncRateLimiter<String>(
  ///   (query) async => searchAPI(query),
  ///   AsyncRateLimiterOptions<String>(
  ///     limit: 10,
  ///     window: Duration(seconds: 60),
  ///   ),
  /// );
  /// ```
  AsyncRateLimiter(this.fn, AsyncRateLimiterOptions<T> options)
      : _options = options,
        _state = const AsyncRateLimiterState() {
    if (!_options.enabled) {
      _state = _state.copyWith(status: PacerStatus.disabled);
    }
  }

  /// The function to execute when rate limit allows.
  final AnyAsyncFunction fn;

  AsyncRateLimiterOptions<T> _options;
  AsyncRateLimiterState<T> _state;
  bool _aborted = false;

  /// The current configuration options for this rate limiter.
  AsyncRateLimiterOptions<T> get options => _options;

  /// The current state of this rate limiter, including execution history and statistics.
  AsyncRateLimiterState<T> get state => _state;

  /// Attempts to execute the rate-limited function with the given arguments.
  ///
  /// Checks if execution is allowed based on the configured rate limit and window.
  /// If the limit has been reached, the execution is rejected, [onReject] is called,
  /// and the future completes with null (without executing the function).
  ///
  /// If execution is allowed, the function is called immediately and the execution
  /// is recorded in the window history.
  ///
  /// Returns a [Future] that completes with the function's result, or null if
  /// the execution was rejected or an error occurred (when [throwOnError] is false).
  ///
  /// Throws an [Exception] if the rate limiter is disabled.
  /// May throw if [throwOnError] is true and execution fails.
  ///
  /// Example:
  /// ```dart
  /// final limiter = AsyncRateLimiter<String>(
  ///   (text) async => sendMessage(text),
  ///   AsyncRateLimiterOptions<String>(
  ///     limit: 3,
  ///     window: Duration(seconds: 10),
  ///   ),
  /// );
  ///
  /// final result = await limiter.maybeExecute('Hello');
  /// if (result != null) {
  ///   print('Message sent');
  /// } else {
  ///   print('Rate limit exceeded');
  /// }
  /// ```
  Future<T?> maybeExecute(T args) async {
    if (!_options.enabled) {
      throw Exception('RateLimiter is disabled');
    }

    final now = DateTime.now();
    final windowStart = _options.windowType == WindowType.fixed
        ? now.subtract(_options.window)
        : _state.executionTimes.isNotEmpty
            ? _state.executionTimes.last.subtract(_options.window)
            : now.subtract(_options.window);

    final validExecutions =
        _state.executionTimes.where((t) => t.isAfter(windowStart)).toList();

    _state = _state.copyWith(
      maybeExecuteCount: _state.maybeExecuteCount + 1,
      executionTimes: validExecutions,
    );

    if (validExecutions.length < _options.limit) {
      return _executeAsync(args, now);
    } else {
      _reject(args);
      return Future.value();
    }
  }

  /// Internal method to execute the rate-limited function.
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
           executionTimes: [..._state.executionTimes, executionTime],
           isExecuting: false,
           isExceeded: false,
           status: PacerStatus.idle,
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
          status: PacerStatus.idle,
        );
        if (_options.throwOnError) {
          rethrow;
        } else {
          return null;
        }
      } else {
        throw Exception('Aborted');
      }
    } finally {
      _options.onSettled?.call(_state.lastResult, null);
      notifyListeners();
    }
  }

  /// Internal method to reject an execution due to rate limit.
  void _reject(T args) {
    _options.onReject?.call(args);
    _state = _state.copyWith(
      rejectionCount: _state.rejectionCount + 1,
      isExceeded: true,
    );
    notifyListeners();
  }

  /// Returns the number of executions remaining in the current window.
  ///
  /// This is the difference between the configured limit and the number of
  /// valid executions within the current window. Returns 0 if at or over the limit.
  ///
  /// Example:
  /// ```dart
  /// final remaining = limiter.getRemainingInWindow();
  /// print('You can make $remaining more requests');
  /// ```
  int getRemainingInWindow() {
    final now = DateTime.now();
    final windowStart = now.subtract(_options.window);

    final validExecutions =
        _state.executionTimes.where((t) => t.isAfter(windowStart)).length;
    return _options.limit - validExecutions;
  }

  /// Returns the duration until the next window opens.
  ///
  /// For fixed windows, this is the time until the window resets.
  /// For sliding windows, this is the time until the oldest execution expires.
  ///
  /// Returns [Duration.zero] if no executions have been recorded.
  ///
  /// Example:
  /// ```dart
  /// if (limiter.getRemainingInWindow() == 0) {
  ///   final waitTime = limiter.getMsUntilNextWindow();
  ///   print('Rate limit exceeded. Try again in ${waitTime.inSeconds} seconds');
  /// }
  /// ```
  Duration getMsUntilNextWindow() {
    if (_state.executionTimes.isEmpty) {
      return Duration.zero;
    }

    final now = DateTime.now();
    final nextWindow = _state.executionTimes.last.add(_options.window);
    return nextWindow.difference(now);
  }

  /// Resets the rate limiter, clearing all execution history.
  ///
  /// Removes all recorded executions, effectively allowing the full limit
  /// to be used immediately. The rate limiter returns to idle state.
  ///
  /// Example:
  /// ```dart
  /// // Clear rate limit for this user (e.g., admin override)
  /// limiter.reset();
  /// ```
  void reset() {
    _state = _state.copyWith(
      executionTimes: [],
      isExceeded: false,
      status: PacerStatus.idle,
      executionCount: 0,
      rejectionCount: 0,
      maybeExecuteCount: 0,
      errorCount: 0,
      successCount: 0,
      settleCount: 0,
    );
    notifyListeners();
  }

  /// Aborts the rate limiter, resetting it to idle state.
  ///
  /// Sets the aborted flag and returns the rate limiter to idle status.
  /// Does not clear execution history.
  ///
  /// Example:
  /// ```dart
  /// limiter.abort(); // Stop rate limiting
  /// ```
  void abort() {
    _aborted = true;
    _state = _state.copyWith(status: PacerStatus.idle);
    notifyListeners();
  }

  /// Updates the rate limiter configuration with new options.
  ///
  /// Applies the new options immediately. If the new options disable the rate limiter,
  /// it is aborted and its status is set to disabled. Otherwise, the status is set to idle.
  ///
  /// This allows dynamic reconfiguration of rate limits and windows without
  /// recreating the rate limiter. Note that changing the limit or window does not
  /// clear execution history.
  ///
  /// Example:
  /// ```dart
  /// final limiter = AsyncRateLimiter<String>(
  ///   (msg) async => sendMessage(msg),
  ///   AsyncRateLimiterOptions<String>(
  ///     limit: 10,
  ///     window: Duration(minutes: 1),
  ///   ),
  /// );
  ///
  /// // Later, adjust the rate limit
  /// limiter.setOptions(
  ///   AsyncRateLimiterOptions<String>(
  ///     limit: 20, // Increase limit
  ///     window: Duration(minutes: 1),
  ///   ),
  /// );
  /// ```
  void setOptions(AsyncRateLimiterOptions<T> options) {
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
