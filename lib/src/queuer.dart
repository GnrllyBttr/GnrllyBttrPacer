import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'common.dart';

typedef PriorityGetter<T> = int Function(T item);

class QueuerOptions<T> extends PacerOptions {
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

  QueuerOptions({
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
  });
}

class QueuerState<T> extends PacerState {
  final int addItemCount;
  final int expirationCount;
  final int rejectionCount;
  final List<T> items;
  final List<DateTime> itemTimestamps;
  final bool isEmpty;
  final bool isFull;
  final bool isRunning;
  final int size;

  QueuerState({
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
  });

  QueuerState<T> copyWith({
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
  }) {
    return QueuerState<T>(
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
    );
  }
}

class Queuer<T> extends ChangeNotifier {
  final AnyFunction fn;
  QueuerOptions<T> _options;
  QueuerState<T> _state;
  Timer? _processTimer;
  final Queue<T> _queue = Queue<T>();
  final List<DateTime> _timestamps = [];

  Queuer(this.fn, QueuerOptions<T> options)
      : _options = options,
        _state = QueuerState() {
    if (!_options.enabled) {
      _state = _state.copyWith(status: PacerStatus.disabled);
    } else if (_options.started) {
      start();
    }
  }

  QueuerOptions<T> get options => _options;
  QueuerState<T> get state => _state;

  bool addItem(T item, [QueuePosition position = QueuePosition.back, bool runOnItemsChange = true]) {
    if (!_options.enabled) return false;

    if (_options.maxSize != null && _queue.length >= _options.maxSize!) {
      _options.onReject?.call(item);
      _state = _state.copyWith(rejectionCount: _state.rejectionCount + 1);
      notifyListeners();
      return false;
    }

    if (position == QueuePosition.back) {
      _queue.add(item);
    } else {
      _queue.addFirst(item);
    }
    _timestamps.add(DateTime.now());

    _state = _state.copyWith(
      addItemCount: _state.addItemCount + 1,
      items: _queue.toList(),
      itemTimestamps: List.from(_timestamps),
      isEmpty: _queue.isEmpty,
      isFull: _options.maxSize != null && _queue.length >= _options.maxSize!,
      size: _queue.length,
    );
    notifyListeners();

    if (_state.isRunning) {
      _scheduleNext();
    }

    return true;
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
    if (!_state.isRunning || _queue.isEmpty) return;

    if (_options.wait != null) {
      _processTimer = Timer(_options.wait!, _processNext);
    } else {
      _processNext();
    }
  }

  void _processNext() {
    final item = getNextItem();
    if (item != null) {
      try {
        fn([item]);
        _options.onExecute?.call(item);
        _state = _state.copyWith(executionCount: _state.executionCount + 1);
      } catch (e) {
        // Handle error if needed
      }
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
    );
    notifyListeners();
  }

  void flush() {
    while (_queue.isNotEmpty) {
      _processNext();
    }
  }

  List<T> peekAllItems() => _queue.toList();

  void setOptions(QueuerOptions<T> options) {
    _options = options;
    if (!_options.enabled) {
      stop();
      _state = _state.copyWith(status: PacerStatus.disabled);
    } else if (_options.started && !_state.isRunning) {
      start();
    }
    notifyListeners();
  }
}