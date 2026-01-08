import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:gnrllybttr_pacer/gnrllybttr_pacer.dart';

void main() {
  runApp(const GnrllyBttrPacerDemo());
}

class GnrllyBttrPacerDemo extends StatelessWidget {
  const GnrllyBttrPacerDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GnrllyBttrPacer Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
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
    _tabController = TabController(length: 6, vsync: this);
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
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.black,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey.shade600,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [
            Tab(text: 'Debouncing'),
            Tab(text: 'Throttling'),
            Tab(text: 'Rate Limiting'),
            Tab(text: 'Queuing'),
            Tab(text: 'Batching'),
            Tab(text: 'Retrying'),
          ],
        ),
      ),
      body: Container(
        color: Colors.grey.shade50,
        child: TabBarView(
          controller: _tabController,
          children: const [
            DebouncingDemo(),
            ThrottlingDemo(),
            RateLimitingDemo(),
            QueuingDemo(),
            BatchingDemo(),
            RetryingDemo(),
          ],
        ),
      ),
    );
  }
}

// Pokemon API service with search functionality
class PokemonService {
  static const String baseUrl = 'https://pokeapi.co/api/v2';

  static Future<Map<String, dynamic>> fetchPokemon(String name) async {
    final response = await http.get(Uri.parse('$baseUrl/pokemon/$name'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load pokemon: ${response.statusCode}');
    }
  }

  static Future<List<dynamic>> fetchPokemonList({int limit = 20, int offset = 0}) async {
    final response = await http.get(Uri.parse('$baseUrl/pokemon?limit=$limit&offset=$offset'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['results'];
    } else {
      throw Exception('Failed to load pokemon list: ${response.statusCode}');
    }
  }

  static Future<List<String>> searchPokemon(String query) async {
    if (query.isEmpty) return [];

    try {
      final allPokemon = await fetchPokemonList(limit: 100);
      final names = allPokemon.map((p) => p['name'] as String).toList();

      // Filter names that contain the query (case insensitive)
      return names
          .where((name) => name.toLowerCase().contains(query.toLowerCase()))
          .take(5) // Limit to 5 suggestions
          .toList();
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> fetchPokemonSpecies(String name) async {
    final response = await http.get(Uri.parse('$baseUrl/pokemon-species/$name'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load pokemon species: ${response.statusCode}');
    }
  }
}

// Debouncing Demo with search suggestions
class DebouncingDemo extends StatefulWidget {
  const DebouncingDemo({super.key});

  @override
  State<DebouncingDemo> createState() => _DebouncingDemoState();
}

class _DebouncingDemoState extends State<DebouncingDemo> {
  final TextEditingController _searchController = TextEditingController();
  late Debouncer _debouncer;
  late AsyncDebouncer _asyncDebouncer;
  late AnyFunction _debouncedSearch;

  List<String> _suggestions = [];
  bool _isSearching = false;
  Duration _debounceWait = const Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    _createDebouncers();
  }

  void _createDebouncers() {
    _debouncer = Debouncer(
      (args) async {
        final query = args[0] as String;
        if (query.isNotEmpty) {
          setState(() => _isSearching = true);
          try {
            final suggestions = await PokemonService.searchPokemon(query);
            if (mounted) {
              setState(() {
                _suggestions = suggestions;
                _isSearching = false;
              });
            }
          } catch (e) {
            if (mounted) {
              setState(() {
                _suggestions = [];
                _isSearching = false;
              });
            }
          }
        } else {
          setState(() {
            _suggestions = [];
            _isSearching = false;
          });
        }
      },
      DebouncerOptions(wait: _debounceWait),
    );

    _asyncDebouncer = AsyncDebouncer(
      (args) async {
        final query = args[0] as String;
        if (query.isNotEmpty) {
          return await PokemonService.searchPokemon(query);
        }
        return [];
      },
      AsyncDebouncerOptions(
        wait: _debounceWait,
        onSuccess: (result) {
          if (mounted && result is List) {
            setState(() => _suggestions = List<String>.from(result));
          }
        },
        onError: (error) {
          debugPrint('Async debounced error: $error');
          if (mounted) {
            setState(() => _suggestions = []);
          }
        },
      ),
    );

    _debouncedSearch = debounce(
      (args) async {
        final query = args[0] as String;
        if (query.isNotEmpty) {
          final suggestions = await PokemonService.searchPokemon(query);
          if (mounted) {
            setState(() => _suggestions = suggestions);
          }
        } else {
          setState(() => _suggestions = []);
        }
      },
      DebouncerOptions(wait: _debounceWait),
    );
  }

  void _updateDebounceWait(double value) {
    setState(() {
      _debounceWait = Duration(milliseconds: value.toInt());
    });
    _debouncer.dispose();
    _asyncDebouncer.dispose();
    _createDebouncers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debouncer.dispose();
    _asyncDebouncer.dispose();
    super.dispose();
  }

  Widget _buildStateCard(String title, List<String> items) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade800,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              item,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.search, color: Colors.grey.shade700, size: 24),
                SizedBox(width: 12),
                Text(
                  'Debouncing Demo - Pokemon Search',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Configuration
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Configuration', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Debounce Wait: ${_debounceWait.inMilliseconds}ms'),
                  Slider(
                    value: _debounceWait.inMilliseconds.toDouble(),
                    min: 100,
                    max: 1000,
                    divisions: 9,
                    label: '${_debounceWait.inMilliseconds}ms',
                    onChanged: _updateDebounceWait,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Search Input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Search for Pokemon (with suggestions):',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Type pokemon name...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: Colors.grey.shade500, width: 1),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    suffixIcon: _isSearching
                        ? Container(
                            width: 16,
                            height: 16,
                            padding: const EdgeInsets.all(8),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade600),
                            ),
                          )
                        : Icon(Icons.search, color: Colors.grey.shade500, size: 20),
                  ),
                  onChanged: (value) {
                    _debouncer.maybeExecute([value]);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Suggestions
          if (_suggestions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Suggestions (${_suggestions.length}):',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _suggestions.map((suggestion) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              suggestion,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _searchController.text = suggestion;
                                  _suggestions = [];
                                });
                              },
                              child: Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Action Buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Actions',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          try {
                            final result = await _asyncDebouncer.maybeExecute([_searchController.text]);
                            if (!mounted || result == null) return;
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Async search completed: ${result.length} results'),
                                    backgroundColor: Colors.grey.shade800,
                                  ),
                                );
                              }
                            });
                          } catch (e) {
                            // Handle error
                          }
                        },
                        icon: Icon(Icons.search, size: 16),
                        label: const Text('Async Search'),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey.shade300),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _debouncedSearch([_searchController.text]);
                        },
                        icon: Icon(Icons.functions, size: 16),
                        label: const Text('Function Search'),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey.shade300),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _suggestions = [];
                        });
                      },
                      icon: Icon(Icons.clear, size: 16),
                      label: const Text('Clear'),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // State Information
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'State Information',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildStateCard(
                        'Debouncer',
                        [
                          'Status: ${_debouncer.state.status}',
                          'Executions: ${_debouncer.state.executionCount}',
                          'Maybe Exec: ${_debouncer.state.maybeExecuteCount}',
                          'Pending: ${_debouncer.state.isPending ? 'Yes' : 'No'}',
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStateCard(
                        'Async Debouncer',
                        [
                          'Status: ${_asyncDebouncer.state.status}',
                          'Success: ${_asyncDebouncer.state.successCount}',
                          'Errors: ${_asyncDebouncer.state.errorCount}',
                          'Suggestions: ${_suggestions.length}',
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Throttling Demo with interactive scroll tracking
class ThrottlingDemo extends StatefulWidget {
  const ThrottlingDemo({super.key});

  @override
  State<ThrottlingDemo> createState() => _ThrottlingDemoState();
}

class _ThrottlingDemoState extends State<ThrottlingDemo> {
  late Throttler _throttler;
  late AsyncThrottler _asyncThrottler;
  late AnyFunction _throttledFunction;

  final ScrollController _scrollController = ScrollController();
  Duration _throttleWait = const Duration(milliseconds: 100);
  int _scrollEvents = 0;
  int _throttledEvents = 0;
  double _scrollPosition = 0.0;
  bool _leading = true;
  bool _trailing = true;

  @override
  void initState() {
    super.initState();
    _createThrottlers();
    _scrollController.addListener(_onScroll);
  }

  void _createThrottlers() {
    _throttler = Throttler(
      (args) {
        final position = args[0] as double;
        setState(() {
          _throttledEvents++;
          _scrollPosition = position;
        });
        debugPrint('Throttled scroll: ${position.toStringAsFixed(1)}');
      },
      ThrottlerOptions(
        wait: _throttleWait,
        leading: _leading,
        trailing: _trailing,
      ),
    );

    _asyncThrottler = AsyncThrottler(
      (args) async {
        final position = args[0] as double;
        await Future.delayed(const Duration(milliseconds: 10));
        return 'Scroll at ${position.toStringAsFixed(1)}';
      },
      AsyncThrottlerOptions(
        wait: _throttleWait,
        leading: _leading,
        trailing: _trailing,
        onSuccess: (result) {
          debugPrint('Async throttled: $result');
        },
      ),
    );

    _throttledFunction = throttle(
      (args) {
        final position = args[0] as double;
        setState(() => _throttledEvents++);
        debugPrint('Function throttled: ${position.toStringAsFixed(1)}');
      },
      ThrottlerOptions(
        wait: _throttleWait,
        leading: _leading,
        trailing: _trailing,
      ),
    );
  }

  void _onScroll() {
    _scrollEvents++;
    final position = _scrollController.position.pixels;
    _throttler.maybeExecute([position]);
  }

  void _updateThrottleWait(double value) {
    setState(() {
      _throttleWait = Duration(milliseconds: value.toInt());
    });
    _throttler.dispose();
    _asyncThrottler.dispose();
    _createThrottlers();
  }

  void _updateLeading(bool value) {
    setState(() => _leading = value);
    _throttler.dispose();
    _asyncThrottler.dispose();
    _createThrottlers();
  }

  void _updateTrailing(bool value) {
    setState(() => _trailing = value);
    _throttler.dispose();
    _asyncThrottler.dispose();
    _createThrottlers();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _throttler.dispose();
    _asyncThrottler.dispose();
    super.dispose();
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.grey.shade600, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.touch_app, color: Colors.grey.shade700, size: 24),
                SizedBox(width: 12),
                Text(
                  'Throttling Demo - Scroll Tracking',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Configuration
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Configuration', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Throttle Wait: ${_throttleWait.inMilliseconds}ms'),
                  Slider(
                    value: _throttleWait.inMilliseconds.toDouble(),
                    min: 50,
                    max: 500,
                    divisions: 9,
                    label: '${_throttleWait.inMilliseconds}ms',
                    onChanged: _updateThrottleWait,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Leading:'),
                      Switch(value: _leading, onChanged: _updateLeading),
                      const SizedBox(width: 16),
                      const Text('Trailing:'),
                      Switch(value: _trailing, onChanged: _updateTrailing),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Scroll Area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Scroll the area below to see throttling in action:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(6),
                    color: Colors.grey.shade50,
                  ),
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: 50,
                    itemBuilder: (context, index) {
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.grey.shade200),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.list,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Item $index',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    'Scroll to see throttling effects',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Stats
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Live Statistics',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Scroll Events',
                        _scrollEvents.toString(),
                        Icons.touch_app,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard(
                        'Throttled',
                        _throttledEvents.toString(),
                        Icons.filter_list,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard(
                        'Ratio',
                        '${(_scrollEvents > 0) ? (_throttledEvents / _scrollEvents * 100).toStringAsFixed(1) : 0}%',
                        Icons.percent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.location_on, color: Colors.grey.shade600, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Current Position: ${_scrollPosition.toStringAsFixed(1)}px',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Action Buttons
          Row(
            children: [
              ElevatedButton(
                onPressed: () async {
                  try {
                    final result = await _asyncThrottler.maybeExecute([_scrollPosition]);
                    if (!mounted || result == null) return;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Async throttled: $result')),
                        );
                      }
                    });
                  } catch (e) {
                    // Handle error
                  }
                },
                child: const Text('Async Throttle'),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: () {
                  _throttledFunction([_scrollPosition]);
                },
                child: const Text('Function Throttle'),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _scrollEvents = 0;
                    _throttledEvents = 0;
                  });
                },
                child: const Text('Reset Stats'),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // State Information
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('State Information', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Throttler Status: ${_throttler.state.status}'),
                  Text('Execution Count: ${_throttler.state.executionCount}'),
                  Text('Last Execution: ${_throttler.state.lastExecutionTime}'),
                  Text('Next Execution: ${_throttler.state.nextExecutionTime}'),
                  const SizedBox(height: 8),
                  Text('Async Throttler Status: ${_asyncThrottler.state.status}'),
                  Text('Success Count: ${_asyncThrottler.state.successCount}'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Rate Limiting Demo with configurable limits
class RateLimitingDemo extends StatefulWidget {
  const RateLimitingDemo({super.key});

  @override
  State<RateLimitingDemo> createState() => _RateLimitingDemoState();
}

class _RateLimitingDemoState extends State<RateLimitingDemo> {
  late RateLimiter _rateLimiter;
  late AsyncRateLimiter _asyncRateLimiter;
  late bool Function(List<dynamic>) _rateLimitedFunction;

  int _requestCount = 0;
  int _limit = 3;
  Duration _window = const Duration(seconds: 5);
  WindowType _windowType = WindowType.sliding;

  @override
  void initState() {
    super.initState();
    _createRateLimiters();
  }

  void _createRateLimiters() {
    _rateLimiter = RateLimiter(
      (args) async {
        final id = args[0] as int;
        debugPrint('Rate limited request: $id');
        await Future.delayed(const Duration(milliseconds: 100));
      },
      RateLimiterOptions(
        limit: _limit,
        window: _window,
        windowType: _windowType,
        onReject: (limiter) {
          debugPrint('Request rejected - too many requests');
        },
      ),
    );

    _asyncRateLimiter = AsyncRateLimiter(
      (args) async {
        final id = args[0] as int;
        await Future.delayed(const Duration(milliseconds: 200));
        return 'Rate limited result #$id';
      },
      AsyncRateLimiterOptions(
        limit: _limit,
        window: _window,
        windowType: _windowType,
        onReject: (limiter) {
          debugPrint('Async request rejected');
        },
        onSuccess: (result) {
          debugPrint('Async rate limited success: $result');
        },
      ),
    );

    _rateLimitedFunction = rateLimit(
      (args) async {
        final id = args[0] as int;
        debugPrint('Function rate limited: $id');
      },
      RateLimiterOptions(
        limit: _limit,
        window: _window,
        windowType: _windowType,
      ),
    );
  }

  void _updateLimit(double value) {
    setState(() => _limit = value.toInt());
    _rateLimiter.dispose();
    _asyncRateLimiter.dispose();
    _createRateLimiters();
  }

  void _updateWindow(double value) {
    setState(() => _window = Duration(seconds: value.toInt()));
    _rateLimiter.dispose();
    _asyncRateLimiter.dispose();
    _createRateLimiters();
  }

  void _updateWindowType(WindowType? value) {
    if (value != null) {
      setState(() => _windowType = value);
      _rateLimiter.dispose();
      _asyncRateLimiter.dispose();
      _createRateLimiters();
    }
  }

  @override
  void dispose() {
    _rateLimiter.dispose();
    _asyncRateLimiter.dispose();
    super.dispose();
  }

  Widget _buildRateLimitStatusCard(String title, List<String> items, int? remaining) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                remaining != null && remaining > 0 ? Icons.check_circle : Icons.warning,
                color: remaining != null && remaining > 0 ? Colors.green.shade600 : Colors.orange.shade600,
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              item,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          )),
          if (remaining != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: remaining > 0 ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: remaining > 0 ? Colors.green.shade200 : Colors.red.shade200,
                ),
              ),
              child: Text(
                'Remaining: $remaining',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: remaining > 0 ? Colors.green.shade700 : Colors.red.shade700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.speed, color: Colors.grey.shade700, size: 24),
                SizedBox(width: 12),
                Text(
                  'Rate Limiting Demo',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Configuration
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Configuration', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Limit: $_limit requests'),
                  Slider(
                    value: _limit.toDouble(),
                    min: 1,
                    max: 10,
                    divisions: 9,
                    label: '$_limit',
                    onChanged: _updateLimit,
                  ),
                  const SizedBox(height: 8),
                  Text('Window: ${_window.inSeconds} seconds'),
                  Slider(
                    value: _window.inSeconds.toDouble(),
                    min: 1,
                    max: 30,
                    divisions: 29,
                    label: '${_window.inSeconds}s',
                    onChanged: _updateWindow,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Window Type:'),
                      const SizedBox(width: 16),
                      DropdownButton<WindowType>(
                        value: _windowType,
                        items: WindowType.values.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type.name.toUpperCase()),
                          );
                        }).toList(),
                        onChanged: _updateWindowType,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Click buttons to make rate-limited requests:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _requestCount++;
                          final allowed = _rateLimiter.maybeExecute([_requestCount]);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    Icon(
                                      allowed ? Icons.check_circle : Icons.cancel,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(allowed ? 'Request allowed #$_requestCount' : 'Request rejected #$_requestCount'),
                                  ],
                                ),
                                backgroundColor: allowed ? Colors.green.shade700 : Colors.red.shade700,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        icon: Icon(Icons.sync, size: 16),
                        label: const Text('Rate Limit Sync'),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey.shade300),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          _requestCount++;
                          try {
                            final result = await _asyncRateLimiter.maybeExecute([_requestCount]);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      Icon(
                                        result != null ? Icons.check_circle : Icons.cancel,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(result != null ? 'Async allowed: $result' : 'Async rejected #$_requestCount'),
                                    ],
                                  ),
                                  backgroundColor: result != null ? Colors.green.shade700 : Colors.red.shade700,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          } catch (e) {
                            // Handle error
                          }
                        },
                        icon: Icon(Icons.sync_alt, size: 16),
                        label: const Text('Rate Limit Async'),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey.shade300),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _requestCount++;
                          final allowed = _rateLimitedFunction([_requestCount]);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    Icon(
                                      allowed ? Icons.check_circle : Icons.cancel,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(allowed ? 'Function allowed #$_requestCount' : 'Function rejected #$_requestCount'),
                                  ],
                                ),
                                backgroundColor: allowed ? Colors.green.shade700 : Colors.red.shade700,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        icon: Icon(Icons.functions, size: 16),
                        label: const Text('Function Rate Limit'),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey.shade300),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // State Information
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rate Limiting Status',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildRateLimitStatusCard(
                        'Sync Rate Limiter',
                        [
                          'Status: ${_rateLimiter.state.status}',
                          'Executions: ${_rateLimiter.state.executionCount}',
                          'Rejections: ${_rateLimiter.state.rejectionCount}',
                          'Exceeded: ${_rateLimiter.state.isExceeded ? 'Yes' : 'No'}',
                        ],
                        _rateLimiter.getRemainingInWindow(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildRateLimitStatusCard(
                        'Async Rate Limiter',
                        [
                          'Status: ${_asyncRateLimiter.state.status}',
                          'Success: ${_asyncRateLimiter.state.successCount}',
                          'Errors: ${_asyncRateLimiter.state.errorCount}',
                        ],
                        null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Explanation
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('How Rate Limiting Works', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('• Fixed Window: Resets at fixed intervals (${_window.inSeconds}s)'),
                  Text('• Sliding Window: Allows requests as old ones expire'),
                  Text('• Current Limit: $_limit requests per window'),
                  Text('• Try making more than $_limit requests quickly to see rejection'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Queuing Demo with configurable parameters
class QueuingDemo extends StatefulWidget {
  const QueuingDemo({super.key});

  @override
  State<QueuingDemo> createState() => _QueuingDemoState();
}

class _QueuingDemoState extends State<QueuingDemo> {
  late Queuer _queuer;
  late AsyncQueuer _asyncQueuer;
  late bool Function(dynamic, [QueuePosition?, bool?]) _enqueueFunction;

  int _taskCount = 0;
  int _maxSize = 5;
  Duration _wait = const Duration(milliseconds: 200);
  bool _autoStart = true;

  @override
  void initState() {
    super.initState();
    _createQueuers();
  }

  void _createQueuers() {
    _queuer = Queuer(
      (args) async {
        final taskId = args[0] as int;
        debugPrint('Processing queued task: $taskId');
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Processed task #$taskId')),
          );
        }
      },
      QueuerOptions(
        wait: _wait,
        maxSize: _maxSize,
        started: _autoStart,
      ),
    );

    _asyncQueuer = AsyncQueuer(
      (args) async {
        final taskId = args[0] as int;
        await Future.delayed(const Duration(milliseconds: 300));
        return 'Async queued result #$taskId';
      },
      AsyncQueuerOptions(
        wait: _wait,
        maxSize: _maxSize,
        started: _autoStart,
        onSuccess: (result) {
          debugPrint('Async queued success: $result');
        },
      ),
    );

    _enqueueFunction = queue(
      (args) async {
        final taskId = args[0] as int;
        debugPrint('Function queued task: $taskId');
        await Future.delayed(const Duration(milliseconds: 400));
      },
      QueuerOptions(
        wait: _wait,
        maxSize: _maxSize,
        started: _autoStart,
      ),
    );
  }

  void _updateMaxSize(double value) {
    setState(() => _maxSize = value.toInt());
    _queuer.dispose();
    _asyncQueuer.dispose();
    _createQueuers();
  }

  void _updateWait(double value) {
    setState(() => _wait = Duration(milliseconds: value.toInt()));
    _queuer.dispose();
    _asyncQueuer.dispose();
    _createQueuers();
  }

  void _updateAutoStart(bool value) {
    setState(() => _autoStart = value);
    _queuer.dispose();
    _asyncQueuer.dispose();
    _createQueuers();
  }

  @override
  void dispose() {
    _queuer.dispose();
    _asyncQueuer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.queue, color: Colors.grey.shade700, size: 24),
                SizedBox(width: 12),
                Text(
                  'Queuing Demo',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Configuration
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Configuration', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Max Queue Size: $_maxSize'),
                  Slider(
                    value: _maxSize.toDouble(),
                    min: 1,
                    max: 20,
                    divisions: 19,
                    label: '$_maxSize',
                    onChanged: _updateMaxSize,
                  ),
                  const SizedBox(height: 8),
                  Text('Processing Wait: ${_wait.inMilliseconds}ms'),
                  Slider(
                    value: _wait.inMilliseconds.toDouble(),
                    min: 50,
                    max: 1000,
                    divisions: 19,
                    label: '${_wait.inMilliseconds}ms',
                    onChanged: _updateWait,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Auto Start:'),
                      Switch(value: _autoStart, onChanged: _updateAutoStart),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade200,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.add_task, color: Colors.orange.shade600),
                    const SizedBox(width: 8),
                    const Text(
                      'Add tasks to the queue:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _taskCount++;
                          final added = _queuer.addItem(_taskCount);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    Icon(
                                      added ? Icons.check_circle : Icons.cancel,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(added ? 'Added task #$_taskCount' : 'Queue full ($_maxSize max)'),
                                  ],
                                ),
                                backgroundColor: added ? Colors.green.shade600 : Colors.red.shade600,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        icon: Icon(Icons.add),
                        label: const Text('Add Sync Task'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          _taskCount++;
                          try {
                            await _asyncQueuer.addItem(_taskCount);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      Icon(Icons.check_circle, color: Colors.white),
                                      SizedBox(width: 8),
                                      Text('Added async task'),
                                    ],
                                  ),
                                  backgroundColor: Colors.blue,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          } catch (e) {
                            // Handle error
                          }
                        },
                        icon: Icon(Icons.add),
                        label: const Text('Add Async Task'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _taskCount++;
                          final added = _enqueueFunction(_taskCount);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    Icon(
                                      added ? Icons.check_circle : Icons.cancel,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(added ? 'Function added #$_taskCount' : 'Function queue full'),
                                  ],
                                ),
                                backgroundColor: added ? Colors.purple.shade600 : Colors.orange.shade600,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.functions),
                        label: const Text('Function Queue'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Queue Controls:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _queuer.start(),
                        icon: Icon(Icons.play_arrow),
                        label: const Text('Start Queue'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _queuer.stop(),
                        icon: Icon(Icons.stop),
                        label: const Text('Stop Queue'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _queuer.flush(),
                        icon: Icon(Icons.clear_all),
                        label: const Text('Flush Queue'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // State Information
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('State Information', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Queuer Status: ${_queuer.state.status}'),
                  Text('Size: ${_queuer.state.size}'),
                  Text('Add Count: ${_queuer.state.addItemCount}'),
                  Text('Execution Count: ${_queuer.state.executionCount}'),
                  Text('Is Running: ${_queuer.state.isRunning}'),
                  const SizedBox(height: 8),
                  Text('Async Queuer Status: ${_asyncQueuer.state.status}'),
                  Text('Active Items: ${_asyncQueuer.state.activeItems.length}'),
                  Text('Pending Items: ${_asyncQueuer.state.pendingItems.length}'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Batching Demo with configurable parameters
class BatchingDemo extends StatefulWidget {
  const BatchingDemo({super.key});

  @override
  State<BatchingDemo> createState() => _BatchingDemoState();
}

class _BatchingDemoState extends State<BatchingDemo> {
  late Batcher _batcher;
  late AsyncBatcher _asyncBatcher;
  late void Function(dynamic) _batchFunction;

  int _itemCount = 0;
  int _maxSize = 3;
  Duration _wait = const Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    _createBatchers();
  }

  void _createBatchers() {
    _batcher = Batcher(
      (args) async {
        final items = args[0] as List;
        debugPrint('Processing batch: ${items.length} items');
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Processed batch of ${items.length} items')),
          );
        }
      },
      BatcherOptions(
        maxSize: _maxSize,
        wait: _wait,
      ),
    );

    _asyncBatcher = AsyncBatcher(
      (args) async {
        final items = args[0] as List;
        await Future.delayed(const Duration(milliseconds: 400));
        return 'Batch processed ${items.length} items';
      },
      AsyncBatcherOptions(
        maxSize: _maxSize,
        wait: _wait,
        onSuccess: (result) {
          debugPrint('Async batch success: $result');
        },
      ),
    );

    _batchFunction = batch(
      (args) async {
        final items = args[0] as List;
        debugPrint('Function batch: ${items.length} items');
        await Future.delayed(const Duration(milliseconds: 200));
      },
      BatcherOptions(maxSize: _maxSize, wait: _wait),
    );
  }

  void _updateMaxSize(double value) {
    setState(() => _maxSize = value.toInt());
    _batcher.dispose();
    _asyncBatcher.dispose();
    _createBatchers();
  }

  void _updateWait(double value) {
    setState(() => _wait = Duration(seconds: value.toInt()));
    _batcher.dispose();
    _asyncBatcher.dispose();
    _createBatchers();
  }

  @override
  void dispose() {
    _batcher.dispose();
    _asyncBatcher.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.batch_prediction, color: Colors.grey.shade700, size: 24),
                SizedBox(width: 12),
                Text(
                  'Batching Demo',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Configuration
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Configuration', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Max Batch Size: $_maxSize'),
                  Slider(
                    value: _maxSize.toDouble(),
                    min: 1,
                    max: 10,
                    divisions: 9,
                    label: '$_maxSize',
                    onChanged: _updateMaxSize,
                  ),
                  const SizedBox(height: 8),
                  Text('Batch Wait: ${_wait.inSeconds} seconds'),
                  Slider(
                    value: _wait.inSeconds.toDouble(),
                    min: 1,
                    max: 10,
                    divisions: 9,
                    label: '${_wait.inSeconds}s',
                    onChanged: _updateWait,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade200,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.add_box, color: Colors.cyan.shade600),
                    const SizedBox(width: 8),
                    const Text(
                      'Add items to batches:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _itemCount++;
                          _batcher.addItem('Item $_itemCount');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Added item #$_itemCount to batch'),
                              backgroundColor: Colors.green.shade600,
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                        icon: Icon(Icons.add),
                        label: const Text('Add Sync Item'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          _itemCount++;
                          try {
                            await _asyncBatcher.addItem('Async Item $_itemCount');
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Added async item #$_itemCount to batch'),
                                  backgroundColor: Colors.blue.shade600,
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            }
                          } catch (e) {
                            // Handle error
                          }
                        },
                        icon: Icon(Icons.add),
                        label: const Text('Add Async Item'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _itemCount++;
                          _batchFunction('Function Item $_itemCount');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Added function item #$_itemCount to batch'),
                              backgroundColor: Colors.purple.shade600,
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                        icon: const Icon(Icons.functions),
                        label: const Text('Function Batch'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Batch Controls:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _batcher.execute(),
                        icon: Icon(Icons.play_arrow),
                        label: const Text('Execute Batch'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _batcher.flush(),
                        icon: Icon(Icons.clear_all),
                        label: const Text('Flush Batch'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // State Information
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('State Information', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Batcher Status: ${_batcher.state.status}'),
                  Text('Size: ${_batcher.state.size}'),
                  Text('Execution Count: ${_batcher.state.executionCount}'),
                  Text('Total Items Processed: ${_batcher.state.totalItemsProcessed}'),
                  Text('Is Pending: ${_batcher.state.isPending}'),
                  const SizedBox(height: 8),
                  Text('Async Batcher Status: ${_asyncBatcher.state.status}'),
                  Text('Success Count: ${_asyncBatcher.state.successCount}'),
                  Text('Failed Items: ${_asyncBatcher.state.failedItems.length}'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Explanation
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('How Batching Works', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('• Batch triggers when size reaches $_maxSize items'),
                  Text('• Or when ${_wait.inSeconds} seconds timeout occurs'),
                  Text('• Whichever condition is met first'),
                  Text('• Manual execution/flush also available'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Retrying Demo with configurable parameters
class RetryingDemo extends StatefulWidget {
  const RetryingDemo({super.key});

  @override
  State<RetryingDemo> createState() => _RetryingDemoState();
}

class _RetryingDemoState extends State<RetryingDemo> {
  final AsyncRetryer _retryer = AsyncRetryer(
    (args) async {
      final attempt = args[0] as int;
      final shouldFail = attempt < 3; // Fail first 2 attempts

      if (shouldFail) {
        throw Exception('Simulated failure on attempt $attempt');
      }

      // Simulate successful API call
      await Future.delayed(const Duration(milliseconds: 200));
      return {'success': true, 'attempt': attempt, 'data': 'Pokemon data'};
    },
    AsyncRetryerOptions(
      maxAttempts: 5,
      backoff: BackoffType.exponential,
      baseWait: const Duration(milliseconds: 500),
      onRetry: (attempt, error) {
        debugPrint('Retry attempt $attempt after error: $error');
      },
      onSuccess: (result) {
        debugPrint('Retry succeeded: $result');
      },
      onError: (error) {
        debugPrint('Retry failed: $error');
      },
    ),
  );

  late AnyAsyncFunction _retryFunction;

  int _retryCount = 0;
  int _maxAttempts = 3;
  BackoffType _backoffType = BackoffType.exponential;
  Duration _baseWait = const Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    _createRetryFunction();
  }

  void _createRetryFunction() {
    _retryFunction = asyncRetry(
      (args) async {
        final attempt = args[0] as int;
        final shouldFail = attempt < (_maxAttempts - 1); // Fail until last attempt

        if (shouldFail) {
          throw Exception('Function retry failure on attempt $attempt');
        }

        await Future.delayed(const Duration(milliseconds: 150));
        return 'Function retry success on attempt $attempt';
      },
      AsyncRetryerOptions(
        maxAttempts: _maxAttempts,
        backoff: _backoffType,
        baseWait: _baseWait,
      ),
    );
  }

  void _updateMaxAttempts(double value) {
    setState(() => _maxAttempts = value.toInt());
    _createRetryFunction();
  }

  void _updateBaseWait(double value) {
    setState(() => _baseWait = Duration(milliseconds: value.toInt()));
    _createRetryFunction();
  }

  void _updateBackoffType(BackoffType? value) {
    if (value != null) {
      setState(() => _backoffType = value);
      _createRetryFunction();
    }
  }

  @override
  void dispose() {
    _retryer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.refresh, color: Colors.grey.shade700, size: 24),
                SizedBox(width: 12),
                Text(
                  'Retrying Demo',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Configuration
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Configuration', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Max Attempts: $_maxAttempts'),
                  Slider(
                    value: _maxAttempts.toDouble(),
                    min: 1,
                    max: 10,
                    divisions: 9,
                    label: '$_maxAttempts',
                    onChanged: _updateMaxAttempts,
                  ),
                  const SizedBox(height: 8),
                  Text('Base Wait: ${_baseWait.inMilliseconds}ms'),
                  Slider(
                    value: _baseWait.inMilliseconds.toDouble(),
                    min: 100,
                    max: 2000,
                    divisions: 19,
                    label: '${_baseWait.inMilliseconds}ms',
                    onChanged: _updateBaseWait,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Backoff Type:'),
                      const SizedBox(width: 16),
                      DropdownButton<BackoffType>(
                        value: _backoffType,
                        items: BackoffType.values.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type.name.toUpperCase()),
                          );
                        }).toList(),
                        onChanged: _updateBackoffType,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade200,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.bug_report, color: Colors.deepPurple.shade600),
                    const SizedBox(width: 8),
                    const Text(
                      'Test retry logic with simulated failures:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          _retryCount++;
                          try {
                            final result = await _retryer.execute([_retryCount]);
                            if (!mounted) return;
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const Icon(Icons.check_circle, color: Colors.white),
                                        const SizedBox(width: 8),
                                        Text('Retry succeeded: ${result['attempt']}'),
                                      ],
                                    ),
                                    backgroundColor: Colors.green.shade600,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            });
                          } catch (e) {
                            if (!mounted) return;
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const Icon(Icons.error, color: Colors.white),
                                        const SizedBox(width: 8),
                                        Text('Retry failed: $e'),
                                      ],
                                    ),
                                    backgroundColor: Colors.red.shade600,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            });
                          }
                        },
                        icon: Icon(Icons.refresh),
                        label: const Text('Test Retry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          _retryCount++;
                          try {
                            final result = await _retryFunction([_retryCount]);
                            if (!mounted) return;
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const Icon(Icons.check_circle, color: Colors.white),
                                        const SizedBox(width: 8),
                                        Text('Function retry: $result'),
                                      ],
                                    ),
                                    backgroundColor: Colors.blue.shade600,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            });
                          } catch (e) {
                            if (!mounted) return;
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const Icon(Icons.error, color: Colors.white),
                                        const SizedBox(width: 8),
                                        Text('Function retry failed: $e'),
                                      ],
                                    ),
                                    backgroundColor: Colors.orange.shade600,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            });
                          }
                        },
                        icon: const Icon(Icons.functions),
                        label: const Text('Function Retry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // State Information
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('State Information', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Retryer Status: ${_retryer.state.status}'),
                  Text('Current Attempt: ${_retryer.state.currentAttempt}'),
                  Text('Execution Count: ${_retryer.state.executionCount}'),
                  Text('Error Count: ${_retryer.state.errorCount}'),
                  Text('Success Count: ${_retryer.state.successCount}'),
                  Text('Last Error: ${_retryer.state.lastError}'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Explanation
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('How Retrying Works', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('• Max Attempts: $_maxAttempts total tries'),
                  Text('• Backoff: ${_backoffType.name} delay between retries'),
                  Text('• Base Wait: ${_baseWait.inMilliseconds}ms initial delay'),
                  Text('• First ${_maxAttempts - 1} attempts will fail, last succeeds'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}