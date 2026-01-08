import 'package:flutter_test/flutter_test.dart';
import 'package:gnrllybttr_pacer/gnrllybttr_pacer.dart';

void main() {
  group('GnrllyBttrPacer Comprehensive Tests', () {
    // Test all core classes can be instantiated
    test('All core classes instantiate correctly', () {
      final debouncer = Debouncer((args) {}, DebouncerOptions(wait: const Duration(milliseconds: 100)));
      final throttler = Throttler((args) {}, ThrottlerOptions(wait: const Duration(milliseconds: 100)));
      final rateLimiter = RateLimiter((args) {}, RateLimiterOptions(limit: 5, window: const Duration(seconds: 1)));
      final queuer = Queuer((args) {}, QueuerOptions(wait: const Duration(milliseconds: 100)));
      final batcher = Batcher((args) {}, BatcherOptions(maxSize: 5, wait: const Duration(seconds: 1)));

      expect(debouncer, isNotNull);
      expect(throttler, isNotNull);
      expect(rateLimiter, isNotNull);
      expect(queuer, isNotNull);
      expect(batcher, isNotNull);

      debouncer.dispose();
      throttler.dispose();
      rateLimiter.dispose();
      queuer.dispose();
      batcher.dispose();
    });

    // Test all async classes can be instantiated
    test('All async classes instantiate correctly', () {
      final asyncDebouncer = AsyncDebouncer((args) async {}, AsyncDebouncerOptions(wait: const Duration(milliseconds: 100)));
      final asyncThrottler = AsyncThrottler((args) async {}, AsyncThrottlerOptions(wait: const Duration(milliseconds: 100)));
      final asyncRateLimiter = AsyncRateLimiter((args) async {}, AsyncRateLimiterOptions(limit: 5, window: const Duration(seconds: 1)));
      final asyncQueuer = AsyncQueuer((args) async {}, AsyncQueuerOptions(wait: const Duration(milliseconds: 100)));
      final asyncBatcher = AsyncBatcher((args) async {}, AsyncBatcherOptions(maxSize: 5, wait: const Duration(seconds: 1)));
      final asyncRetryer = AsyncRetryer((args) async {}, AsyncRetryerOptions());

      expect(asyncDebouncer, isNotNull);
      expect(asyncThrottler, isNotNull);
      expect(asyncRateLimiter, isNotNull);
      expect(asyncQueuer, isNotNull);
      expect(asyncBatcher, isNotNull);
      expect(asyncRetryer, isNotNull);

      asyncDebouncer.dispose();
      asyncThrottler.dispose();
      asyncRateLimiter.dispose();
      asyncQueuer.dispose();
      asyncBatcher.dispose();
      asyncRetryer.dispose();
    });

    // Test initial states
    test('All classes have correct initial states', () {
      final debouncer = Debouncer((args) {}, DebouncerOptions(wait: const Duration(milliseconds: 100)));
      final throttler = Throttler((args) {}, ThrottlerOptions(wait: const Duration(milliseconds: 100)));
      final rateLimiter = RateLimiter((args) {}, RateLimiterOptions(limit: 5, window: const Duration(seconds: 1)));
      final queuer = Queuer((args) {}, QueuerOptions(wait: const Duration(milliseconds: 100)));
      final batcher = Batcher((args) {}, BatcherOptions(maxSize: 5, wait: const Duration(seconds: 1)));

      expect(debouncer.state.status, PacerStatus.idle);
      expect(debouncer.state.executionCount, 0);
      expect(debouncer.state.isPending, false);

      expect(throttler.state.status, PacerStatus.idle);
      expect(throttler.state.executionCount, 0);

      expect(rateLimiter.state.status, PacerStatus.idle);
      expect(rateLimiter.state.executionCount, 0);

      expect(queuer.state.status, PacerStatus.idle);
      expect(queuer.state.size, 0);

      expect(batcher.state.status, PacerStatus.idle);
      expect(batcher.state.size, 0);

      debouncer.dispose();
      throttler.dispose();
      rateLimiter.dispose();
      queuer.dispose();
      batcher.dispose();
    });

    // Test synchronous operations
    test('Synchronous operations work', () {
      int debounceCount = 0;
      int throttleCount = 0;
      int rateLimitCount = 0;

      final debouncer = Debouncer(
        (args) => debounceCount++,
        DebouncerOptions(wait: const Duration(milliseconds: 100)),
      );

      final throttler = Throttler(
        (args) => throttleCount++,
        ThrottlerOptions(wait: const Duration(milliseconds: 100)),
      );

      final rateLimiter = RateLimiter(
        (args) => rateLimitCount++,
        RateLimiterOptions(limit: 2, window: const Duration(seconds: 1)),
      );

      // Test debouncer (should not execute immediately)
      debouncer.maybeExecute([]);
      expect(debounceCount, 0);
      expect(debouncer.state.isPending, true);

      // Test throttler (should execute immediately)
      throttler.maybeExecute([]);
      expect(throttleCount, 1);

      // Test rate limiter
      expect(rateLimiter.maybeExecute([]), true);
      expect(rateLimiter.maybeExecute([]), true);
      expect(rateLimiter.maybeExecute([]), false); // Exceeded limit
      expect(rateLimitCount, 2);

      debouncer.dispose();
      throttler.dispose();
      rateLimiter.dispose();
    });

    // Test queuer operations
    test('Queuer operations work', () {
      int processCount = 0;
      final queuer = Queuer(
        (args) => processCount++,
        QueuerOptions(wait: const Duration(milliseconds: 50)),
      );

      expect(queuer.addItem('item1'), true);
      expect(queuer.addItem('item2'), true);
      expect(queuer.state.size, 2);

      queuer.dispose();
    });

    // Test batcher operations
    test('Batcher operations work', () {
      int batchCount = 0;
      final batcher = Batcher(
        (args) => batchCount++,
        BatcherOptions(maxSize: 3, wait: const Duration(seconds: 1)),
      );

      batcher.addItem('item1');
      batcher.addItem('item2');
      expect(batcher.state.size, 2);

      batcher.dispose();
    });

    // Test convenience functions
    test('All convenience functions create valid functions', () {
      final debounceFn = debounce((args) {}, DebouncerOptions(wait: const Duration(milliseconds: 100)));
      final throttleFn = throttle((args) {}, ThrottlerOptions(wait: const Duration(milliseconds: 100)));
      final rateLimitFn = rateLimit((args) {}, RateLimiterOptions(limit: 5, window: const Duration(seconds: 1)));
      final queueFn = queue((args) {}, QueuerOptions(wait: const Duration(milliseconds: 100)));
      final batchFn = batch((args) {}, BatcherOptions(maxSize: 5, wait: const Duration(seconds: 1)));

      final asyncDebounceFn = asyncDebounce((args) async {}, AsyncDebouncerOptions(wait: const Duration(milliseconds: 100)));
      final asyncThrottleFn = asyncThrottle((args) async {}, AsyncThrottlerOptions(wait: const Duration(milliseconds: 100)));
      final asyncRateLimitFn = asyncRateLimit((args) async {}, AsyncRateLimiterOptions(limit: 5, window: const Duration(seconds: 1)));
      final asyncQueueFn = asyncQueue((args) async {}, AsyncQueuerOptions(wait: const Duration(milliseconds: 100)));
      final asyncBatchFn = asyncBatch((args) async {}, AsyncBatcherOptions(maxSize: 5, wait: const Duration(seconds: 1)));
      final asyncRetryFn = asyncRetry((args) async {}, AsyncRetryerOptions());

      expect(debounceFn, isA<Function>());
      expect(throttleFn, isA<Function>());
      expect(rateLimitFn, isA<Function>());
      expect(queueFn, isA<Function>());
      expect(batchFn, isA<Function>());
      expect(asyncDebounceFn, isA<Function>());
      expect(asyncThrottleFn, isA<Function>());
      expect(asyncRateLimitFn, isA<Function>());
      expect(asyncQueueFn, isA<Function>());
      expect(asyncBatchFn, isA<Function>());
      expect(asyncRetryFn, isA<Function>());
    });

    // Test options classes
    test('All options classes create with required parameters', () {
      final debounceOpts = DebouncerOptions(wait: const Duration(milliseconds: 100));
      final throttleOpts = ThrottlerOptions(wait: const Duration(milliseconds: 100));
      final rateLimitOpts = RateLimiterOptions(limit: 5, window: const Duration(seconds: 1));
      final queueOpts = QueuerOptions(wait: const Duration(milliseconds: 100));
      final batchOpts = BatcherOptions(maxSize: 5, wait: const Duration(seconds: 1));
      final retryOpts = AsyncRetryerOptions();

      expect(debounceOpts.wait, const Duration(milliseconds: 100));
      expect(throttleOpts.wait, const Duration(milliseconds: 100));
      expect(rateLimitOpts.limit, 5);
      expect(queueOpts.wait, const Duration(milliseconds: 100));
      expect(batchOpts.maxSize, 5);
      expect(retryOpts.maxAttempts, 3);
    });

    // Test enums
    test('All enums have correct values', () {
      expect(PacerStatus.values.length, 5);
      expect(QueuePosition.values.length, 2);
      expect(WindowType.values.length, 2);
      expect(BackoffType.values.length, 3);

      expect(PacerStatus.idle, PacerStatus.values[1]);
      expect(QueuePosition.front, QueuePosition.values[0]);
      expect(WindowType.fixed, WindowType.values[0]);
      expect(BackoffType.exponential, BackoffType.values[0]);
    });

    // Test utility functions
    test('Utility functions work correctly', () {
      expect(isFunction(() {}), true);
      expect(isFunction('string'), false);
      expect(isFunction(42), false);

      int callCount = 0;
      final result1 = parseFunctionOrValue((args) {
        callCount++;
        return 'called';
      });
      expect(result1, 'called');
      expect(callCount, 1);

      final result2 = parseFunctionOrValue('direct');
      expect(result2, 'direct');
    });

    // Test disabled state
    test('Disabled state works correctly', () {
      final debouncer = Debouncer(
        (args) {},
        DebouncerOptions(wait: const Duration(milliseconds: 100), enabled: false),
      );

      expect(debouncer.state.status, PacerStatus.disabled);

      debouncer.maybeExecute([]);
      expect(debouncer.state.executionCount, 0);

      debouncer.dispose();
    });

    // Test state copyWith methods
    test('State copyWith methods work', () {
      final debounceState = DebouncerState(
        executionCount: 1,
        status: PacerStatus.idle,
        maybeExecuteCount: 2,
        lastArgs: ['test'],
        isPending: false,
      );

      final newState = debounceState.copyWith(
        executionCount: 5,
        status: PacerStatus.pending,
        isPending: true,
      );

      expect(newState.executionCount, 5);
      expect(newState.status, PacerStatus.pending);
      expect(newState.maybeExecuteCount, 2); // Unchanged
      expect(newState.lastArgs, ['test']); // Unchanged
      expect(newState.isPending, true);
    });

    // Test rate limiter remaining count
    test('Rate limiter remaining count works', () {
      final rateLimiter = RateLimiter(
        (args) {},
        RateLimiterOptions(limit: 3, window: const Duration(seconds: 1)),
      );

      expect(rateLimiter.getRemainingInWindow(), 3);

      rateLimiter.maybeExecute([]);
      expect(rateLimiter.getRemainingInWindow(), 2);

      rateLimiter.maybeExecute([]);
      rateLimiter.maybeExecute([]);
      expect(rateLimiter.getRemainingInWindow(), 0);

      rateLimiter.dispose();
    });

    // Test configuration changes
    test('Configuration changes work', () {
      final debouncer = Debouncer(
        (args) {},
        DebouncerOptions(wait: const Duration(milliseconds: 100)),
      );

      expect(debouncer.options.wait, const Duration(milliseconds: 100));

      debouncer.setOptions(DebouncerOptions(wait: const Duration(milliseconds: 200)));
      expect(debouncer.options.wait, const Duration(milliseconds: 200));

      debouncer.dispose();
    });
  });
}