/// An asynchronous function that accepts any type of arguments.
///
/// Used for async operations in pacers like [AsyncRetryer], [AsyncBatcher], etc.
/// The function can accept any type of argument and return a Future of any type.
typedef AnyAsyncFunction = Future<dynamic> Function(dynamic args);

/// A synchronous function that accepts any type of arguments.
///
/// Used throughout the GnrllyBttrPacer package for flexible function signatures.
/// The function can accept any type of argument and return any type.
typedef AnyFunction = void Function(dynamic args);

/// Function type for determining item priority in a priority queue.
///
/// Returns an integer priority value where lower numbers indicate higher priority.
/// Used by [QueuerOptions.getPriority] to determine processing order.
///
/// Example:
/// ```dart
/// PriorityGetter<Task> priorityFn = (task) => task.urgencyLevel;
/// // Lower urgencyLevel = higher priority
/// ```
typedef PriorityGetter<T> = int Function(T item);

/// Function type for determining if a batch should execute based on its items.
typedef ShouldExecuteGetter<T> = bool Function(List<T> items);
