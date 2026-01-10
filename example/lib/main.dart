import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:gnrllybttr_pacer/gnrllybttr_pacer.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const GnrllyBttrPacerDemo());
}

class GnrllyBttrPacerDemo extends StatelessWidget {
  const GnrllyBttrPacerDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GnrllyBttrPacer Demo',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 10, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GnrllyBttrPacer Demo'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Debouncer'),
            Tab(text: 'Throttler'),
            Tab(text: 'RateLimiter'),
            Tab(text: 'Queuer'),
            Tab(text: 'Batcher'),
            Tab(text: 'AsyncDebouncer'),
            Tab(text: 'AsyncThrottler'),
            Tab(text: 'AsyncRateLimiter'),
            Tab(text: 'AsyncQueuer'),
            Tab(text: 'AsyncBatcher'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          DebouncerDemo(),
          ThrottlerDemo(),
          RateLimiterDemo(),
          QueuerDemo(),
          BatcherDemo(),
          AsyncDebouncerDemo(),
          AsyncThrottlerDemo(),
          AsyncRateLimiterDemo(),
          AsyncQueuerDemo(),
          AsyncBatcherDemo(),
        ],
      ),
    );
  }
}

// Pokemon data class
class Pokemon {
  const Pokemon({
    required this.id,
    required this.name,
    required this.height,
    required this.weight,
  });

  final int id;
  final String name;
  final int height;
  final int weight;

  factory Pokemon.fromJson(Map<String, dynamic> json) {
    return Pokemon(
      id: json['id'] as int,
      name: json['name'] as String,
      height: json['height'] as int,
      weight: json['weight'] as int,
    );
  }

  @override
  String toString() =>
      'Pokemon(id: $id, name: $name, height: $height, weight: $weight)';
}

// Pokemon API helper
class PokemonApi {
  static Future<Pokemon> fetchPokemon(int id) async {
    final response = await http.get(
      Uri.parse('https://pokeapi.co/api/v2/pokemon/$id'),
    );
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return Pokemon.fromJson(json);
    } else {
      throw Exception('Failed to load pokemon');
    }
  }

  static Future<List<Pokemon>> fetchMultiplePokemon(List<int> ids) async {
    final futures = ids.map((id) => fetchPokemon(id)).toList();
    return Future.wait(futures);
  }
}

// Base demo state
abstract class BaseDemoState<T extends StatefulWidget> extends State<T> {
  final List<String> logs = [];
  final ScrollController _scrollController = ScrollController();

  void addLog(String message) {
    setState(() {
      logs.add(
        '${DateTime.now().toIso8601String().split('T')[1].split('.')[0]}: $message',
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Widget buildLogArea() {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        color: Colors.grey[100],
        child: ListView.builder(
          controller: _scrollController,
          itemCount: logs.length,
          itemBuilder: (context, index) {
            return Text(logs[index], style: const TextStyle(fontSize: 12));
          },
        ),
      ),
    );
  }

  Widget buildStateDisplay(Object state) {
    final children = <Widget>[];

    if (state is PacerState) {
      children.addAll([
        Text(
          'Status: ${state.status}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        Text('Execution Count: ${state.executionCount}'),
      ]);
    }

    if (state is AsyncBatcherState ||
        state is AsyncQueuerState ||
        state is AsyncDebouncerState ||
        state is AsyncThrottlerState ||
        state is AsyncRateLimiterState) {
      children.addAll([
        Text('Error Count: ${(state as dynamic).errorCount}'),
        Text('Success Count: ${(state as dynamic).successCount}'),
      ]);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}

// Debouncer Demo
class DebouncerDemo extends StatefulWidget {
  const DebouncerDemo({super.key});

  @override
  State<DebouncerDemo> createState() => _DebouncerDemoState();
}

class _DebouncerDemoState extends BaseDemoState<DebouncerDemo> {
  late Debouncer<String> _debouncer;
  final TextEditingController _controller = TextEditingController();
  double _waitMs = 500;

  @override
  void initState() {
    super.initState();
    _createDebouncer();
  }

  void _createDebouncer() {
    _debouncer.dispose();
    _debouncer = Debouncer<String>((dynamic args) {
      final query = args as String;
      addLog('Searching for: $query');
      PokemonApi.fetchPokemon(int.tryParse(query) ?? 1)
          .then((pokemon) {
            addLog('Found: ${pokemon.name}');
          })
          .catchError((e) {
            addLog('Error: $e');
          });
    }, DebouncerOptions<String>(wait: Duration(milliseconds: _waitMs.toInt())));
  }

  @override
  void dispose() {
    _debouncer.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Configuration',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    const Text('Wait (ms):'),
                    Expanded(
                      child: Slider(
                        value: _waitMs,
                        min: 100,
                        max: 2000,
                        divisions: 19,
                        label: '${_waitMs.toInt()}ms',
                        onChanged: (value) {
                          setState(() => _waitMs = value);
                          _createDebouncer();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'Pokemon ID (debounced search)',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              if (value.isNotEmpty) {
                _debouncer.maybeExecute(value);
              }
            },
          ),
        ),
        buildStateDisplay(_debouncer.state),
        buildLogArea(),
      ],
    );
  }
}

// Throttler Demo
class ThrottlerDemo extends StatefulWidget {
  const ThrottlerDemo({super.key});

  @override
  State<ThrottlerDemo> createState() => _ThrottlerDemoState();
}

class _ThrottlerDemoState extends BaseDemoState<ThrottlerDemo> {
  late Throttler<int> _throttler;
  int _clickCount = 0;
  double _waitMs = 1000;

  @override
  void initState() {
    super.initState();
    _createThrottler();
  }

  void _createThrottler() {
    _throttler.dispose();
    _throttler = Throttler<int>((dynamic args) {
      final count = args as int;
      addLog('Throttled click #$count');
      PokemonApi.fetchPokemon(count % 151 + 1)
          .then((pokemon) {
            addLog('Fetched: ${pokemon.name}');
          })
          .catchError((e) {
            addLog('Error: $e');
          });
    }, ThrottlerOptions<int>(wait: Duration(milliseconds: _waitMs.toInt())));
  }

  @override
  void dispose() {
    _throttler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Configuration',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    const Text('Wait (ms):'),
                    Expanded(
                      child: Slider(
                        value: _waitMs,
                        min: 200,
                        max: 5000,
                        divisions: 24,
                        label: '${_waitMs.toInt()}ms',
                        onChanged: (value) {
                          setState(() => _waitMs = value);
                          _createThrottler();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: () {
              _clickCount++;
              _throttler.maybeExecute(_clickCount);
            },
            child: Text('Click me (throttled) - Count: $_clickCount'),
          ),
        ),
        buildStateDisplay(_throttler.state),
        buildLogArea(),
      ],
    );
  }
}

// RateLimiter Demo
class RateLimiterDemo extends StatefulWidget {
  const RateLimiterDemo({super.key});

  @override
  State<RateLimiterDemo> createState() => _RateLimiterDemoState();
}

class _RateLimiterDemoState extends BaseDemoState<RateLimiterDemo> {
  late RateLimiter<int> _rateLimiter;
  int _requestCount = 0;
  double _limit = 3;
  double _windowSeconds = 10;

  @override
  void initState() {
    super.initState();
    _createRateLimiter();
  }

  void _createRateLimiter() {
    _rateLimiter.dispose();
    _rateLimiter = RateLimiter<int>(
      (dynamic args) {
        final count = args as int;
        addLog('Rate limited request #$count');
        PokemonApi.fetchPokemon(count % 151 + 1)
            .then((pokemon) {
              addLog('Fetched: ${pokemon.name}');
            })
            .catchError((e) {
              addLog('Error: $e');
            });
      },
      RateLimiterOptions<int>(
        limit: _limit.toInt(),
        window: Duration(seconds: _windowSeconds.toInt()),
      ),
    );
  }

  @override
  void dispose() {
    _rateLimiter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Configuration',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    const Text('Limit:'),
                    Expanded(
                      child: Slider(
                        value: _limit,
                        min: 1,
                        max: 10,
                        divisions: 9,
                        label: '${_limit.toInt()}',
                        onChanged: (value) {
                          setState(() => _limit = value);
                          _createRateLimiter();
                        },
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Text('Window (s):'),
                    Expanded(
                      child: Slider(
                        value: _windowSeconds,
                        min: 5,
                        max: 60,
                        divisions: 11,
                        label: '${_windowSeconds.toInt()}s',
                        onChanged: (value) {
                          setState(() => _windowSeconds = value);
                          _createRateLimiter();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: () {
              _requestCount++;
              final allowed = _rateLimiter.maybeExecute(_requestCount);
              addLog(
                'Request #$_requestCount ${allowed ? 'allowed' : 'rejected'}',
              );
            },
            child: Text('Make request (rate limited) - Total: $_requestCount'),
          ),
        ),
        Text(
          'Remaining: ${_rateLimiter.getRemainingInWindow()} / ${_limit.toInt()}',
        ),
        buildStateDisplay(_rateLimiter.state),
        buildLogArea(),
      ],
    );
  }
}

// Queuer Demo
class QueuerDemo extends StatefulWidget {
  const QueuerDemo({super.key});

  @override
  State<QueuerDemo> createState() => _QueuerDemoState();
}

class _QueuerDemoState extends BaseDemoState<QueuerDemo> {
  late Queuer<int> _queuer;
  int _taskCount = 0;
  double _waitMs = 500;

  @override
  void initState() {
    super.initState();
    _createQueuer();
  }

  void _createQueuer() {
    _queuer.dispose();
    _queuer = Queuer<int>((dynamic args) {
      final id = args as int;
      addLog('Processing queued task #$id');
      PokemonApi.fetchPokemon(id % 151 + 1)
          .then((pokemon) {
            addLog('Processed: ${pokemon.name}');
          })
          .catchError((e) {
            addLog('Error: $e');
          });
    }, QueuerOptions<int>(wait: Duration(milliseconds: _waitMs.toInt())));
  }

  @override
  void dispose() {
    _queuer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Configuration',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    const Text('Wait (ms):'),
                    Expanded(
                      child: Slider(
                        value: _waitMs,
                        min: 100,
                        max: 2000,
                        divisions: 19,
                        label: '${_waitMs.toInt()}ms',
                        onChanged: (value) {
                          setState(() => _waitMs = value);
                          _createQueuer();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: () {
              _taskCount++;
              _queuer.addItem(_taskCount);
              addLog('Added task #$_taskCount to queue');
            },
            child: Text('Add task to queue - Total: $_taskCount'),
          ),
        ),
        Text('Queue Size: ${_queuer.state.size}'),
        buildStateDisplay(_queuer.state),
        buildLogArea(),
      ],
    );
  }
}

// Batcher Demo
class BatcherDemo extends StatefulWidget {
  const BatcherDemo({super.key});

  @override
  State<BatcherDemo> createState() => _BatcherDemoState();
}

class _BatcherDemoState extends BaseDemoState<BatcherDemo> {
  late Batcher<int> _batcher;
  int _itemCount = 0;
  double _maxSize = 3;
  double _waitSeconds = 2;

  @override
  void initState() {
    super.initState();
    _createBatcher();
  }

  void _createBatcher() {
    _batcher.dispose();
    _batcher = Batcher<int>(
      (dynamic args) {
        final ids = args as List<int>;
        addLog('Batching ${ids.length} requests');
        PokemonApi.fetchMultiplePokemon(ids)
            .then((pokemonList) {
              for (final pokemon in pokemonList) {
                addLog('Fetched: ${pokemon.name}');
              }
            })
            .catchError((e) {
              addLog('Error: $e');
            });
      },
      BatcherOptions<int>(
        maxSize: _maxSize.toInt(),
        wait: Duration(seconds: _waitSeconds.toInt()),
      ),
    );
  }

  @override
  void dispose() {
    _batcher.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Configuration',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    const Text('Max Size:'),
                    Expanded(
                      child: Slider(
                        value: _maxSize,
                        min: 2,
                        max: 10,
                        divisions: 8,
                        label: '${_maxSize.toInt()}',
                        onChanged: (value) {
                          setState(() => _maxSize = value);
                          _createBatcher();
                        },
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Text('Wait (s):'),
                    Expanded(
                      child: Slider(
                        value: _waitSeconds,
                        min: 1,
                        max: 10,
                        divisions: 9,
                        label: '${_waitSeconds.toInt()}s',
                        onChanged: (value) {
                          setState(() => _waitSeconds = value);
                          _createBatcher();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: () {
              _itemCount++;
              _batcher.addItem(_itemCount % 151 + 1);
              addLog('Added item #$_itemCount to batch');
            },
            child: Text('Add item to batch - Total: $_itemCount'),
          ),
        ),
        Text('Batch Size: ${_batcher.state.size} / ${_maxSize.toInt()}'),
        buildStateDisplay(_batcher.state),
        buildLogArea(),
      ],
    );
  }
}

// AsyncDebouncer Demo
class AsyncDebouncerDemo extends StatefulWidget {
  const AsyncDebouncerDemo({super.key});

  @override
  State<AsyncDebouncerDemo> createState() => _AsyncDebouncerDemoState();
}

class _AsyncDebouncerDemoState extends BaseDemoState<AsyncDebouncerDemo> {
  late AsyncDebouncer<String> _asyncDebouncer;
  final TextEditingController _controller = TextEditingController();
  double _waitMs = 500;

  @override
  void initState() {
    super.initState();
    _createAsyncDebouncer();
  }

  void _createAsyncDebouncer() {
    _asyncDebouncer.dispose();
    _asyncDebouncer = AsyncDebouncer<String>(
      (dynamic args) async {
        final query = args as String;
        addLog('Async searching for: $query');
        try {
          final pokemon = await PokemonApi.fetchPokemon(
            int.tryParse(query) ?? 1,
          );
          addLog('Found: ${pokemon.name}');
        } catch (e) {
          addLog('Error: $e');
        }
      },
      AsyncDebouncerOptions<String>(
        wait: Duration(milliseconds: _waitMs.toInt()),
      ),
    );
  }

  @override
  void dispose() {
    _asyncDebouncer.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Configuration',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    const Text('Wait (ms):'),
                    Expanded(
                      child: Slider(
                        value: _waitMs,
                        min: 100,
                        max: 2000,
                        divisions: 19,
                        label: '${_waitMs.toInt()}ms',
                        onChanged: (value) {
                          setState(() => _waitMs = value);
                          _createAsyncDebouncer();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'Pokemon ID (async debounced search)',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              if (value.isNotEmpty) {
                _asyncDebouncer.maybeExecute(value);
              }
            },
          ),
        ),
        buildStateDisplay(_asyncDebouncer.state),
        buildLogArea(),
      ],
    );
  }
}

// AsyncThrottler Demo
class AsyncThrottlerDemo extends StatefulWidget {
  const AsyncThrottlerDemo({super.key});

  @override
  State<AsyncThrottlerDemo> createState() => _AsyncThrottlerDemoState();
}

class _AsyncThrottlerDemoState extends BaseDemoState<AsyncThrottlerDemo> {
  late AsyncThrottler<int> _asyncThrottler;
  int _clickCount = 0;
  double _waitMs = 1000;

  @override
  void initState() {
    super.initState();
    _createAsyncThrottler();
  }

  void _createAsyncThrottler() {
    _asyncThrottler.dispose();
    _asyncThrottler = AsyncThrottler<int>(
      (dynamic args) async {
        final count = args as int;
        addLog('Async throttled click #$count');
        try {
          final pokemon = await PokemonApi.fetchPokemon(count % 151 + 1);
          addLog('Fetched: ${pokemon.name}');
        } catch (e) {
          addLog('Error: $e');
        }
      },
      AsyncThrottlerOptions<int>(wait: Duration(milliseconds: _waitMs.toInt())),
    );
  }

  @override
  void dispose() {
    _asyncThrottler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Configuration',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    const Text('Wait (ms):'),
                    Expanded(
                      child: Slider(
                        value: _waitMs,
                        min: 200,
                        max: 5000,
                        divisions: 24,
                        label: '${_waitMs.toInt()}ms',
                        onChanged: (value) {
                          setState(() => _waitMs = value);
                          _createAsyncThrottler();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: () {
              _clickCount++;
              _asyncThrottler.maybeExecute(_clickCount);
            },
            child: Text('Click me (async throttled) - Count: $_clickCount'),
          ),
        ),
        buildStateDisplay(_asyncThrottler.state),
        buildLogArea(),
      ],
    );
  }
}

// AsyncRateLimiter Demo
class AsyncRateLimiterDemo extends StatefulWidget {
  const AsyncRateLimiterDemo({super.key});

  @override
  State<AsyncRateLimiterDemo> createState() => _AsyncRateLimiterDemoState();
}

class _AsyncRateLimiterDemoState extends BaseDemoState<AsyncRateLimiterDemo> {
  late AsyncRateLimiter<int> _asyncRateLimiter;
  int _requestCount = 0;
  double _limit = 3;
  double _windowSeconds = 10;

  @override
  void initState() {
    super.initState();
    _createAsyncRateLimiter();
  }

  void _createAsyncRateLimiter() {
    _asyncRateLimiter.dispose();
    _asyncRateLimiter = AsyncRateLimiter<int>(
      (dynamic args) async {
        final count = args as int;
        addLog('Async rate limited request #$count');
        try {
          final pokemon = await PokemonApi.fetchPokemon(count % 151 + 1);
          addLog('Fetched: ${pokemon.name}');
        } catch (e) {
          addLog('Error: $e');
        }
      },
      AsyncRateLimiterOptions<int>(
        limit: _limit.toInt(),
        window: Duration(seconds: _windowSeconds.toInt()),
      ),
    );
  }

  @override
  void dispose() {
    _asyncRateLimiter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Configuration',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    const Text('Limit:'),
                    Expanded(
                      child: Slider(
                        value: _limit,
                        min: 1,
                        max: 10,
                        divisions: 9,
                        label: '${_limit.toInt()}',
                        onChanged: (value) {
                          setState(() => _limit = value);
                          _createAsyncRateLimiter();
                        },
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Text('Window (s):'),
                    Expanded(
                      child: Slider(
                        value: _windowSeconds,
                        min: 5,
                        max: 60,
                        divisions: 11,
                        label: '${_windowSeconds.toInt()}s',
                        onChanged: (value) {
                          setState(() => _windowSeconds = value);
                          _createAsyncRateLimiter();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: () async {
              _requestCount++;
              final result = await _asyncRateLimiter.maybeExecute(
                _requestCount,
              );
              addLog('Request #$_requestCount result: $result');
            },
            child: Text(
              'Make async request (rate limited) - Total: $_requestCount',
            ),
          ),
        ),
        Text(
          'Remaining: ${_asyncRateLimiter.getRemainingInWindow()} / ${_limit.toInt()}',
        ),
        buildStateDisplay(_asyncRateLimiter.state),
        buildLogArea(),
      ],
    );
  }
}

// AsyncQueuer Demo
class AsyncQueuerDemo extends StatefulWidget {
  const AsyncQueuerDemo({super.key});

  @override
  State<AsyncQueuerDemo> createState() => _AsyncQueuerDemoState();
}

class _AsyncQueuerDemoState extends BaseDemoState<AsyncQueuerDemo> {
  late AsyncQueuer<int> _asyncQueuer;
  int _taskCount = 0;
  double _concurrency = 2;
  double _waitMs = 500;

  @override
  void initState() {
    super.initState();
    _createAsyncQueuer();
  }

  void _createAsyncQueuer() {
    _asyncQueuer.dispose();
    _asyncQueuer = AsyncQueuer<int>(
      (dynamic args) async {
        final id = args as int;
        addLog('Processing async queued task #$id');
        try {
          final pokemon = await PokemonApi.fetchPokemon(id % 151 + 1);
          addLog('Processed: ${pokemon.name}');
        } catch (e) {
          addLog('Error: $e');
        }
      },
      AsyncQueuerOptions<int>(
        concurrency: _concurrency.toInt(),
        wait: Duration(milliseconds: _waitMs.toInt()),
      ),
    );
  }

  @override
  void dispose() {
    _asyncQueuer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Configuration',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    const Text('Concurrency:'),
                    Expanded(
                      child: Slider(
                        value: _concurrency,
                        min: 1,
                        max: 5,
                        divisions: 4,
                        label: '${_concurrency.toInt()}',
                        onChanged: (value) {
                          setState(() => _concurrency = value);
                          _createAsyncQueuer();
                        },
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Text('Wait (ms):'),
                    Expanded(
                      child: Slider(
                        value: _waitMs,
                        min: 100,
                        max: 2000,
                        divisions: 19,
                        label: '${_waitMs.toInt()}ms',
                        onChanged: (value) {
                          setState(() => _waitMs = value);
                          _createAsyncQueuer();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: () async {
              _taskCount++;
              await _asyncQueuer.addItem(_taskCount);
              addLog('Added async task #$_taskCount to queue');
            },
            child: Text('Add async task to queue - Total: $_taskCount'),
          ),
        ),
        Text(
          'Queue Size: ${_asyncQueuer.state.size}, Active: ${_asyncQueuer.state.activeItems.length}, Pending: ${_asyncQueuer.state.pendingItems.length}',
        ),
        buildStateDisplay(_asyncQueuer.state),
        buildLogArea(),
      ],
    );
  }
}

// AsyncBatcher Demo
class AsyncBatcherDemo extends StatefulWidget {
  const AsyncBatcherDemo({super.key});

  @override
  State<AsyncBatcherDemo> createState() => _AsyncBatcherDemoState();
}

class _AsyncBatcherDemoState extends BaseDemoState<AsyncBatcherDemo> {
  late AsyncBatcher<int> _asyncBatcher;
  int _itemCount = 0;
  double _maxSize = 3;
  double _waitSeconds = 2;

  @override
  void initState() {
    super.initState();
    _createAsyncBatcher();
  }

  void _createAsyncBatcher() {
    _asyncBatcher.dispose();
    _asyncBatcher = AsyncBatcher<int>(
      (dynamic args) async {
        final ids = args as List<int>;
        addLog('Async batching ${ids.length} requests');
        try {
          final pokemonList = await PokemonApi.fetchMultiplePokemon(ids);
          for (final pokemon in pokemonList) {
            addLog('Fetched: ${pokemon.name}');
          }
        } catch (e) {
          addLog('Error: $e');
        }
      },
      AsyncBatcherOptions<int>(
        maxSize: _maxSize.toInt(),
        wait: Duration(seconds: _waitSeconds.toInt()),
      ),
    );
  }

  @override
  void dispose() {
    _asyncBatcher.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Configuration',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    const Text('Max Size:'),
                    Expanded(
                      child: Slider(
                        value: _maxSize,
                        min: 2,
                        max: 10,
                        divisions: 8,
                        label: '${_maxSize.toInt()}',
                        onChanged: (value) {
                          setState(() => _maxSize = value);
                          _createAsyncBatcher();
                        },
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Text('Wait (s):'),
                    Expanded(
                      child: Slider(
                        value: _waitSeconds,
                        min: 1,
                        max: 10,
                        divisions: 9,
                        label: '${_waitSeconds.toInt()}s',
                        onChanged: (value) {
                          setState(() => _waitSeconds = value);
                          _createAsyncBatcher();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: () async {
              _itemCount++;
              await _asyncBatcher.addItem(_itemCount % 151 + 1);
              addLog('Added async item #$_itemCount to batch');
            },
            child: Text('Add async item to batch - Total: $_itemCount'),
          ),
        ),
        Text('Batch Size: ${_asyncBatcher.state.size} / ${_maxSize.toInt()}'),
        buildStateDisplay(_asyncBatcher.state),
        buildLogArea(),
      ],
    );
  }
}
