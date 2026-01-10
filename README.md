# GnrllyBttrPacer 🕒⚡

Developed with ❤️ by

[<img src="https://github.com/GnrllyBttr/gnrllybttr.dev/raw/production/images/logo.png" width="225" alt="GnrllyBttr Logo">](https://gnrllybttr.dev/)

[![GitHub Stars](https://img.shields.io/github/stars/GnrllyBttr/GnrllyBttrPacer.svg?logo=github)](https://github.com/GnrllyBttr/GnrllyBttrPacer/stargazers)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/GnrllyBttr/GnrllyBttrPacer/raw/main/LICENSE)
[![CI](https://github.com/GnrllyBttr/GnrllyBttrPacer/workflows/CI/badge.svg)](https://github.com/GnrllyBttr/GnrllyBttrPacer/actions)

[![Package](https://img.shields.io/pub/v/gnrllybttr_pacer.svg?logo=flutter)](https://pub.dartlang.org/packages/gnrllybttr_pacer)
[![Platform](https://img.shields.io/badge/platform-all-brightgreen.svg?logo=flutter)](https://img.shields.io/badge/platform-android%20|%20ios%20|%20linux%20|%20macos%20|%20web%20|%20windows-green.svg)
[![Likes](https://img.shields.io/pub/likes/gnrllybttr_pacer?logo=flutter)](https://pub.dev/packages/gnrllybttr_pacer/score)
[![Points](https://img.shields.io/pub/points/gnrllybttr_pacer?logo=flutter)](https://pub.dev/packages/gnrllybttr_pacer/score)

---

![Screenshot of GnrllyBttrPacer Demo](https://github.com/GnrllyBttr/GnrllyBttrPacer/raw/main/showcase.png)

## 📑 Table of Contents

- [GnrllyBttrPacer 🕒⚡](#gnrllybttrpacer-)
  - [📑 Table of Contents](#-table-of-contents)
  - [🌟 Features](#-features)
  - [🚀 Installation](#-installation)
  - [📚 Examples](#-examples)
    - [Debouncing Search Input](#debouncing-search-input)
    - [Throttling Button Clicks](#throttling-button-clicks)
    - [Rate Limiting API Calls](#rate-limiting-api-calls)
    - [Queuing Background Tasks](#queuing-background-tasks)
    - [Batching Operations](#batching-operations)
    - [Retrying Failed Requests](#retrying-failed-requests)
  - [🏁 Getting Started](#-getting-started)
  - [📖 Usage](#-usage)
    - [Debouncing](#debouncing)
    - [Throttling](#throttling)
    - [Rate Limiting](#rate-limiting)
    - [Queuing](#queuing)
    - [Batching](#batching)
    - [Retrying](#retrying)
    - [State Management](#state-management)
  - [🤝 Contributing](#-contributing)
  - [🆘 Support](#-support)
  - [📝 Changelog](#-changelog)
  - [📄 License](#-license)

---

## 🌟 Features

The `GnrllyBttrPacer` package provides high-quality utilities for controlling function execution timing in Flutter applications. Inspired by TanStack Pacer, it offers:

- **Debouncing**: Delay execution until after a period of inactivity
- **Throttling**: Smoothly limit the rate at which functions can fire
- **Rate Limiting**: Enforce execution limits over time windows (fixed/sliding)
- **Queuing**: Process items sequentially with FIFO/LIFO/priority support
- **Batching**: Group operations for efficient processing
- **Retrying**: Automatic retry with exponential backoff strategies
- **Reactive State**: Built-in ChangeNotifier for real-time state updates
- **Type Safety**: Full generics support with Dart's type system
- **Flutter Integration**: Designed for seamless Flutter app integration
- **Zero Dependencies**: Lightweight with no external dependencies
- **Cross-Platform**: Works on all Flutter-supported platforms

---

## 🚀 Installation

Add the following to your `pubspec.yaml` file:

```yaml
dependencies:
  gnrllybttr_pacer: ^1.0.0
```

Then run:

```shell
flutter pub get
```

---

## 📚 Examples

Here are various examples showing different ways to use GnrllyBttrPacer:

### Debouncing Search Input

```dart
class SearchWidget extends StatefulWidget {
  @override
  _SearchWidgetState createState() => _SearchWidgetState();
}

class _SearchWidgetState extends State<SearchWidget> {
  final TextEditingController _controller = TextEditingController();
  final Debouncer<String> _debouncer = Debouncer<String>(
    (query) async {
      if (query.isNotEmpty) {
        final results = await searchAPI(query);
        // Handle search results
      }
    },
    DebouncerOptions<String>(wait: const Duration(milliseconds: 300)),
  );

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: const InputDecoration(hintText: 'Search...'),
      onChanged: (value) => _debouncer.maybeExecute(value),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _debouncer.dispose();
    super.dispose();
  }
}
```

### Throttling Button Clicks

```dart
class ThrottledButton extends StatefulWidget {
  @override
  _ThrottledButtonState createState() => _ThrottledButtonState();
}

class _ThrottledButtonState extends State<ThrottledButton> {
  final Throttler<int> _throttler = Throttler<int>(
    (count) {
      debugPrint('Button clicked: $count');
      // Handle button action
    },
    ThrottlerOptions<int>(
      wait: const Duration(milliseconds: 1000),
      leading: true,
      trailing: false,
    ),
  );

  int _clickCount = 0;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        _clickCount++;
        _throttler.maybeExecute(_clickCount);
      },
      child: const Text('Throttled Button'),
    );
  }

  @override
  void dispose() {
    _throttler.dispose();
    super.dispose();
  }
}
```

### Rate Limiting API Calls

```dart
class ApiService {
  final RateLimiter<String> _rateLimiter = RateLimiter<String>(
    (endpoint) async {
      return await http.get(Uri.parse('https://api.example.com/$endpoint'));
    },
    RateLimiterOptions<String>(
      limit: 10,
      window: const Duration(minutes: 1),
      windowType: WindowType.sliding,
    ),
  );

  Future<http.Response> makeRequest(String endpoint) async {
    final allowed = _rateLimiter.maybeExecute(endpoint);
    if (allowed) {
      return await http.get(Uri.parse('https://api.example.com/$endpoint'));
    } else {
      throw Exception('Rate limit exceeded');
    }
  }
}
```

### Queuing Background Tasks

```dart
class TaskQueue extends StatefulWidget {
  @override
  _TaskQueueState createState() => _TaskQueueState();
}

class _TaskQueueState extends State<TaskQueue> {
  final Queuer<int> _queuer = Queuer<int>(
    (taskId) async {
      await processTask(taskId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Task $taskId completed')),
        );
      }
    },
    QueuerOptions<int>(
      wait: const Duration(milliseconds: 500),
      maxSize: 10,
      started: true,
    ),
  );

  int _taskCount = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: () {
            _taskCount++;
            final added = _queuer.addItem(_taskCount);
            if (!added) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Queue is full')),
              );
            }
          },
          child: const Text('Add Task'),
        ),
        Text('Queue size: ${_queuer.state.size}'),
        Text('Processed: ${_queuer.state.executionCount}'),
      ],
    );
  }

  @override
  void dispose() {
    _queuer.dispose();
    super.dispose();
  }
}
```

### Batching Operations

```dart
class BatchProcessor extends StatefulWidget {
  @override
  _BatchProcessorState createState() => _BatchProcessorState();
}

class _BatchProcessorState extends State<BatchProcessor> {
  final Batcher<String> _batcher = Batcher<String>(
    (items) async {
      await processBatch(items);
      debugPrint('Processed batch of ${items.length} items');
    },
    BatcherOptions<String>(
      maxSize: 5,
      wait: const Duration(seconds: 2),
    ),
  );

  int _itemCount = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: () {
            _itemCount++;
            _batcher.addItem('Item $_itemCount');
          },
          child: const Text('Add Item to Batch'),
        ),
        ElevatedButton(
          onPressed: () => _batcher.execute(),
          child: const Text('Process Batch'),
        ),
        Text('Current batch size: ${_batcher.state.size}'),
        Text('Total processed: ${_batcher.state.totalItemsProcessed}'),
      ],
    );
  }

  @override
  void dispose() {
    _batcher.dispose();
    super.dispose();
  }
}
```

### Retrying Failed Requests

```dart
class RetryService {
  final AsyncRetryer<String> _retryer = AsyncRetryer<String>(
    (url) async {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        throw Exception('Request failed: ${response.statusCode}');
      }

      return response.body;
    },
    AsyncRetryerOptions<String>(
      maxAttempts: 3,
      backoff: BackoffType.exponential,
      baseWait: const Duration(milliseconds: 500),
      onRetry: (attempt, error) {
        debugPrint('Retry attempt $attempt: $error');
      },
    ),
  );

  Future<String> fetchWithRetry(String url) async {
    return await _retryer.execute(url);
  }
}
```

---

## 🏁 Getting Started

To get started with `GnrllyBttrPacer`, follow these steps:

1. **Add the Package**: Install the package via `pubspec.yaml`.
2. **Import the Package**: Add `import 'package:gnrllybttr_pacer/gnrllybttr_pacer.dart';` to your Dart files.
3. **Choose Your Utility**: Select the appropriate utility for your use case (debounce, throttle, rate limit, queue, batch, or retry).
4. **Create an Instance**: Instantiate the utility class with your function and configuration options.
5. **Use the Utility**: Call the appropriate method (`maybeExecute`, `addItem`, etc.) to control function execution.
6. **Monitor State**: Use the built-in state management to track execution statistics and status.

---

## 📖 Usage

### Debouncing

Debouncing delays function execution until after a period of inactivity. Perfect for search inputs and API calls.

```dart
// Class-based approach
final debouncer = Debouncer<String>(
  (query) => performSearch(query),
  DebouncerOptions<String>(wait: const Duration(milliseconds: 300)),
);

// Function-based approach
final debouncedFn = debounce<String>(
  (query) => performSearch(query),
  DebouncerOptions<String>(wait: const Duration(milliseconds: 300)),
);

// Usage
debouncer.maybeExecute('search query');
```

### Throttling

Throttling ensures a function executes at most once within a time window. Great for button clicks and scroll handlers.

```dart
final throttler = Throttler<int>(
  (count) => debugPrint('Throttled: $count'),
  ThrottlerOptions<int>(
    wait: const Duration(milliseconds: 100),
    leading: true,
    trailing: true,
  ),
);

// Usage
throttler.maybeExecute(42);
```

### Rate Limiting

Rate limiting allows a function to execute up to a limit within a time window. Ideal for API rate limiting.

```dart
final rateLimiter = RateLimiter<String>(
  (endpoint) => makeAPICall(endpoint),
  RateLimiterOptions<String>(
    limit: 5,
    window: const Duration(minutes: 1),
    windowType: WindowType.sliding,
  ),
);

// Usage
if (rateLimiter.maybeExecute('api/endpoint')) {
  // Request allowed
} else {
  // Rate limit exceeded
}
```

### Queuing

Queuing processes items sequentially with configurable concurrency. Perfect for background task processing.

```dart
final queuer = Queuer<String>(
  (taskData) => processItem(taskData),
  QueuerOptions<String>(
    wait: const Duration(milliseconds: 500),
    maxSize: 10,
    started: true,
  ),
);

// Usage
queuer.addItem('task data');
queuer.start(); // If not auto-started
```

### Batching

Batching groups multiple operations together for efficient processing. Great for bulk operations.

```dart
final batcher = Batcher<String>(
  (items) => processBatch(items),
  BatcherOptions<String>(maxSize: 10, wait: const Duration(seconds: 1)),
);

// Usage
batcher.addItem('item 1');
batcher.addItem('item 2');
// Automatically processes when batch size reached or timeout
```

### Retrying

Retrying automatically retries failed operations with configurable backoff strategies.

```dart
final retryer = AsyncRetryer<String>(
  (params) => unreliableAPICall(params),
  AsyncRetryerOptions<String>(
    maxAttempts: 3,
    backoff: BackoffType.exponential,
    baseWait: const Duration(milliseconds: 100),
  ),
);

// Usage
try {
  final result = await retryer.execute('api params');
} catch (e) {
  // All retries failed
}
```

### State Management

All utilities provide reactive state management through ChangeNotifier:

```dart
final debouncer = Debouncer<String>((query) => search(query), DebouncerOptions<String>());

// Listen to state changes
debouncer.addListener(() {
  final state = debouncer.state;
  debugPrint('Execution count: ${state.executionCount}');
  debugPrint('Status: ${state.status}');
  debugPrint('Is pending: ${state.isPending}');
});

// Access current state
final currentState = debouncer.state;
```

---

## 🤝 Contributing

We welcome contributions! Please see our [contributing guidelines](https://github.com/GnrllyBttr/GnrllyBttrPacer/raw/main/CONTRIBUTING.md) for more details.

---

## 🆘 Support

If you encounter any issues or have questions, please [open an issue](https://github.com/GnrllyBttr/GnrllyBttrPacer/issues) on GitHub.

---

## 📝 Changelog

See the [changelog](https://github.com/GnrllyBttr/GnrllyBttrPacer/raw/main/CHANGELOG.md) for updates and changes.

---

## 📄 License

This project is licensed under the MIT License. See the [LICENSE](https://github.com/GnrllyBttr/GnrllyBttrPacer/raw/main/LICENSE) file for details.

---

Let me know if you'd like further refinements! 🎉</content>
<parameter name="filePath">README.md