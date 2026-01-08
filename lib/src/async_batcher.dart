import 'dart:async';
import 'package:flutter/foundation.dart';
import 'common.dart';
import 'batcher.dart';

class AsyncBatcherOptions<T> extends PacerOptions {
  final int? maxSize;
  final Duration? wait;
  final ShouldExecuteGetter<T>? getShouldExecute;
  final void Function(List<T> items)? onExecute;
  final void Function(List<T> items)? onItemsChange;
  final bool started;
  final void Function(dynamic result)? onSuccess;
  final void Function(dynamic error)? onError;
  final void Function(dynamic result, dynamic error)? onSettled;
  final bool throwOnError;

  AsyncBatcherOptions({
    super.enabled = true,
    super.key,
    this.maxSize,
    this.wait,
    this.getShouldExecute,
    this.onExecute,
    this.onItemsChange,
    this.started = false,
    this.onSuccess,
    this.onError,
    this.onSettled,
    this.throwOnError = false,
  });
}

class AsyncBatcherState<T> extends PacerState {
  final List<T> items;
  final bool isEmpty;
  final bool isPending;
  final int size;
  final int totalItemsProcessed;
  final List<T> failedItems;
  final int errorCount;
  final int successCount;
  final int settleCount;
  final bool isExecuting;
  final dynamic lastResult;

  AsyncBatcherState({
    super.executionCount = 0,
    super.status = PacerStatus.idle,
    this.items = const [],
    this.isEmpty = true,
    this.isPending = false,
    this.size = 0,
    this.totalItemsProcessed = 0,
    this.failedItems = const [],
    this.errorCount = 0,
    this.successCount = 0,
    this.settleCount = 0,
    this.isExecuting = false,
    this.lastResult,
  });

  AsyncBatcherState<T> copyWith({
    int? executionCount,
    PacerStatus? status,
    List<T>? items,
    bool? isEmpty,
    bool? isPending,
    int? size,
    int? totalItemsProcessed,
    List<T>? failedItems,
    int? errorCount,
    int? successCount,
    int? settleCount,
    bool? isExecuting,
    dynamic lastResult,
  }) {
    return AsyncBatcherState<T>(
      executionCount: executionCount ?? this.executionCount,
      status: status ?? this.status,
      items: items ?? this.items,
      isEmpty: isEmpty ?? this.isEmpty,
      isPending: isPending ?? this.isPending,
      size: size ?? this.size,
      totalItemsProcessed: totalItemsProcessed ?? this.totalItemsProcessed,
      failedItems: failedItems ?? this.failedItems,
      errorCount: errorCount ?? this.errorCount,
      successCount: successCount ?? this.successCount,
      settleCount: settleCount ?? this.settleCount,
      isExecuting: isExecuting ?? this.isExecuting,
      lastResult: lastResult ?? this.lastResult,
    );
  }
}

class AsyncBatcher<T> extends ChangeNotifier {
  final AnyAsyncFunction fn;
  AsyncBatcherOptions<T> _options;
  AsyncBatcherState<T> _state;
  Timer? _batchTimer;
  Completer? _completer;
  bool _aborted = false;

  AsyncBatcher(this.fn, AsyncBatcherOptions<T> options)
      : _options = options,
        _state = AsyncBatcherState() {
    if (!_options.enabled) {
      _state = _state.copyWith(status: PacerStatus.disabled);
    }
  }

  AsyncBatcherOptions<T> get options => _options;
  AsyncBatcherState<T> get state => _state;

  Future<dynamic> addItem(T item) async {
    if (!_options.enabled) {
      throw Exception('Batcher is disabled');
    }

    _completer = Completer();

    _state = _state.copyWith(
      items: [..._state.items, item],
      isEmpty: false,
      size: _state.size + 1,
    );
    _options.onItemsChange?.call(_state.items);
    notifyListeners();

    if (_shouldExecute()) {
      return execute();
    } else if (_options.wait != null && !_state.isPending) {
      _scheduleExecute();
    }

    return _completer!.future;
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
    _batchTimer = Timer(_options.wait!, () => execute().then((result) {
      if (_completer != null && !_completer!.isCompleted) {
        _completer!.complete(result);
      }
    }).catchError((e) {
      if (_completer != null && !_completer!.isCompleted) {
        _completer!.completeError(e);
      }
    }));
  }

  Future<List<T>> execute() async {
    if (_state.items.isEmpty) return [];

    _batchTimer?.cancel();
    final itemsToExecute = List<T>.from(_state.items);

    _state = _state.copyWith(
      items: [],
      isEmpty: true,
      isPending: false,
      size: 0,
      status: PacerStatus.executing,
      isExecuting: true,
    );
    notifyListeners();

    try {
      final result = await fn([itemsToExecute]);
      if (!_aborted) {
        _options.onExecute?.call(itemsToExecute);
        _options.onSuccess?.call(result);
        _state = _state.copyWith(
          executionCount: _state.executionCount + 1,
          successCount: _state.successCount + 1,
          settleCount: _state.settleCount + 1,
          lastResult: result,
          totalItemsProcessed: _state.totalItemsProcessed + itemsToExecute.length,
          isExecuting: false,
          status: PacerStatus.idle,
        );
        if (_completer != null && !_completer!.isCompleted) {
          _completer!.complete(itemsToExecute);
        }
        return itemsToExecute;
      } else {
        throw Exception('Aborted');
      }
    } catch (e) {
      if (!_aborted) {
        _options.onError?.call(e);
        _state = _state.copyWith(
          errorCount: _state.errorCount + 1,
          settleCount: _state.settleCount + 1,
          failedItems: [..._state.failedItems, ...itemsToExecute],
          isExecuting: false,
          status: PacerStatus.idle,
        );
        if (_options.throwOnError) {
          if (_completer != null && !_completer!.isCompleted) {
            _completer!.completeError(e);
          }
          rethrow;
        } else {
          if (_completer != null && !_completer!.isCompleted) {
            _completer!.complete([]);
          }
          return [];
        }
      } else {
        throw Exception('Aborted');
      }
    } finally {
      _options.onSettled?.call(_state.lastResult, null);
      notifyListeners();
    }
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

  void abort() {
    _aborted = true;
    _batchTimer?.cancel();
    _state = _state.copyWith(status: PacerStatus.idle);
    if (_completer != null && !_completer!.isCompleted) {
      _completer!.completeError('Aborted');
    }
    notifyListeners();
  }

  void setOptions(AsyncBatcherOptions<T> options) {
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