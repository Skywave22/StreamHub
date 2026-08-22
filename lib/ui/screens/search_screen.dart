import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/media_item.dart';
import '../../core/models/media_type.dart';
import '../../core/models/search_filter.dart';
import '../../core/platform/platform_info.dart';
import '../../core/providers.dart';
import '../../core/utils/debouncer.dart';
import '../../providers/provider.dart' as prov;
import '../widgets/empty_error.dart';
import '../widgets/poster_tile.dart';
import '../widgets/skeletons.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final Debouncer _debouncer = Debouncer(const Duration(milliseconds: 400));
  final ScrollController _scroll = ScrollController();

  MediaType? _type;
  String? _providerId;
  int? _year;
  String? _genre;
  List<String> _genres = const [];

  List<MediaItem> _results = const [];
  bool _loading = false;
  bool _loadingMore = false;
  int _page = 1;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadGenres();
  }

  @override
  void dispose() {
    _debouncer.dispose();
    _scroll.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadGenres() async {
    try {
      final tmdb = ref.read(tmdbServiceProvider);
      final movie = await tmdb.genres(MediaType.movie);
      final tv = await tmdb.genres(MediaType.tv);
      if (!mounted) return;
      setState(() => _genres = {...movie, ...tv}.toList()..sort());
    } catch (_) {
      // genres are optional; ignore failures
    }
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) {
      _searchNext();
    }
  }

  void _onChanged(String q) {
    _debouncer.run(() => _search(1));
  }

  Future<void> _search(int page) async {
    final query = _controller.text.trim();
    if (query.isEmpty) {
      setState(() {
        _results = const [];
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() {
      if (page == 1) {
        _loading = true;
      } else {
        _loadingMore = true;
      }
      _error = null;
    });
    try {
      final items = await ref.read(searchServiceProvider).search(
            query,
            filter: SearchFilter(type: _type, providerId: _providerId, year: _year, genre: _genre),
            page: page,
          );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _page = page;
        _hasMore = items.length >= 20;
        _results = page == 1 ? items : [..._results, ...items];
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = 'Unable to search right now.\nCheck your connection and TMDB key.';
      });
    }
  }

  void _searchNext() {
    if (_hasMore && !_loading && !_loadingMore) {
      _search(_page + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pluginManager = ref.watch(pluginManagerProvider);
    final providers = pluginManager.activeProviders(currentPlatform());

    return Scaffold(
      appBar: AppBar(title: const Text('Search', style: TextStyle(fontWeight: FontWeight.w700))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _controller,
              onChanged: _onChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search movies and TV shows…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(icon: const Icon(Icons.close), onPressed: () {
                        _controller.clear();
                        setState(() => _results = const []);
                      }),
              ),
            ),
          ),
          _buildFilters(providers),
          const Divider(height: 1),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildFilters(List<prov.StreamProvider> providers) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          SegmentedButton<MediaType?>(
            segments: const [
              ButtonSegment(value: null, label: Text('All')),
              ButtonSegment(value: MediaType.movie, label: Text('Movies')),
              ButtonSegment(value: MediaType.tv, label: Text('TV')),
            ],
            selected: {_type},
            onSelectionChanged: (s) {
              setState(() => _type = s.first);
              _search(1);
            },
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
          ),
          const SizedBox(width: 8),
          _dropdown<String?>(
            value: _providerId,
            hint: 'Provider',
            items: [null, ...providers.map((p) => p.id)],
            label: (v) => v == null ? 'All providers' : providers.firstWhere((p) => p.id == v).name,
            onChanged: (v) {
              setState(() => _providerId = v);
              _search(1);
            },
          ),
          const SizedBox(width: 8),
          _dropdown<int?>(
            value: _year,
            hint: 'Year',
            items: [null, ...List.generate(27, (i) => 2026 - i)],
            label: (v) => v == null ? 'Any year' : '$v',
            onChanged: (v) {
              setState(() => _year = v);
              _search(1);
            },
          ),
          if (_genres.isNotEmpty) ...[
            const SizedBox(width: 8),
            _dropdown<String?>(
              value: _genre,
              hint: 'Genre',
              items: [null, ..._genres],
              label: (v) => v ?? 'Any genre',
              onChanged: (v) {
                setState(() => _genre = v);
                _search(1);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _dropdown<T>({
    required T? value,
    required String hint,
    required List<T?> items,
    required String Function(T?) label,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButton<T?>(
      value: items.contains(value) ? value : null,
      hint: Text(hint),
      items: items
          .map((v) => DropdownMenuItem<T?>(value: v, child: Text(label(v), overflow: TextOverflow.ellipsis)))
          .toList(),
      onChanged: (v) => onChanged(v),
      underline: const SizedBox.shrink(),
      borderRadius: BorderRadius.circular(12),
    );
  }

  Widget _buildBody() {
    if (_loading) return _gridSkeleton();
    if (_error != null) return ErrorState(message: _error!, onRetry: () => _search(1));
    if (_results.isEmpty && _controller.text.trim().isEmpty) {
      return const EmptyState(title: 'Search', subtitle: 'Find movies and TV shows across all enabled providers.', icon: Icons.search);
    }
    if (_results.isEmpty) {
      return const EmptyState(title: 'No results', subtitle: 'Try a different title or filter.');
    }
    return GridView.builder(
      controller: _scroll,
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 140,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2 / 3,
      ),
      itemCount: _results.length + (_loadingMore ? 4 : 0),
      itemBuilder: (context, i) {
        if (i >= _results.length) return const Skeleton(radius: 14);
        final item = _results[i];
        return PosterTile(item: item, onTap: () => context.push('/details/${item.id}', extra: item));
      },
    );
  }

  Widget _gridSkeleton() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 140, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 2 / 3),
      itemCount: 12,
      itemBuilder: (_, __) => const Skeleton(radius: 14),
    );
  }
}
