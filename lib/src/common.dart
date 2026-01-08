// Common types and utilities for GnrllyBttrPacer

typedef AnyFunction = void Function(List<dynamic> args);
typedef AnyAsyncFunction = Future<dynamic> Function(List<dynamic> args);

enum QueuePosition { front, back }

enum PacerStatus { disabled, idle, pending, executing, running }

class PacerOptions {
  final bool enabled;
  final String? key;

  PacerOptions({this.enabled = true, this.key});
}

class PacerState {
  final int executionCount;
  final PacerStatus status;

  PacerState({this.executionCount = 0, this.status = PacerStatus.idle});
}