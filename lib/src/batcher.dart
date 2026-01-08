import 'dart:async';
import 'package:flutter/foundation.dart';
import 'common.dart';

typedef ShouldExecuteGetter<T> = bool Function(List<T> items);

class BatcherOptions<T> extends PacerOptions {
  final int? maxSize;
  final Duration? wait;
  final ShouldExecuteGetter<T>? getShouldExecute;
  final void Function(List<T> items)? onExecute;
  final void Function(List<T> items)? onItemsChange;
  final bool started;

  BatcherOptions({
    super.enabled = true,
    super.key,
    this.maxSize,
    this.wait,
    this.getShouldExecute,
    this.onExecute,
    this.onItemsChange,
    this.started = false,
  });
}

class BatcherState<T> extends PacerState {
  final List<T> items;
  final bool isEmpty;
  final bool isPending;
  final int size;
  final int totalItemsProcessed;

  BatcherState({
    super.executionCount = 0,
    super.status = PacerStatus.idle,
    this.items = const [],
    this.isEmpty = true,
    this.isPending = false,
    this.size = 0,
    this.totalItemsProcessed = 0,
  });

  BatcherState<T> copyWith({
    int? executionCount,
    PacerStatus? status,
    List<T>? items,
    bool? isEmpty,
    bool? isPending,
    int? size,
    int? totalItemsProcessed,
  }) {
    return BatcherState<T>(
      executionCount: executionCount ?? this.executionCount,
      status: status ?? this.status,
      items: items ?? this.items,
      isEmpty: isEmpty ?? this.isEmpty,
      isPending: isPending ?? this.isPending,
      size: size ?? this.size,
      totalItemsProcessed: totalItemsProcessed ?? this.totalItemsProcessed,
    );
  }
}

class Batcher<T> extends ChangeNotifier {
  final AnyFunction fn;
  BatcherOptions<T> _options;
  BatcherState<T> _state;
  Timer? _batchTimer;

  Batcher(this.fn, BatcherOptions<T> options)
      : _options = options,
        _state = BatcherState() {
    if (!_options.enabled) {
      _state = _state.copyWith(status: PacerStatus.disabled);
    } else if (_options.started) {
      // Batches start automatically if started
    }
  }

  BatcherOptions<T> get options => _options;
  BatcherState<T> get state => _state;

  void addItem(T item) {
    if (!_options.enabled) return;

    _state = _state.copyWith(
      items: [..._state.items, item],
      isEmpty: false,
      size: _state.size + 1,
    );
    _options.onItemsChange?.call(_state.items);
    notifyListeners();

    if (_shouldExecute()) {
      execute();
    } else if (_options.wait != null && !_state.isPending) {
      _scheduleExecute();
    }
  }

  bool _shouldExecute() {
    if (_options.getShouldExecute != null) {
      return _options.getShouldExecute!(_state.items);
    }
    return _options.maxSize != null && _state.size >= _options.maxSize!;
  }

  void _scheduleExecute() {
    _state = _state.copyWith(isPending: true, status: PacerStatus.pending);
    notifyListeners();
    _batchTimer = Timer(_options.wait!, execute);
  }

  void execute() {
    if (_state.items.isEmpty) return;

    _batchTimer?.cancel();
    final itemsToExecute = List<T>.from(_state.items);

    _state = _state.copyWith(
      items: [],
      isEmpty: true,
      isPending: false,
      size: 0,
      status: PacerStatus.idle,
    );
    notifyListeners();

    try {
      fn([itemsToExecute]);
      _options.onExecute?.call(itemsToExecute);
      _state = _state.copyWith(
        executionCount: _state.executionCount + 1,
        totalItemsProcessed: _state.totalItemsProcessed + itemsToExecute.length,
      );
    } catch (e) {
      // Handle error if needed
    }
    notifyListeners();
  }

  void stop() {
    _batchTimer?.cancel();
    _state = _state.copyWith(isPending: false, status: PacerStatus.idle);
    notifyListeners();
  }

  void flush() {
    if (_state.items.isNotEmpty) {
      execute();
    }
  }

  List<T> peekAllItems() => _state.items;

  void setOptions(BatcherOptions<T> options) {
    _options = options;
    if (!_options.enabled) {
      stop();
      _state = _state.copyWith(status: PacerStatus.disabled);
    } else {
      _state = _state.copyWith(status: PacerStatus.idle);
    }
    notifyListeners();
  }
}