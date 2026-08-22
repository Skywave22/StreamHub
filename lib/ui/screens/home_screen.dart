import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/continue_watching_entry.dart';
import '../../core/models/media_item.dart';
import '../../core/providers.dart';
import '../widgets/empty_error.dart';
import '../widgets/media_rail.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final Map<String, List<MediaItem>> _network = {};
  Set<String> _loading = {};
  bool _tmdbMissing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
  }

  Future<void> _loadAll() async {
    final tmdb = ref.read(tmdbServiceProvider);
    setState(() => _loading = {'trending', 'popularMovies', 'popularTv', 'newReleases', 'recommendations'});
    Future<void> load(String key, Future<List<MediaItem>> Function() fetch) async {
      try {
        final items = await fetch();
        if (!mounted) return;
        setState(() {
          _network[key] = items;
          _loading.remove(key);
        });
      } catch (e) {
        if (!mounted) return;
        setState(() => _loading.remove(key));
        if (key == 'trending') setState(() => _tmdbMissing = true);
      }
    }

    await Future.wait([
      load('trending', () => tmdb.trending()),
      load('popularMovies', () => tmdb.popularMovies()),
      load('popularTv', () => tmdb.popularTv()),
      load('newReleases', () => tmdb.newReleases()),
      load('recommendations', () async {
        final recent = ref.read(libraryStoreProvider).recentlyWatched(limit: 1);
        if (recent.isEmpty) return <MediaItem>[];
        return tmdb.recommendations(recent.first.id, recent.first.type);
      }),
    ]);
  }

  Future<void> _refresh() async {
    await _loadAll();
  }

  void _open(MediaItem item) => context.push('/details/${item.id}', extra: item);

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryStoreProvider);
    final continueWatching = library.continueWatching();
    final favorites = library.favorites();
    final watchlist = library.watchlist();
    final recently = library.recentlyWatched();

    return Scaffold(
      appBar: AppBar(
        title: const Text('StreamHub', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.go('/search'),
            tooltip: 'Search',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          children: [
            const SizedBox(height: 4),
            if (_tmdbMissing)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  child: ListTile(
                    leading: const Icon(Icons.key),
                    title: const Text('TMDB is not configured'),
                    subtitle: const Text('Add your TMDB API key to see trending and popular titles.'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/settings/tmdb'),
                  ),
                ),
              ),
            _ContinueRail(entries: continueWatching, onOpen: _open),
            MediaRail(
              title: 'Trending',
              items: _network['trending'] ?? const [],
              loading: _loading.contains('trending'),
              onTap: _open,
            ),
            MediaRail(
              title: 'Popular Movies',
              items: _network['popularMovies'] ?? const [],
              loading: _loading.contains('popularMovies'),
              onTap: _open,
            ),
            MediaRail(
              title: 'Popular TV',
              items: _network['popularTv'] ?? const [],
              loading: _loading.contains('popularTv'),
              onTap: _open,
            ),
            MediaRail(
              title: 'New Releases',
              items: _network['newReleases'] ?? const [],
              loading: _loading.contains('newReleases'),
              onTap: _open,
            ),
            if (favorites.isNotEmpty) MediaRail(title: 'Favorites', items: favorites, onTap: _open),
            if (watchlist.isNotEmpty) MediaRail(title: 'Watchlist', items: watchlist, onTap: _open),
            if (recently.isNotEmpty) MediaRail(title: 'Recently Watched', items: recently, onTap: _open),
            if ((_network['recommendations'] ?? const []).isNotEmpty)
              MediaRail(title: 'Recommendations', items: _network['recommendations']!, onTap: _open),
            if (_loading.isEmpty && continueWatching.isEmpty && (_network.values.every((v) => v.isEmpty)) && !_tmdbMissing)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: EmptyState(title: 'Nothing here yet', subtitle: 'Search for movies and TV shows to get started.'),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _ContinueRail extends StatelessWidget {
  const _ContinueRail({required this.entries, required this.onOpen});

  final List<ContinueWatchingEntry> entries;
  final ValueChanged<MediaItem> onOpen;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Text('Continue Watching', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        ),
        SizedBox(
          height: 208,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) => _ContinueCard(entry: entries[i], onTap: () => onOpen(_toItem(entries[i]))),
          ),
        ),
      ],
    );
  }

  MediaItem _toItem(ContinueWatchingEntry e) => MediaItem(id: e.mediaId, type: e.type, title: e.title, posterUrl: e.posterUrl);
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.entry, required this.onTap});

  final ContinueWatchingEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 160,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (entry.posterUrl != null && entry.posterUrl!.isNotEmpty)
                      Image.network(entry.posterUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: scheme.surfaceContainerHighest))
                    else
                      Container(color: scheme.surfaceContainerHighest, child: const Icon(Icons.movie_outlined)),
                    if (entry.episodeName != null)
                      Positioned(
                        left: 6,
                        bottom: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(6)),
                          child: Text(entry.episodeName!, style: const TextStyle(color: Colors.white, fontSize: 10)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: entry.progress, minHeight: 4, backgroundColor: scheme.surfaceContainerHighest),
            ),
            const SizedBox(height: 6),
            Text(entry.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
