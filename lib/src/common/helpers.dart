// 🎯 Dart imports:
import 'dart:async';

// 🌎 Project imports:
import 'package:gnrllybttr_pacer/src/batcher/async_batcher.dart';
import 'package:gnrllybttr_pacer/src/batcher/batcher.dart';
import 'package:gnrllybttr_pacer/src/batcher/models.dart';
import 'package:gnrllybttr_pacer/src/common/enums.dart';
import 'package:gnrllybttr_pacer/src/common/typedefs.dart';
import 'package:gnrllybttr_pacer/src/debouncer/async_debouncer.dart';
import 'package:gnrllybttr_pacer/src/debouncer/debouncer.dart';
import 'package:gnrllybttr_pacer/src/debouncer/models.dart';
import 'package:gnrllybttr_pacer/src/queuer/async_queuer.dart';
import 'package:gnrllybttr_pacer/src/queuer/models.dart';
import 'package:gnrllybttr_pacer/src/queuer/queuer.dart';
import 'package:gnrllybttr_pacer/src/rate_limiter/async_rate_limiter.dart';
import 'package:gnrllybttr_pacer/src/rate_limiter/models.dart';
import 'package:gnrllybttr_pacer/src/rate_limiter/rate_limiter.dart';
import 'package:gnrllybttr_pacer/src/retryer/models.dart';
import 'package:gnrllybttr_pacer/src/retryer/retryer.dart';
import 'package:gnrllybttr_pacer/src/throttler/async_throttler.dart';
import 'package:gnrllybttr_pacer/src/throttler/models.dart';
import 'package:gnrllybttr_pacer/src/throttler/throttler.dart';

/// Convenience functions for creating debounced functions

/// Creates a debounced function that delays execution until inactivity.
///
/// Returns a function that can be called directly. The returned function
/// internally manages a [Debouncer] instance and calls [Debouncer.maybeExecute].
///
/// ## Example - Search Input Debouncing
///
/// ```dart
/// class SearchWidget extends StatefulWidget {
///   @override
///   State<SearchWidget> createState() => _SearchWidgetState();
/// }
///
/// class _SearchWidgetState extends State<SearchWidget> {
///   late final void Function(String) _debouncedSearch;
///   String _results = '';
///
///   @override
///   void initState() {
///     super.initState();
///     _debouncedSearch = debounce<String>(
///       (query) {
///         setState(() {
///           _results = 'Searching for: $query';
///           // Perform actual search here
///         });
///       },
///       DebouncerOptions<String>(
///         wait: Duration(milliseconds: 300),
///         trailing: true,
///       ),
///     );
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return TextField(
///       onChanged: _debouncedSearch,
///       decoration: InputDecoration(hintText: 'Search...'),
///     );
///   }
/// }
/// ```
///
/// ## Example - Button Click Debouncing
///
/// ```dart
/// class DebouncedButton extends StatelessWidget {
///   final void Function() onPressed;
///   final String text;
///
///   const DebouncedButton({required this.onPressed, required this.text});
///
///   @override
///   Widget build(BuildContext context) {
///     final debouncedOnPressed = debounce<void>(
///       (_) => onPressed(),
///       DebouncerOptions<void>(
///         wait: Duration(milliseconds: 500),
///         leading: true,
///         trailing: false,
///       ),
///     );
///
///     return ElevatedButton(
///       onPressed: () => debouncedOnPressed(null),
///       child: Text(text),
///     );
///   }
/// }
/// ```
void Function(T) debounce<T>(
  AnyFunction fn,
  DebouncerOptions<T> options,
) {
  final debouncer = Debouncer<T>(fn, options);

  return debouncer.maybeExecute;
}

/// Creates an async debounced function that delays execution until inactivity.
///
/// Returns a function that can be called directly. The returned function
/// internally manages an [AsyncDebouncer] instance and calls [AsyncDebouncer.maybeExecute].
///
/// ## Example - Async API Search
///
/// ```dart
/// class ApiSearchWidget extends StatefulWidget {
///   @override
///   State<ApiSearchWidget> createState() => _ApiSearchWidgetState();
/// }
///
/// class _ApiSearchWidgetState extends State<ApiSearchWidget> {
///   late final Future<String?> Function(String) _debouncedSearch;
///   String _results = '';
///   bool _loading = false;
///
///   @override
///   void initState() {
///     super.initState();
///     _debouncedSearch = asyncDebounce<String>(
///       (query) async {
///         setState(() => _loading = true);
///         try {
///           final result = await searchApi(query);
///           setState(() {
///             _results = result;
///             _loading = false;
///           });
///           return result;
///         } catch (e) {
///           setState(() => _loading = false);
///           rethrow;
///         }
///       },
///       AsyncDebouncerOptions<String>(
///         wait: Duration(milliseconds: 300),
///         trailing: true,
///       ),
///     );
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return Column(
///       children: [
///         TextField(
///           onChanged: (query) => _debouncedSearch(query),
///           decoration: InputDecoration(hintText: 'Search...'),
///         ),
///         if (_loading) CircularProgressIndicator(),
///         Text(_results),
///       ],
///     );
///   }
/// }
/// ```
Future<T?> Function(T) asyncDebounce<T>(
  AnyAsyncFunction fn,
  AsyncDebouncerOptions<T> options,
) {
  final debouncer = AsyncDebouncer<T>(fn, options);

  return debouncer.maybeExecute;
}

/// Convenience functions for creating throttled functions

/// Creates a throttled function that limits execution frequency.
///
/// Returns a function that can be called directly. The returned function
/// internally manages a [Throttler] instance and calls [Throttler.maybeExecute].
///
/// ## Example - Scroll Event Throttling
///
/// ```dart
/// class ScrollTracker extends StatefulWidget {
///   @override
///   State<ScrollTracker> createState() => _ScrollTrackerState();
/// }
///
/// class _ScrollTrackerState extends State<ScrollTracker> {
///   late final void Function(double) _throttledUpdate;
///   double _scrollPosition = 0;
///
///   @override
///   void initState() {
///     super.initState();
///     _throttledUpdate = throttle<double>(
///       (position) {
///         setState(() => _scrollPosition = position);
///         // Update scroll analytics, save position, etc.
///       },
///       ThrottlerOptions<double>(
///         wait: Duration(milliseconds: 100),
///         leading: true,
///         trailing: true,
///       ),
///     );
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return NotificationListener<ScrollNotification>(
///       onNotification: (notification) {
///         _throttledUpdate(notification.metrics.pixels);
///         return false;
///       },
///       child: ListView.builder(
///         itemCount: 100,
///         itemBuilder: (context, index) => ListTile(
///           title: Text('Item $index'),
///         ),
///       ),
///     );
///   }
/// }
/// ```
///
/// ## Example - Window Resize Handling
///
/// ```dart
/// class ResponsiveLayout extends StatefulWidget {
///   @override
///   State<ResponsiveLayout> createState() => _ResponsiveLayoutState();
/// }
///
/// class _ResponsiveLayoutState extends State<ResponsiveLayout> {
///   late final void Function(Size) _throttledResize;
///   Size _windowSize = Size.zero;
///
///   @override
///   void initState() {
///     super.initState();
///     _throttledResize = throttle<Size>(
///       (size) {
///         setState(() => _windowSize = size);
///         // Recalculate layout, update breakpoints, etc.
///       },
///       ThrottlerOptions<Size>(
///         wait: Duration(milliseconds: 200),
///         leading: true,
///         trailing: true,
///       ),
///     );
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return LayoutBuilder(
///       builder: (context, constraints) {
///         _throttledResize(Size(constraints.maxWidth, constraints.maxHeight));
///         return Text('Window: ${_windowSize.width} x ${_windowSize.height}');
///       },
///     );
///   }
/// }
/// ```
void Function(T) throttle<T>(
  AnyFunction fn,
  ThrottlerOptions<T> options,
) {
  final throttler = Throttler<T>(fn, options);

  return throttler.maybeExecute;
}

/// Creates an async throttled function that limits execution frequency.
///
/// Returns a function that can be called directly. The returned function
/// internally manages an [AsyncThrottler] instance and calls [AsyncThrottler.maybeExecute].
///
/// ## Example - Throttled API Calls
///
/// ```dart
/// class ApiThrottler {
///   late final Future<String?> Function(Map<String, dynamic>) _throttledApiCall;
///
///   ApiThrottler() {
///     _throttledApiCall = asyncThrottle<Map<String, dynamic>>(
///       (params) async {
///         // Make API call with rate limiting
///         final response = await http.post(
///           Uri.parse('https://api.example.com/data'),
///           body: jsonEncode(params),
///         );
///         return response.body;
///       },
///       AsyncThrottlerOptions<Map<String, dynamic>>(
///         wait: Duration(seconds: 1), // Max 1 call per second
///         leading: true,
///         trailing: true,
///       ),
///     );
///   }
///
///   Future<String?> callApi(Map<String, dynamic> params) {
///     return _throttledApiCall(params);
///   }
/// }
/// ```
Future<T?> Function(T) asyncThrottle<T>(
  AnyAsyncFunction fn,
  AsyncThrottlerOptions<T> options,
) {
  final throttler = AsyncThrottler<T>(fn, options);

  return throttler.maybeExecute;
}

/// Convenience functions for creating rate-limited functions

/// Creates a rate-limited function that restricts execution frequency.
///
/// Returns a function that can be called directly. The returned function
/// internally manages a [RateLimiter] instance and calls [RateLimiter.maybeExecute].
/// Returns true if the function was executed, false if rate limited.
///
/// ## Example - API Rate Limiting
///
/// ```dart
/// class ApiClient {
///   late final bool Function(Map<String, dynamic>) _rateLimitedRequest;
///   int _successfulRequests = 0;
///   int _rejectedRequests = 0;
///
///   ApiClient() {
///     _rateLimitedRequest = rateLimit<Map<String, dynamic>>(
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
///     return _rateLimitedRequest(params);
///   }
/// }
/// ```
///
/// ## Example - Button Click Rate Limiting
///
/// ```dart
/// class RateLimitedButton extends StatefulWidget {
///   final void Function() onPressed;
///   final String text;
///
///   const RateLimitedButton({required this.onPressed, required this.text});
///
///   @override
///   State<RateLimitedButton> createState() => _RateLimitedButtonState();
/// }
///
/// class _RateLimitedButtonState extends State<RateLimitedButton> {
///   late final bool Function(void) _rateLimitedPress;
///   int _pressCount = 0;
///
///   @override
///   void initState() {
///     super.initState();
///     _rateLimitedPress = rateLimit<void>(
///       (_) {
///         setState(() => _pressCount++);
///         widget.onPressed();
///       },
///       RateLimiterOptions<void>(
///         limit: 3, // Max 3 clicks
///         window: Duration(seconds: 5), // per 5 seconds
///         onReject: (_) {
///           ScaffoldMessenger.of(context).showSnackBar(
///             SnackBar(content: Text('Too many clicks! Wait before trying again.')),
///           );
///         },
///       ),
///     );
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return ElevatedButton(
///       onPressed: () => _rateLimitedPress(null),
///       child: Text('${widget.text} ($_pressCount)'),
///     );
///   }
/// }
/// ```
bool Function(T) rateLimit<T>(
  AnyFunction fn,
  RateLimiterOptions<T> options,
) {
  final rateLimiter = RateLimiter<T>(fn, options);

  return rateLimiter.maybeExecute;
}

/// Creates an async rate-limited function that restricts execution frequency.
///
/// Returns a function that can be called directly. The returned function
/// internally manages an [AsyncRateLimiter] instance and calls [AsyncRateLimiter.maybeExecute].
///
/// ## Example - Async API Rate Limiting
///
/// ```dart
/// class AsyncApiClient {
///   late final Future<String?> Function(Map<String, dynamic>) _rateLimitedRequest;
///
///   AsyncApiClient() {
///     _rateLimitedRequest = asyncRateLimit<Map<String, dynamic>>(
///       (params) async {
///         final response = await http.post(
///           Uri.parse('https://api.example.com/async-endpoint'),
///           body: jsonEncode(params),
///         );
///         return response.body;
///       },
///       AsyncRateLimiterOptions<Map<String, dynamic>>(
///         limit: 5, // 5 requests
///         window: Duration(seconds: 60), // per minute
///         windowType: WindowType.sliding,
///         onReject: (params) {
///           print('Rate limit exceeded, request rejected');
///         },
///       ),
///     );
///   }
///
///   Future<String?> makeRequest(Map<String, dynamic> params) {
///     return _rateLimitedRequest(params);
///   }
/// }
/// ```
Future<T?> Function(T) asyncRateLimit<T>(
  AnyAsyncFunction fn,
  AsyncRateLimiterOptions<T> options,
) {
  final rateLimiter = AsyncRateLimiter<T>(fn, options);

  return rateLimiter.maybeExecute;
}

/// Convenience functions for creating queued functions

/// Creates a queued function that processes items sequentially.
///
/// Returns a function that can be called directly. The returned function
/// internally manages a [Queuer] instance and calls [Queuer.addItem].
/// Returns true if the item was queued, false if rejected.
///
/// ## Example - Task Queue
///
/// ```dart
/// class TaskProcessor extends StatefulWidget {
///   @override
///   State<TaskProcessor> createState() => _TaskProcessorState();
/// }
///
/// class _TaskProcessorState extends State<TaskProcessor> {
///   late final bool Function(String) _queueTask;
///   final List<String> _completedTasks = [];
///
///   @override
///   void initState() {
///     super.initState();
///     _queueTask = queue<String>(
///       (task) {
///         setState(() => _completedTasks.add(task));
///         // Process task here
///       },
///       QueuerOptions<String>(
///         wait: Duration(milliseconds: 500), // Process every 500ms
///         maxSize: 10, // Max 10 tasks in queue
///         started: true, // Auto-start processing
///       ),
///     );
///   }
///
///   void addTask(String task) {
///     final added = _queueTask(task);
///     if (!added) {
///       print('Task rejected: queue full');
///     }
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return Column(
///       children: [
///         ElevatedButton(
///           onPressed: () => addTask('Task ${DateTime.now()}'),
///           child: Text('Add Task'),
///         ),
///         Text('Completed: ${_completedTasks.length}'),
///       ],
///     );
///   }
/// }
/// ```
///
/// ## Example - Priority Queue
///
/// ```dart
/// enum Priority { low, medium, high }
///
/// class PriorityTask {
///   final String name;
///   final Priority priority;
///   PriorityTask(this.name, this.priority);
/// }
///
/// class PriorityProcessor {
///   late final bool Function(PriorityTask) _queueTask;
///
///   PriorityProcessor() {
///     _queueTask = queue<PriorityTask>(
///       (task) => print('Processing: ${task.name}'),
///       QueuerOptions<PriorityTask>(
///         getPriority: (task) => task.priority.index,
///         wait: Duration(milliseconds: 200),
///         started: true,
///       ),
///     );
///   }
///
///   void addTask(String name, Priority priority) {
///     _queueTask(PriorityTask(name, priority));
///   }
/// }
/// ```
bool Function(T, {QueuePosition? position, bool? runOnItemsChange}) queue<T>(
  AnyFunction fn,
  QueuerOptions<T> options,
) {
  final queuer = Queuer<T>(fn, options);

  return (item, {QueuePosition? position, bool? runOnItemsChange}) {
    return queuer.addItem(
      item,
      position: position ?? QueuePosition.back,
      runOnItemsChange: runOnItemsChange ?? true,
    );
  };
}

/// Creates an async queued function that processes items sequentially.
///
/// Returns a function that can be called directly. The returned function
/// internally manages an [AsyncQueuer] instance and calls [AsyncQueuer.addItem].
///
/// ## Example - Async Task Processing
///
/// ```dart
/// class AsyncTaskProcessor {
///   late final Future<dynamic> Function(String) _queueTask;
///   final List<String> _results = [];
///
///   AsyncTaskProcessor() {
///     _queueTask = asyncQueue<String>(
///       (task) async {
///         // Simulate async work
///         await Future.delayed(Duration(seconds: 1));
///         final result = 'Processed: $task';
///         _results.add(result);
///         return result;
///       },
///       AsyncQueuerOptions<String>(
///         wait: Duration(milliseconds: 500),
///         maxSize: 5,
///         started: true,
///       ),
///     );
///   }
///
///   Future<void> addTask(String task) async {
///     await _queueTask(task);
///   }
/// }
/// ```
Future<dynamic> Function(T, {QueuePosition? position, bool? runOnItemsChange})
    asyncQueue<T>(
  AnyAsyncFunction fn,
  AsyncQueuerOptions<T> options,
) {
  final queuer = AsyncQueuer<T>(fn, options);

  return (item, {QueuePosition? position, bool? runOnItemsChange}) {
    return queuer.addItem(
      item,
      position: position ?? QueuePosition.back,
      runOnItemsChange: runOnItemsChange ?? true,
    );
  };
}

/// Convenience functions for creating batched functions

/// Creates a batched function that accumulates items before processing.
///
/// Returns a function that can be called directly. The returned function
/// internally manages a [Batcher] instance and calls [Batcher.addItem].
///
/// ## Example - Log Batching
///
/// ```dart
/// class LogBatcher {
///   late final void Function(String) _batchLog;
///
///   LogBatcher() {
///     _batchLog = batch<String>(
///       (logs) {
///         // Send batch to logging service
///         print('Sending ${logs.length} logs to server');
///         for (final log in logs) {
///           print('  $log');
///         }
///       },
///       BatcherOptions<String>(
///         maxSize: 10, // Batch up to 10 logs
///         maxWait: Duration(seconds: 5), // Or every 5 seconds
///       ),
///     );
///   }
///
///   void log(String message) {
///     _batchLog(message);
///   }
/// }
/// ```
///
/// ## Example - Event Batching
///
/// ```dart
/// class EventTracker extends StatefulWidget {
///   @override
///   State<EventTracker> createState() => _EventTrackerState();
/// }
///
/// class _EventTrackerState extends State<EventTracker> {
///   late final void Function(Map<String, dynamic>) _batchEvent;
///   int _batchesSent = 0;
///
///   @override
///   void initState() {
///     super.initState();
///     _batchEvent = batch<Map<String, dynamic>>(
///       (events) {
///         setState(() => _batchesSent++);
///         // Send events to analytics service
///         print('Sent batch of ${events.length} events');
///       },
///       BatcherOptions<Map<String, dynamic>>(
///         maxSize: 20, // Batch up to 20 events
///         maxWait: Duration(seconds: 10), // Or every 10 seconds
///       ),
///     );
///   }
///
///   void trackEvent(String eventName, Map<String, dynamic> properties) {
///     _batchEvent({
///       'event': eventName,
///       'timestamp': DateTime.now().toIso8601String(),
///       'properties': properties,
///     });
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return ElevatedButton(
///       onPressed: () => trackEvent('button_click', {'source': 'widget'}),
///       child: Text('Track Event (Batches: $_batchesSent)'),
///     );
///   }
/// }
/// ```
void Function(T) batch<T>(
  AnyFunction fn,
  BatcherOptions<T> options,
) {
  final batcher = Batcher<T>(fn, options);

  return batcher.addItem;
}

/// Creates an async batched function that accumulates items before processing.
///
/// Returns a function that can be called directly. The returned function
/// internally manages an [AsyncBatcher] instance and calls [AsyncBatcher.addItem].
///
/// ## Example - Async Batch Processing
///
/// ```dart
/// class AsyncBatchProcessor {
///   late final Future<dynamic> Function(String) _batchProcess;
///
///   AsyncBatchProcessor() {
///     _batchProcess = asyncBatch<String>(
///       (items) async {
///         // Process batch asynchronously
///         print('Processing batch of ${items.length} items');
///         await Future.delayed(Duration(seconds: 1));
///         return 'Processed ${items.length} items';
///       },
///       AsyncBatcherOptions<String>(
///         maxSize: 5,
///         maxWait: Duration(seconds: 3),
///       ),
///     );
///   }
///
///   Future<void> addItem(String item) async {
///     await _batchProcess(item);
///   }
/// }
/// ```
Future<dynamic> Function(T) asyncBatch<T>(
  AnyAsyncFunction fn,
  AsyncBatcherOptions<T> options,
) {
  final batcher = AsyncBatcher<T>(fn, options);

  return batcher.addItem;
}

/// Convenience functions for creating retried functions

/// Creates an async function with automatic retry logic.
///
/// Returns a function that can be called directly. The returned function
/// internally manages an [AsyncRetryer] instance and calls [AsyncRetryer.execute].
///
/// ## Example - API Call with Retries
///
/// ```dart
/// class RetryApiClient {
///   late final Future<String?> Function(Map<String, dynamic>) _retryingRequest;
///
///   RetryApiClient() {
///     _retryingRequest = asyncRetry<Map<String, dynamic>>(
///       (params) async {
///         final response = await http.post(
///           Uri.parse('https://api.example.com/unreliable-endpoint'),
///           body: jsonEncode(params),
///         );
///
///         if (response.statusCode != 200) {
///           throw Exception('API error: ${response.statusCode}');
///         }
///
///         return response.body;
///       },
///       AsyncRetryerOptions<Map<String, dynamic>>(
///         maxAttempts: 3,
///         delay: Duration(seconds: 1),
///         backoffFactor: 2.0, // Exponential backoff
///         retryCondition: (error, attempt) {
///           // Retry on network errors, not on auth errors
///           return error is SocketException || error is TimeoutException;
///         },
///       ),
///     );
///   }
///
///   Future<String?> makeRequest(Map<String, dynamic> params) {
///     return _retryingRequest(params);
///   }
/// }
/// ```
///
/// ## Example - File Upload with Retries
///
/// ```dart
/// class FileUploader {
///   late final Future<bool?> Function(File) _retryingUpload;
///
///   FileUploader() {
///     _retryingUpload = asyncRetry<File>(
///       (file) async {
///         final request = http.MultipartRequest(
///           'POST',
///           Uri.parse('https://upload.example.com/files'),
///         );
///         request.files.add(await http.MultipartFile.fromPath('file', file.path));
///
///         final response = await request.send();
///         if (response.statusCode != 200) {
///           throw Exception('Upload failed: ${response.statusCode}');
///         }
///
///         return true;
///       },
///       AsyncRetryerOptions<File>(
///         maxAttempts: 5,
///         delay: Duration(seconds: 2),
///         backoffFactor: 1.5,
///         maxDelay: Duration(seconds: 30),
///         retryCondition: (error, attempt) {
///           // Retry on network issues or server errors
///           return error is IOException ||
///                  (error is Exception && error.toString().contains('5'));
///         },
///       ),
///     );
///   }
///
///   Future<bool?> uploadFile(File file) {
///     return _retryingUpload(file);
///   }
/// }
/// ```
Future<T?> Function(T) asyncRetry<T>(
  AnyAsyncFunction fn,
  AsyncRetryerOptions<T> options,
) {
  final retryer = AsyncRetryer<T>(fn, options);

  return retryer.execute;
}

/// Utility functions

/// Checks if a value is a function.
///
/// Useful for type checking and validation in dynamic contexts.
///
/// ## Example
///
/// ```dart
/// void processValue(dynamic value) {
///   if (isFunction(value)) {
///     value(); // Safe to call
///   } else {
///     print('Value is not a function: $value');
///   }
/// }
/// ```
bool isFunction(dynamic value) {
  return value is Function;
}

/// Parses a value that might be a function or a static value.
///
/// If the value is a function, calls it with optional arguments.
/// If it's a static value, returns it directly.
///
/// ## Example - Dynamic Configuration
///
/// ```dart
/// class DynamicConfig {
///   final dynamic _valueOrFunction;
///
///   DynamicConfig(this._valueOrFunction);
///
///   dynamic getValue([List<dynamic>? args]) {
///     return parseFunctionOrValue(_valueOrFunction, args);
///   }
/// }
///
/// // Usage
/// final staticConfig = DynamicConfig('static value');
/// final dynamicConfig = DynamicConfig(() => 'computed value');
/// final paramConfig = DynamicConfig((args) => 'value with ${args[0]}');
///
/// print(staticConfig.getValue()); // 'static value'
/// print(dynamicConfig.getValue()); // 'computed value'
/// print(paramConfig.getValue(['param'])); // 'value with param'
/// ```
dynamic parseFunctionOrValue(dynamic value, {List<dynamic>? args}) {
  if (value is Function) {
    return value(args ?? <dynamic>[]);
  }

  return value;
}
