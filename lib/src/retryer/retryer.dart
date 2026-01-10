// 🎯 Dart imports:
import 'dart:async';

// 🐦 Flutter imports:
import 'package:flutter/foundation.dart';

// 🌎 Project imports:
import 'package:gnrllybttr_pacer/src/common/common.dart';
import 'package:gnrllybttr_pacer/src/retryer/models.dart';


/// An asynchronous retry mechanism with configurable backoff strategies.
///
/// [AsyncRetryer] automatically retries failed async operations using various
/// backoff strategies. It's designed for handling transient failures in network
/// requests, database operations, or other unreliable async operations.
///
/// Key features:
/// - Multiple backoff strategies (exponential, linear, fixed)
/// - Configurable retry attempts and timeouts
/// - Jitter support to prevent thundering herd
/// - Comprehensive callbacks for monitoring progress
/// - Manual abort capability
/// - Flutter ChangeNotifier integration for reactive UI
///
/// ## Basic Example - HTTP Request with Retry
///
/// ```dart
/// class HttpClient {
///   late final AsyncRetryer<Map<String, String>> _retryer;
///
///   HttpClient() {
///     _retryer = AsyncRetryer<Map<String, String>>(
///       (params) async {
///         final response = await http.get(Uri.parse(params['url']!));
///         if (response.statusCode >= 500) {
///           throw Exception('Server error: ${response.statusCode}');
///         }
///         return {'status': response.statusCode.toString(), 'body': response.body};
///       },
///       AsyncRetryerOptions<Map<String, String>>(
///         maxAttempts: 3,
///         backoff: BackoffType.exponential,
///         baseWait: Duration(seconds: 1),
///         onRetry: (attempt, error) => print('Retry $attempt: $error'),
///         onSuccess: (result) => print('Request succeeded'),
///       ),
///     );
///   }
///
///   Future<Map<String, String>?> get(String url) {
///     return _retryer.execute({'url': url});
///   }
/// }
/// ```
///
/// ## Example - Database Operation with Timeouts
///
/// ```dart
/// final dbRetryer = AsyncRetryer<String>(
///   (query) async {
///     // Simulate database operation with potential timeout
///     await Future.delayed(Duration(milliseconds: Random().nextInt(2000)));
///     if (Random().nextDouble() < 0.6) { // 60% failure rate
///       throw Exception('Database connection timeout');
///     }
///     return 'Query result for: $query';
///   },
///   AsyncRetryerOptions<String>(
///     maxAttempts: 5,
///     backoff: BackoffType.linear,
///     baseWait: Duration(milliseconds: 500),
///     maxExecutionTime: Duration(seconds: 2), // Single attempt timeout
///     maxTotalExecutionTime: Duration(seconds: 15), // Total timeout
///     jitter: Duration(milliseconds: 200),
///   ),
/// );
///
/// try {
///   final result = await dbRetryer.execute('SELECT * FROM users');
///   print('Success: $result');
/// } catch (e) {
///   print('All retries failed: $e');
/// }
/// ```
///
/// ## Example - Flutter Widget with Progress UI
///
/// ```dart
/// class RetryableOperation extends StatefulWidget {
///   @override
///   State<RetryableOperation> createState() => _RetryableOperationState();
/// }
///
/// class _RetryableOperationState extends State<RetryableOperation> {
///   late final AsyncRetryer<String> _retryer;
///   String _status = 'Ready';
///   double _progress = 0.0;
///
///   @override
///   void initState() {
///     super.initState();
///     _retryer = AsyncRetryer<String>(
///       (input) async {
///         // Simulate operation that fails 80% of the time
///         await Future.delayed(Duration(seconds: 1));
///         if (Random().nextDouble() < 0.8) {
///           throw Exception('Operation failed');
///         }
///         return 'Completed: $input';
///       },
///       AsyncRetryerOptions<String>(
///         maxAttempts: 4,
///         backoff: BackoffType.exponential,
///         baseWait: Duration(seconds: 1),
///         onRetry: (attempt, error) => setState(() {
///           _status = 'Retrying (attempt $attempt)...';
///           _progress = attempt / 4.0;
///         }),
///         onSuccess: (result) => setState(() {
///           _status = result!;
///           _progress = 1.0;
///         }),
///         onError: (error) => setState(() {
///           _status = 'Failed: $error';
///           _progress = 0.0;
///         }),
///       ),
///     );
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return Column(
///       children: [
///         ElevatedButton(
///           onPressed: _retryer.state.isExecuting
///             ? null
///             : () => _retryer.execute('Test operation'),
///           child: Text(_retryer.state.isExecuting ? 'Executing...' : 'Start'),
///         ),
///         Text(_status),
///         LinearProgressIndicator(value: _progress),
///         if (_retryer.state.isExecuting)
///           TextButton(
///             onPressed: _retryer.abort,
///             child: Text('Cancel'),
///           ),
///       ],
///     );
///   }
/// }
/// ```
///
/// ## Example - Manual Abort Control
///
/// ```dart
/// final retryer = AsyncRetryer<void>(
///   (data) async {
///     // Long-running operation
///     await Future.delayed(Duration(seconds: 5));
///     print('Operation completed');
///   },
///   AsyncRetryerOptions<void>(
///     maxAttempts: 10,
///     backoff: BackoffType.fixed,
///     baseWait: Duration(seconds: 1),
///   ),
/// );
///
/// // Start operation
/// final future = retryer.execute(null);
///
/// // Abort after 3 seconds
/// Timer(Duration(seconds: 3), () {
///   retryer.abort();
///   print('Operation aborted');
/// });
///
/// try {
///   await future;
/// } catch (e) {
///   print('Operation was aborted: $e');
/// }
/// ```
///
/// ## Example - Custom Backoff Strategy
///
/// ```dart
/// // Custom backoff: Fibonacci sequence
/// Duration fibonacciBackoff(int attempt) {
///   if (attempt <= 1) return Duration(seconds: 1);
///   if (attempt == 2) return Duration(seconds: 1);
///   if (attempt == 3) return Duration(seconds: 2);
///   if (attempt == 4) return Duration(seconds: 3);
///   if (attempt == 5) return Duration(seconds: 5);
///   return Duration(seconds: 8); // Cap at 8 seconds
/// }
///
/// final customRetryer = AsyncRetryer<String>(
///   (input) async {
///     // Your operation here
///     throw Exception('Simulated failure');
///   },
///   AsyncRetryerOptions<String>(
///     maxAttempts: 3,
///     backoff: BackoffType.exponential, // Still use exponential for simplicity
///     baseWait: Duration(seconds: 1),
///     // You could implement custom retry logic in onRetry callback
///     onRetry: (attempt, error) {
///       final wait = fibonacciBackoff(attempt);
///       print('Waiting ${wait.inSeconds}s before retry $attempt');
///     },
///   ),
/// );
/// ```
class AsyncRetryer<T> extends ChangeNotifier {
  /// Creates an [AsyncRetryer] with the given function and options.
  ///
  /// The [fn] will be executed with automatic retry logic based on [options].
  /// Failed attempts will be retried according to the configured backoff strategy.
  AsyncRetryer(this.fn, AsyncRetryerOptions<T> options)
      : _options = options,
        _state = AsyncRetryerState<T>() {
    if (!_options.enabled) {
      _state = _state.copyWith(status: PacerStatus.disabled);
    }
  }

  /// The async function to execute with retry logic.
  final AnyAsyncFunction fn;

  AsyncRetryerOptions<T> _options;
  AsyncRetryerState<T> _state;
  Timer? _retryTimer;
  Completer<T?>? _completer;
  bool _aborted = false;
  late DateTime? _startTime;

  /// Current configuration options for this retryer.
  AsyncRetryerOptions<T> get options => _options;

  /// Current state of this retryer.
  AsyncRetryerState<T> get state => _state;

  /// Executes the function with automatic retry logic.
  ///
  /// Returns a Future that completes with the result if successful,
  /// or throws the last error if all retries are exhausted.
  ///
  /// The operation will be attempted up to [AsyncRetryerOptions.maxAttempts] times,
  /// with delays between retries based on the configured backoff strategy.
  ///
  /// Throws an exception if the retryer is disabled.
  Future<T?> execute(T args) async {
    if (!_options.enabled) {
      throw Exception('Retryer is disabled');
    }

    _completer = Completer<T?>();
    _aborted = false;
    _startTime = DateTime.now();
    _state = _state.copyWith(
      currentAttempt: 0,
      status: PacerStatus.executing,
      totalExecutionTime: Duration.zero,
    );

    notifyListeners();

    await _attempt(args, 1);

    return _completer!.future;
  }

  Future<void> _attempt(T args, int attempt) async {
    if (_aborted) {
      return;
    }

    final attemptStart = DateTime.now();

    _state = _state.copyWith(currentAttempt: attempt);
    
    notifyListeners();

    try {
      final result = await fn(args);

      if (!_aborted) {
        _options.onSuccess?.call(result);
        _state = _state.copyWith(
          executionCount: _state.executionCount + 1,
          successCount: _state.successCount + 1,
          lastResult: result,
          lastExecutionTime: attemptStart,
          totalExecutionTime: DateTime.now().difference(_startTime!),
          status: PacerStatus.idle,
        );
        _completer!.complete(result as T?);
      }
    } catch (e) {
      if (_aborted) {
        return;
      }

      _options.onError?.call(e);
      _state = _state.copyWith(
        errorCount: _state.errorCount + 1,
        settleCount: _state.settleCount + 1,
        isExecuting: false,
      );

      if (_options.throwOnError) {
        rethrow;
      } else {
        _completer!.complete(null);
      }
      
      notifyListeners();
    }
  }

  /// Aborts the current retry operation.
  ///
  /// Cancels any pending retry timers and completes the current operation
  /// with an error. The [AsyncRetryerOptions.onAbort] callback will be called.
  ///
  /// Safe to call multiple times or when no operation is in progress.
  void abort() {
    _aborted = true;
    _retryTimer?.cancel();
    _options.onAbort?.call();
    _state = _state.copyWith(status: PacerStatus.idle);
    
    if (_completer != null && !_completer!.isCompleted) {
      _completer!.completeError('Aborted');
    }

    notifyListeners();
  }

  /// Updates the retryer configuration with new options.
  ///
  /// Changes take effect immediately. If the new options disable the retryer,
  /// any current operation will be aborted and the status set to disabled.
  void setOptions(AsyncRetryerOptions<T> options) {
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
