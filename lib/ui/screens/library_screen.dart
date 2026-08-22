import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/continue_watching_entry.dart';
import '../../core/models/media_item.dart';
import '../../core/providers.dart';
import '../widgets/empty_error.dart';
import '../widgets/poster_tile.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryStoreProvider);
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Library', style: TextStyle(fontWeight: FontWeight.w700)),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Favorites'),
              Tab(text: 'Watchlist'),
              Tab(text: 'Watched'),
              Tab(text: 'Continue'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _Grid(items: library.favorites(), empty: 'Nothing in favorites yet.\nTap ♥ on any title.'),
            _Grid(items: library.watchlist(), empty: 'Your watchlist is empty.\nBookmark titles to plan your watching.'),
            _Grid(items: library.recentlyWatched(limit: 200), empty: 'No watched titles yet.'),
            _ContinueTab(entries: library.continueWatching(limit: 200)),
          ],
        ),
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.items, required this.empty});
  final List<MediaItem> items;
  final String empty;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return EmptyState(title: 'Empty', subtitle: empty, icon: Icons.video_library_outlined);
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 140, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 2 / 3),
      itemCount: items.length,
      itemBuilder: (context, i) => PosterTile(
        item: items[i],
        onTap: () => context.push('/details/${items[i].id}', extra: items[i]),
      ),
    );
  }
}

class _ContinueTab extends StatelessWidget {
  const _ContinueTab({required this.entries});
  final List<ContinueWatchingEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const EmptyState(title: 'Nothing in progress', subtitle: 'Start watching something and it will appear here.');
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final e = entries[i];
        return ListTile(
          contentPadding: const EdgeInsets.all(8),
          tileColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 72,
              height: 48,
              child: e.posterUrl != null && e.posterUrl!.isNotEmpty
                  ? Image.network(e.posterUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.movie))
                  : const Icon(Icons.movie),
            ),
          ),
          title: Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (e.episodeName != null) Text(e.episodeName!, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              LinearProgressIndicator(value: e.progress, minHeight: 4),
            ],
          ),
          onTap: () => context.push('/details/${e.mediaId}'),
        );
      },
    );
  }
}
