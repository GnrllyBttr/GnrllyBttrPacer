// 🎯 Dart imports:
import 'dart:async';

// 🐦 Flutter imports:
import 'package:flutter/foundation.dart';

// 🌎 Project imports:
import 'package:gnrllybttr_pacer/src/common/common.dart';
import 'package:gnrllybttr_pacer/src/debouncer/models.dart';

/// A debouncer that delays execution until a quiet period has elapsed.
///
/// [Debouncer] is the synchronous version of [AsyncDebouncer]. It's useful for
/// rate-limiting synchronous callbacks like UI updates, event handlers, or
/// any function that should only run after activity has stopped.
///
/// The debouncer can run the function at the:
/// - **Leading edge** (immediately on first call, then ignore subsequent calls)
/// - **Trailing edge** (wait for quiet period after last call)
/// - **Both edges** (immediately on first call, then again after quiet period)
///
/// ## Basic Example - Search Input
///
/// ```dart
/// class SearchWidget extends StatefulWidget {
///   @override
///   State<SearchWidget> createState() => _SearchWidgetState();
/// }
///
/// class _SearchWidgetState extends State<SearchWidget> {
///   late final Debouncer<String> _searchDebouncer;
///   String _searchResults = '';
///
///   @override
///   void initState() {
///     super.initState();
///     _searchDebouncer = Debouncer<String>(
///       (query) {
///         setState(() {
///           _searchResults = 'Searching for: $query';
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
///   void dispose() {
///     _searchDebouncer.dispose();
///     super.dispose();
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return TextField(
///       onChanged: (query) => _searchDebouncer.maybeExecute(query),
///       decoration: InputDecoration(
///         hintText: 'Search...',
///       ),
///     );
///   }
/// }
/// ```
///
/// ## Example - Leading Edge Execution
///
/// Execute immediately on first call, then ignore subsequent calls:
/// ```dart
/// final debouncer = Debouncer<void>(
///   () => print('Button tapped!'),
///   DebouncerOptions<void>(
///     wait: Duration(seconds: 2),
///     leading: true,
///     trailing: false,
///   ),
/// );
///
/// // User rapidly taps button
/// debouncer.maybeExecute(); // Prints immediately
/// debouncer.maybeExecute(); // Ignored
/// debouncer.maybeExecute(); // Ignored
/// // After 2 seconds, ready for next tap
/// ```
///
/// ## Example - Scroll Position Tracking
///
/// Update UI only after scrolling stops:
/// ```dart
/// class ScrollTracker extends StatefulWidget {
///   @override
///   State<ScrollTracker> createState() => _ScrollTrackerState();
/// }
///
/// class _ScrollTrackerState extends State<ScrollTracker> {
///   late final Debouncer<double> _scrollDebouncer;
///   double _scrollPosition = 0;
///
///   @override
///   void initState() {
///     super.initState();
///     _scrollDebouncer = Debouncer<double>(
///       (position) {
///         setState(() {
///           _scrollPosition = position;
///           // Update UI or save scroll position
///         });
///       },
///       DebouncerOptions<double>(
///         wait: Duration(milliseconds: 150),
///         trailing: true,
///       ),
///     );
///   }
///
///   @override
///   void dispose() {
///     _scrollDebouncer.dispose();
///     super.dispose();
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return NotificationListener<ScrollNotification>(
///       onNotification: (notification) {
///         _scrollDebouncer.maybeExecute(notification.metrics.pixels);
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
/// ## Example - Form Validation
///
/// Validate form after user stops typing:
/// ```dart
/// class FormValidator {
///   late final Debouncer<String> _emailDebouncer;
///   late final Debouncer<String> _passwordDebouncer;
///
///   String? emailError;
///   String? passwordError;
///
///   FormValidator() {
///     _emailDebouncer = Debouncer<String>(
///       (email) {
///         emailError = _validateEmail(email);
///       },
///       DebouncerOptions<String>(wait: Duration(milliseconds: 500)),
///     );
///
///     _passwordDebouncer = Debouncer<String>(
///       (password) {
///         passwordError = _validatePassword(password);
///       },
///       DebouncerOptions<String>(wait: Duration(milliseconds: 500)),
///     );
///   }
///
///   String? _validateEmail(String email) {
///     if (email.isEmpty) return 'Email required';
///     if (!email.contains('@')) return 'Invalid email';
///     return null;
///   }
///
///   String? _validatePassword(String password) {
///     if (password.isEmpty) return 'Password required';
///     if (password.length < 8) return 'Password too short';
///     return null;
///   }
///
///   void onEmailChanged(String email) => _emailDebouncer.maybeExecute(email);
///   void onPasswordChanged(String password) => _passwordDebouncer.maybeExecute(password);
///
///   void dispose() {
///     _emailDebouncer.dispose();
///     _passwordDebouncer.dispose();
///   }
/// }
/// ```
///
/// ## Example - Manual Control
///
/// Manually trigger or cancel pending executions:
/// ```dart
/// final debouncer = Debouncer<String>(
///   (value) => print('Processed: $value'),
///   DebouncerOptions<String>(wait: Duration(seconds: 1)),
/// );
///
/// debouncer.maybeExecute('Hello');
/// print(debouncer.state.isPending); // true
///
/// // Force immediate execution
/// debouncer.flush();
/// print(debouncer.state.isPending); // false
///
/// debouncer.maybeExecute('World');
///
/// // Cancel pending execution
/// debouncer.cancel();
/// print(debouncer.state.isPending); // false
/// // 'World' will not be processed
/// ```
class Debouncer<T> extends ChangeNotifier {
  /// Creates a [Debouncer] with the given function and options.
  ///
  /// The [fn] will be called after the configured wait period has elapsed
  /// without any additional calls to [maybeExecute].
  Debouncer(this.fn, DebouncerOptions<T> options)
      : _options = options,
        _state = DebouncerState<T>() {
    if (!_options.enabled) {
      _state = _state.copyWith(status: PacerStatus.disabled);
    }
  }

  /// The function to execute after debouncing.
  final AnyFunction fn;

  DebouncerOptions<T> _options;
  DebouncerState<T> _state;
  Timer? _timer;
  bool _leadingExecuted = false;

  /// Current configuration options for this debouncer.
  DebouncerOptions<T> get options => _options;

  /// Current state of this debouncer.
  DebouncerState<T> get state => _state;

  /// Potentially executes the function after the configured wait period.
  ///
  /// Behavior depends on [DebouncerOptions.leading] and [DebouncerOptions.trailing]:
  /// - If leading is true: executes immediately on first call
  /// - If trailing is true: executes after wait period of inactivity
  /// - Both can be true for execution at both edges
  ///
  /// Each call resets the timer, so the function only executes when calls stop.
  void maybeExecute(T args) {
    if (!_options.enabled) {
      return;
    }

    _state = _state.copyWith(
      maybeExecuteCount: _state.maybeExecuteCount + 1,
      lastArgs: args,
      isPending: true,
      status: PacerStatus.pending,
    );
    notifyListeners();

    _timer?.cancel();

    if (_options.leading && !_leadingExecuted) {
      _execute(args);
      _leadingExecuted = true;
    } else {
      _timer = Timer(_options.wait, () {
        if (_options.trailing) {
          _execute(args);
        }
        _state = _state.copyWith(isPending: false, status: PacerStatus.idle);
        _leadingExecuted = false;
        notifyListeners();
      });
    }
  }

  void _execute(T args) {
    _options.onExecute?.call(args);
    fn(args);
    _state = _state.copyWith(executionCount: _state.executionCount + 1);
    notifyListeners();
  }

  /// Cancels any pending execution.
  ///
  /// After calling this, the function will not execute even if it was pending.
  /// The timer is reset and the debouncer is ready for new calls.
  void cancel() {
    _timer?.cancel();
    _state = _state.copyWith(isPending: false, status: PacerStatus.idle);
    _leadingExecuted = false;
    notifyListeners();
  }

  /// Immediately executes any pending function call.
  ///
  /// If there's a pending execution (trailing mode), it will run immediately
  /// instead of waiting for the timer. If nothing is pending, this does nothing.
  void flush() {
    if (_state.isPending && _options.trailing && _state.lastArgs != null) {
      _timer?.cancel();
      _execute(_state.lastArgs as T);
      _state = _state.copyWith(isPending: false, status: PacerStatus.idle);
      _leadingExecuted = false;
      notifyListeners();
    }
  }

  /// Updates the debouncer options at runtime.
  ///
  /// If [enabled] is set to false, any pending execution will be cancelled.
  void setOptions(DebouncerOptions<T> options) {
    _options = options;
    if (!_options.enabled) {
      cancel();
      _state = _state.copyWith(status: PacerStatus.disabled);
    } else {
      _state = _state.copyWith(status: PacerStatus.idle);
    }
    notifyListeners();
  }
}
