import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'common.dart';
import 'queuer.dart';

class AsyncQueuerOptions<T> extends PacerOptions {
  final Duration? wait;
  final int? maxSize;
  final QueuePosition addItemsTo;
  final QueuePosition getItemsFrom;
  final PriorityGetter<T>? getPriority;
  final Duration? expirationDuration;
  final void Function(T item)? onExecute;
  final void Function(T item)? onExpire;
  final void Function(T item)? onReject;
  final bool started;
  final int? concurrency;
  final void Function(dynamic result)? onSuccess;
  final void Function(dynamic error)? onError;
  final void Function(dynamic result, dynamic error)? onSettled;
  final bool throwOnError;

  AsyncQueuerOptions({
    super.enabled = true,
    super.key,
    this.wait,
    this.maxSize,
    this.addItemsTo = QueuePosition.back,
    this.getItemsFrom = QueuePosition.front,
    this.getPriority,
    this.expirationDuration,
    this.onExecute,
    this.onExpire,
    this.onReject,
    this.started = false,
    this.concurrency = 1,
    this.onSuccess,
    this.onError,
    this.onSettled,
    this.throwOnError = false,
  });
}

class AsyncQueuerState<T> extends PacerState {
  final int addItemCount;
  final int expirationCount;
  final int rejectionCount;
  final List<T> items;
  final List<DateTime> itemTimestamps;
  final bool isEmpty;
  final bool isFull;
  final bool isRunning;
  final int size;
  final List<T> activeItems;
  final List<T> pendingItems;
  final int errorCount;
  final int successCount;
  final int settleCount;
  final bool isExecuting;
  final dynamic lastResult;

  AsyncQueuerState({
    super.executionCount = 0,
    super.status = PacerStatus.idle,
    this.addItemCount = 0,
    this.expirationCount = 0,
    this.rejectionCount = 0,
    this.items = const [],
    this.itemTimestamps = const [],
    this.isEmpty = true,
    this.isFull = false,
    this.isRunning = false,
    this.size = 0,
    this.activeItems = const [],
    this.pendingItems = const [],
    this.errorCount = 0,
    this.successCount = 0,
    this.settleCount = 0,
    this.isExecuting = false,
    this.lastResult,
  });

  AsyncQueuerState<T> copyWith({
    int? executionCount,
    PacerStatus? status,
    int? addItemCount,
    int? expirationCount,
    int? rejectionCount,
    List<T>? items,
    List<DateTime>? itemTimestamps,
    bool? isEmpty,
    bool? isFull,
    bool? isRunning,
    int? size,
    List<T>? activeItems,
    List<T>? pendingItems,
    int? errorCount,
    int? successCount,
    int? settleCount,
    bool? isExecuting,
    dynamic lastResult,
  }) {
    return AsyncQueuerState<T>(
      executionCount: executionCount ?? this.executionCount,
      status: status ?? this.status,
      addItemCount: addItemCount ?? this.addItemCount,
      expirationCount: expirationCount ?? this.expirationCount,
      rejectionCount: rejectionCount ?? this.rejectionCount,
      items: items ?? this.items,
      itemTimestamps: itemTimestamps ?? this.itemTimestamps,
      isEmpty: isEmpty ?? this.isEmpty,
      isFull: isFull ?? this.isFull,
      isRunning: isRunning ?? this.isRunning,
      size: size ?? this.size,
      activeItems: activeItems ?? this.activeItems,
      pendingItems: pendingItems ?? this.pendingItems,
      errorCount: errorCount ?? this.errorCount,
      successCount: successCount ?? this.successCount,
      settleCount: settleCount ?? this.settleCount,
      isExecuting: isExecuting ?? this.isExecuting,
      lastResult: lastResult ?? this.lastResult,
    );
  }
}

class AsyncQueuer<T> extends ChangeNotifier {
  final AnyAsyncFunction fn;
  AsyncQueuerOptions<T> _options;
  AsyncQueuerState<T> _state;
  Timer? _processTimer;
  final Queue<T> _queue = Queue<T>();
  final List<DateTime> _timestamps = [];
  final Set<Completer> _activeCompleters = {};
  bool _aborted = false;

  AsyncQueuer(this.fn, AsyncQueuerOptions<T> options)
      : _options = options,
        _state = AsyncQueuerState() {
    if (!_options.enabled) {
      _state = _state.copyWith(status: PacerStatus.disabled);
    } else if (_options.started) {
      start();
    }
  }

  AsyncQueuerOptions<T> get options => _options;
  AsyncQueuerState<T> get state => _state;

  Future<dynamic> addItem(T item, [QueuePosition position = QueuePosition.back, bool runOnItemsChange = true]) async {
    if (!_options.enabled) {
      throw Exception('Queuer is disabled');
    }

    if (_options.maxSize != null && _queue.length >= _options.maxSize!) {
      _options.onReject?.call(item);
      _state = _state.copyWith(rejectionCount: _state.rejectionCount + 1);
      notifyListeners();
      throw Exception('Queue is full');
    }

    final completer = Completer();
    _activeCompleters.add(completer);

    if (_options.addItemsTo == QueuePosition.back) {
      _queue.add(item);
    } else {
      _queue.addFirst(item);
    }
    _timestamps.add(DateTime.now());

    _state = _state.copyWith(
      addItemCount: _state.addItemCount + 1,
      items: _queue.toList(),
      itemTimestamps: List.from(_timestamps),
      pendingItems: [..._state.pendingItems, item],
      isEmpty: _queue.isEmpty,
      isFull: _options.maxSize != null && _queue.length >= _options.maxSize!,
      size: _queue.length,
    );
    notifyListeners();

    if (_state.isRunning) {
      _scheduleNext();
    }

    return completer.future;
  }

  T? getNextItem() {
    if (_queue.isEmpty) return null;

    _expireItems();

    if (_queue.isEmpty) return null;

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
      pendingItems: _state.pendingItems.where((i) => i != item).toList(),
      activeItems: [..._state.activeItems, item],
      isEmpty: _queue.isEmpty,
      isFull: _options.maxSize != null && _queue.length >= _options.maxSize!,
      size: _queue.length,
    );
    notifyListeners();

    return item;
  }

  void _expireItems() {
    if (_options.expirationDuration == null) return;

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

  void start() {
    if (_state.isRunning) return;

    _state = _state.copyWith(isRunning: true, status: PacerStatus.running);
    notifyListeners();
    _scheduleNext();
  }

  void stop() {
    _processTimer?.cancel();
    _state = _state.copyWith(isRunning: false, status: PacerStatus.idle);
    notifyListeners();
  }

  void _scheduleNext() {
    if (!_state.isRunning || _queue.isEmpty || _aborted) return;

    final activeCount = _state.activeItems.length;
    if (_options.concurrency != null && activeCount >= _options.concurrency!) return;

    if (_options.wait != null) {
      _processTimer = Timer(_options.wait!, _processNext);
    } else {
      _processNext();
    }
  }

  void _processNext() async {
    final item = getNextItem();
    if (item == null || _aborted) return;

    _state = _state.copyWith(isExecuting: true, status: PacerStatus.executing);
    notifyListeners();

    try {
      final result = await fn([item]);
      if (!_aborted) {
        _options.onExecute?.call(item);
        _options.onSuccess?.call(result);
        _state = _state.copyWith(
          executionCount: _state.executionCount + 1,
          successCount: _state.successCount + 1,
          settleCount: _state.settleCount + 1,
          lastResult: result,
          activeItems: _state.activeItems.where((i) => i != item).toList(),
          isExecuting: false,
        );
        // Complete the corresponding completer
        final completer = _activeCompleters.firstWhere((c) => !c.isCompleted);
        completer.complete(result);
        _activeCompleters.remove(completer);
      }
    } catch (e) {
      if (!_aborted) {
        _options.onError?.call(e);
        _state = _state.copyWith(
          errorCount: _state.errorCount + 1,
          settleCount: _state.settleCount + 1,
          activeItems: _state.activeItems.where((i) => i != item).toList(),
          isExecuting: false,
        );
        final completer = _activeCompleters.firstWhere((c) => !c.isCompleted);
        if (_options.throwOnError) {
          completer.completeError(e);
        } else {
          completer.complete(null);
        }
        _activeCompleters.remove(completer);
      }
    } finally {
      _options.onSettled?.call(_state.lastResult, null);
      notifyListeners();
      _scheduleNext();
    }
  }

  void clear() {
    _queue.clear();
    _timestamps.clear();
    _state = _state.copyWith(
      items: [],
      itemTimestamps: [],
      activeItems: [],
      pendingItems: [],
      isEmpty: true,
      isFull: false,
      size: 0,
    );
    notifyListeners();
  }

  void reset() {
    clear();
    _state = _state.copyWith(
      addItemCount: 0,
      executionCount: 0,
      expirationCount: 0,
      rejectionCount: 0,
      errorCount: 0,
      successCount: 0,
      settleCount: 0,
    );
    notifyListeners();
  }

  void flush() {
    while (_queue.isNotEmpty && !_aborted) {
      _processNext();
    }
  }

  List<T> peekAllItems() => _queue.toList();
  List<T> peekActiveItems() => _state.activeItems;
  List<T> peekPendingItems() => _state.pendingItems;

  void abort() {
    _aborted = true;
    _processTimer?.cancel();
    _state = _state.copyWith(status: PacerStatus.idle);
    for (final completer in _activeCompleters) {
      if (!completer.isCompleted) {
        completer.completeError('Aborted');
      }
    }
    _activeCompleters.clear();
    notifyListeners();
  }

  void setOptions(AsyncQueuerOptions<T> options) {
    _options = options;
    if (!_options.enabled) {
      abort();
      _state = _state.copyWith(status: PacerStatus.disabled);
    } else if (_options.started && !_state.isRunning) {
      start();
    }
    notifyListeners();
  }
}