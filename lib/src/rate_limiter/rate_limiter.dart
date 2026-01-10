// 🐦 Flutter imports:
import 'package:flutter/foundation.dart';

// 🌎 Project imports:
import 'package:gnrllybttr_pacer/src/common/common.dart';
import 'package:gnrllybttr_pacer/src/rate_limiter/models.dart';

/// A rate limiter that restricts function execution frequency.
///
/// [RateLimiter] is the synchronous version of [AsyncRateLimiter]. It ensures
/// a function is not executed more than a specified number of times within
/// a time window. Useful for API rate limiting, preventing abuse, or
/// controlling resource usage.
///
/// Supports two window types:
/// - **Fixed window**: Counts executions in fixed time intervals
/// - **Sliding window**: Counts executions in a rolling time window
///
/// ## Basic Example - API Rate Limiting
///
/// ```dart
/// class ApiClient {
///   late final RateLimiter<Map<String, dynamic>> _rateLimiter;
///   int _successfulRequests = 0;
///   int _rejectedRequests = 0;
///
///   ApiClient() {
///     _rateLimiter = RateLimiter<Map<String, dynamic>>(
///       (params) {
///         _successfulRequests++;
///         // Make actual API request
///         print('API request: $params');
///       },
///       RateLimiterOptions<Map<String, dynamic>>(
///         limit: 10, // 10 requests
///         window: Duration(seconds: 60), // per minute
///         windowType: WindowType.sliding,
///         onReject: (params) {
///           _rejectedRequests++;
///           print('Rate limit exceeded for: $params');
///         },
///       ),
///     );
///   }
///
///   bool makeRequest(Map<String, dynamic> params) {
///     return _rateLimiter.maybeExecute(params);
///   }
/// }
/// ```
///
/// ## Example - Button Click Rate Limiting
///
/// Prevent rapid button clicks:
/// ```dart
/// class RateLimitedButton extends StatefulWidget {
///   @override
///   State<RateLimitedButton> createState() => _RateLimitedButtonState();
/// }
///
/// class _RateLimitedButtonState extends State<RateLimitedButton> {
///   late final RateLimiter<void> _rateLimiter;
///   int _clickCount = 0;
///
///   @override
///   void initState() {
///     super.initState();
///     _rateLimiter = RateLimiter<void>(
///       () => setState(() => _clickCount++),
///       RateLimiterOptions<void>(
///         limit: 3, // Max 3 clicks
///         window: Duration(seconds: 5), // per 5 seconds
///         onReject: (_) => ScaffoldMessenger.of(context).showSnackBar(
///           SnackBar(content: Text('Too many clicks! Wait before trying again.')),
///         ),
///       ),
///     );
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return ElevatedButton(
///       onPressed: () => _rateLimiter.maybeExecute(null),
///       child: Text('Clicks: $_clickCount'),
///     );
///   }
/// }
/// ```
///
/// ## Example - Fixed vs Sliding Window Comparison
///
/// ```dart
/// // Fixed window: Resets at fixed intervals
/// final fixedLimiter = RateLimiter<void>(
///   () => print('Fixed: Executed'),
///   RateLimiterOptions<void>(
///     limit: 3,
///     window: Duration(minutes: 1),
///     windowType: WindowType.fixed,
///   ),
/// );
///
/// // Sliding window: Rolling window based on execution times
/// final slidingLimiter = RateLimiter<void>(
///   () => print('Sliding: Executed'),
///   RateLimiterOptions<void>(
///     limit: 3,
///     window: Duration(minutes: 1),
///     windowType: WindowType.sliding,
///   ),
/// );
/// ```
///
/// ## Example - Check Remaining Capacity
///
/// Monitor rate limit status:
/// ```dart
/// final limiter = RateLimiter<String>(
///   (msg) => print(msg),
///   RateLimiterOptions<String>(
///     limit: 5,
///     window: Duration(seconds: 10),
///   ),
/// );
///
/// for (var i = 0; i < 7; i++) {
///   final remaining = limiter.getRemainingInWindow();
///   print('Remaining: $remaining');
///
///   if (limiter.maybeExecute('Message $i')) {
///     print('Sent: Message $i');
///   } else {
///     print('Rejected: Message $i');
///     final wait = limiter.getMsUntilNextWindow();
///     print('Wait ${wait.inSeconds}s before next attempt');
///   }
/// }
/// ```
///
/// ## Example - Manual Control
///
/// Control rate limiter behavior manually:
/// ```dart
/// final limiter = RateLimiter<void>(
///   () => print('Executed'),
///   RateLimiterOptions<void>(
///     limit: 3,
///     window: Duration(seconds: 5),
///   ),
/// );
///
/// limiter.maybeExecute(null); // Success
/// limiter.maybeExecute(null); // Success
/// limiter.maybeExecute(null); // Success
/// limiter.maybeExecute(null); // Rejected
///
/// print(limiter.state.isExceeded); // true
///
/// // Reset to allow new executions
/// limiter.reset();
/// print(limiter.state.isExceeded); // false
/// limiter.maybeExecute(null); // Success
/// ```
class RateLimiter<T> extends ChangeNotifier {
  /// Creates a [RateLimiter] with the given function and options.
  ///
  /// The [fn] will be called at most [RateLimiterOptions.limit] times
  /// within each [RateLimiterOptions.window] duration.
  RateLimiter(this.fn, RateLimiterOptions<T> options)
      : _options = options,
        _state = RateLimiterState<T>() {
    if (!_options.enabled) {
      _state = _state.copyWith(status: PacerStatus.disabled);
    }
  }

  /// The function to execute when rate limiting allows.
  final AnyFunction fn;

  RateLimiterOptions<T> _options;
  RateLimiterState<T> _state;

  /// Current configuration options for this rate limiter.
  RateLimiterOptions<T> get options => _options;

  /// Current state of this rate limiter.
  RateLimiterState<T> get state => _state;

  /// Potentially executes the function if rate limit allows.
  ///
  /// Returns true if the function was executed, false if rate limited.
  /// The decision is based on [RateLimiterOptions.windowType] and execution history.
  ///
  /// For fixed windows, counts executions in the current time window.
  /// For sliding windows, counts executions in a rolling window based on execution times.
  bool maybeExecute(T args) {
    if (!_options.enabled) {
      return false;
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
      _execute(args, now);
      return true;
    } else {
      _reject(args);
      return false;
    }
  }

  void _execute(T args, DateTime executionTime) {
    fn(args);
    _options.onExecute?.call(args);
    _state = _state.copyWith(
      executionCount: _state.executionCount + 1,
      executionTimes: [..._state.executionTimes, executionTime],
      isExceeded: false,
    );
    notifyListeners();
  }

  void _reject(T args) {
    _options.onReject?.call(args);
    _state = _state.copyWith(
      rejectionCount: _state.rejectionCount + 1,
      isExceeded: true,
    );
    notifyListeners();
  }

  /// Returns the number of remaining executions allowed in the current window.
  ///
  /// A positive number indicates how many more executions are allowed.
  /// Zero or negative indicates the limit is exceeded.
  ///
  /// Useful for UI feedback or pre-checking before attempting execution.
  int getRemainingInWindow() {
    final now = DateTime.now();
    final windowStart = now.subtract(_options.window);

    final validExecutions =
        _state.executionTimes.where((t) => t.isAfter(windowStart)).length;
    return _options.limit - validExecutions;
  }

  /// Returns the duration until the next execution window starts.
  ///
  /// For sliding windows, this is the time until the oldest execution
  /// in the current window expires. For fixed windows, this is the time
  /// until the current window ends.
  ///
  /// Returns [Duration.zero] if no executions have occurred yet.
  Duration getMsUntilNextWindow() {
    if (_state.executionTimes.isEmpty) {
      return Duration.zero;
    }

    final now = DateTime.now();
    final nextWindow = _state.executionTimes.last.add(_options.window);
    return nextWindow.difference(now);
  }

  /// Resets the rate limiter state, clearing all execution history.
  ///
  /// After reset, the rate limiter behaves as if no executions have occurred.
  /// Useful for testing or when you want to allow immediate executions again.
  void reset() {
    _state = _state.copyWith(
      executionTimes: [],
      isExceeded: false,
      status: PacerStatus.idle,
      executionCount: 0,
      rejectionCount: 0,
      maybeExecuteCount: 0,
    );
    notifyListeners();
  }

  /// Updates the rate limiter configuration with new options.
  ///
  /// Changes take effect immediately. If the new options disable the limiter,
  /// the status will be set to [PacerStatus.disabled].
  void setOptions(RateLimiterOptions<T> options) {
    _options = options;
    if (!_options.enabled) {
      _state = _state.copyWith(status: PacerStatus.disabled);
    } else {
      _state = _state.copyWith(status: PacerStatus.idle);
    }
    notifyListeners();
  }
}
