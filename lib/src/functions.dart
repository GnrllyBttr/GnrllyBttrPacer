import 'dart:async';
import 'common.dart';
import 'debouncer.dart';
import 'async_debouncer.dart';
import 'throttler.dart';
import 'async_throttler.dart';
import 'rate_limiter.dart';
import 'async_rate_limiter.dart';
import 'queuer.dart';
import 'async_queuer.dart';
import 'batcher.dart';
import 'async_batcher.dart';
import 'retryer.dart';

/// Convenience functions for creating debounced functions

AnyFunction debounce(
  AnyFunction fn,
  DebouncerOptions options,
) {
  final debouncer = Debouncer(fn, options);
  return (List<dynamic> args) => debouncer.maybeExecute(args);
}

AnyAsyncFunction asyncDebounce(
  AnyAsyncFunction fn,
  AsyncDebouncerOptions options,
) {
  final debouncer = AsyncDebouncer(fn, options);
  return (List<dynamic> args) => debouncer.maybeExecute(args);
}

/// Convenience functions for creating throttled functions

AnyFunction throttle(
  AnyFunction fn,
  ThrottlerOptions options,
) {
  final throttler = Throttler(fn, options);
  return (List<dynamic> args) => throttler.maybeExecute(args);
}

AnyAsyncFunction asyncThrottle(
  AnyAsyncFunction fn,
  AsyncThrottlerOptions options,
) {
  final throttler = AsyncThrottler(fn, options);
  return (List<dynamic> args) => throttler.maybeExecute(args);
}

/// Convenience functions for creating rate-limited functions

bool Function(List<dynamic>) rateLimit(
  AnyFunction fn,
  RateLimiterOptions options,
) {
  final rateLimiter = RateLimiter(fn, options);
  return (List<dynamic> args) => rateLimiter.maybeExecute(args);
}

AnyAsyncFunction asyncRateLimit(
  AnyAsyncFunction fn,
  AsyncRateLimiterOptions options,
) {
  final rateLimiter = AsyncRateLimiter(fn, options);
  return (List<dynamic> args) => rateLimiter.maybeExecute(args);
}

/// Convenience functions for creating queued functions

bool Function(dynamic, [QueuePosition?, bool?]) queue<T>(
  AnyFunction fn,
  QueuerOptions<T> options,
) {
  final queuer = Queuer<T>(fn, options);
  return (item, [QueuePosition? position, bool? runOnItemsChange]) =>
      queuer.addItem(item, position ?? QueuePosition.back, runOnItemsChange ?? true);
}

Future<dynamic> Function(dynamic, [QueuePosition?, bool?]) asyncQueue<T>(
  AnyAsyncFunction fn,
  AsyncQueuerOptions<T> options,
) {
  final queuer = AsyncQueuer<T>(fn, options);
  return (item, [QueuePosition? position, bool? runOnItemsChange]) =>
      queuer.addItem(item, position ?? QueuePosition.back, runOnItemsChange ?? true);
}

/// Convenience functions for creating batched functions

void Function(dynamic) batch<T>(
  AnyFunction fn,
  BatcherOptions<T> options,
) {
  final batcher = Batcher<T>(fn, options);
  return (item) => batcher.addItem(item);
}

Future<dynamic> Function(dynamic) asyncBatch<T>(
  AnyAsyncFunction fn,
  AsyncBatcherOptions<T> options,
) {
  final batcher = AsyncBatcher<T>(fn, options);
  return (item) => batcher.addItem(item);
}

/// Convenience functions for creating retried functions

AnyAsyncFunction asyncRetry(
  AnyAsyncFunction fn,
  AsyncRetryerOptions options,
) {
  final retryer = AsyncRetryer(fn, options);
  return (List<dynamic> args) => retryer.execute(args);
}

/// Utility functions

bool isFunction(dynamic value) {
  return value is Function;
}

dynamic parseFunctionOrValue(dynamic value, [List<dynamic>? args]) {
  if (value is Function) {
    return value(args ?? []);
  }
  return value;
}