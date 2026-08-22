import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/errors/app_exception.dart';
import '../../core/models/episode.dart';
import '../../core/models/media_details.dart';
import '../../core/models/media_item.dart';
import '../../core/models/media_source.dart';
import '../../core/platform/platform_info.dart';
import '../../core/providers.dart';
import '../../core/storage/settings_store.dart';
import '../router/app_router.dart';
import '../widgets/empty_error.dart';
import '../widgets/poster_tile.dart';
import '../widgets/rating_stars.dart';

class DetailsScreen extends ConsumerStatefulWidget {
  const DetailsScreen({super.key, required this.mediaId, this.initialItem});

  final String mediaId;
  final MediaItem? initialItem;

  @override
  ConsumerState<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends ConsumerState<DetailsScreen> {
  MediaDetails? _details;
  bool _loading = true;
  String? _error;
  int _selectedSeason = 1;
  List<Episode> _episodes = const [];
  bool _loadingEpisodes = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool get _isExternal => widget.mediaId.startsWith('ext:') || widget.mediaId.startsWith('addon:');

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      MediaDetails? details;
      if (_isExternal) {
        final pm = ref.read(pluginManagerProvider);
        final parts = widget.mediaId.split(':');
        final providerId = parts.length >= 2 ? '${parts[0]}:${parts[1]}' : '';
        final provider = pm.findProvider(providerId, currentPlatform());
        if (provider == null) {
          throw const AppException(AppErrorKind.pluginNotFound, message: 'The provider for this title is not installed.');
        }
        details = await provider.getDetails(widget.mediaId);
      } else {
        final tmdb = ref.read(tmdbServiceProvider);
        details = await tmdb.getDetails(widget.mediaId);
      }
      if (!mounted) return;
      setState(() {
        _details = details;
        _loading = false;
        if (details != null && details.isTv && details.seasons.isNotEmpty) {
          _selectedSeason = details.seasons.first.seasonNumber;
        }
      });
      if (details != null && details.isTv) _loadEpisodes(_selectedSeason);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is AppException ? e.message : 'Could not load this title.';
      });
    }
  }

  Future<void> _loadEpisodes(int season) async {
    setState(() {
      _selectedSeason = season;
      _loadingEpisodes = true;
    });
    try {
      if (_isExternal) {
        final all = _details?.episodes ?? const <Episode>[];
        setState(() {
          _episodes = all.where((e) => e.seasonNumber == season).toList();
          _loadingEpisodes = false;
        });
        return;
      }
      final tmdb = ref.read(tmdbServiceProvider);
      final episodes = await tmdb.getEpisodes(widget.mediaId, season);
      if (!mounted) return;
      setState(() {
        _episodes = episodes;
        _loadingEpisodes = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _episodes = const [];
        _loadingEpisodes = false;
      });
    }
  }

  Future<void> _play({int? season, int? episode, String? episodeName}) async {
    final details = _details;
    if (details == null) return;
    final resolver = ref.read(sourceResolverProvider);
    final sources = await resolver.gather(
      details.item,
      season: season,
      episode: episode,
    );
    if (!mounted) return;
    if (sources.isEmpty) {
      _snack('No sources for this title.\nInstall a plugin or configure a direct source.');
      return;
    }
    final mode = ref.read(settingsStoreProvider).sourceSelectionMode;
    final picked = resolver.pick(sources, mode);
    if (picked != null && mode != SourceSelectionMode.manual) {
      await _resolveAndPlay(picked, season: season, episode: episode, episodeName: episodeName);
    } else {
      _showSourceSheet(sources, season: season, episode: episode, episodeName: episodeName);
    }
  }

  Future<void> _resolveAndPlay(MediaSource source, {int? season, int? episode, String? episodeName}) async {
    try {
      final provider = ref.read(pluginManagerProvider).findProvider(source.providerId, currentPlatform());
      final verified = provider != null ? await provider.resolveSource(source) : source;
      if (!mounted) return;
      final details = _details!;
      final upcoming = _episodes.where((e) => e.episodeNumber > (episode ?? 0)).toList();
      final index = episode != null ? _episodes.indexWhere((e) => e.episodeNumber == episode) : -1;
      context.push(
        '/player',
        extra: PlayerRequest(
          item: details.item,
          source: verified,
          sources: const [],
          seasonNumber: season,
          episodeNumber: episode,
          episodeName: episodeName,
          upcoming: upcoming,
          episodes: _episodes,
          currentEpisodeIndex: index,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _snack(e is AppException ? e.message : 'Could not play this source.');
    }
  }

  void _showSourceSheet(List<MediaSource> sources, {int? season, int? episode, String? episodeName}) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Choose source', style: Theme.of(context).textTheme.titleLarge),
            ),
            for (final s in sources)
              ListTile(
                leading: const Icon(Icons.play_circle_outline),
                title: Text(s.name),
                subtitle: Text([
                  s.providerId,
                  s.resolution,
                  s.quality,
                  s.codec,
                  if (s.language != null) s.language,
                  if (s.subtitles.isNotEmpty) '${s.subtitles.length} subs',
                ].where((e) => e != null && e.isNotEmpty).join(' · ')),
                trailing: s.verified ? const Icon(Icons.verified, color: Colors.green) : null,
                onTap: () {
                  Navigator.pop(context);
                  _resolveAndPlay(s, season: season, episode: episode, episodeName: episodeName);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryStoreProvider);
    final details = _details;
    final isFav = details != null && library.isFavorite(details.item.id);
    final isWatchlist = details != null && library.isInWatchlist(details.item.id);
    final isWatched = details != null && library.isWatched(details.item.id);

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null || details == null) {
      return Scaffold(
        appBar: AppBar(),
        body: ErrorState(message: _error ?? 'Could not load this title.', onRetry: _load),
      );
    }

    final item = details.item;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: _backdrop(item),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (item.originalTitle != null && item.originalTitle != item.title) item.originalTitle!,
                      if (item.releaseYear != null) '${item.releaseYear}',
                      if (details.runtimeMinutes != null) '${details.runtimeMinutes} min',
                      if (item.type.isTv) '${details.seasonCount} seasons',
                    ].join(' · '),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  if (item.rating != null)
                    Row(children: [
                      RatingStars(rating: item.rating!),
                      const SizedBox(width: 8),
                      Text('${item.rating!.toStringAsFixed(1)}/10', style: Theme.of(context).textTheme.bodyMedium),
                    ]),
                  if (item.genres.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: item.genres.map((g) => Chip(label: Text(g))).toList(),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: () => _play(season: item.type.isTv ? _selectedSeason : null, episode: item.type.isTv ? (_episodes.isNotEmpty ? _episodes.first.episodeNumber : 1) : null),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Play'),
                      ),
                      if (details.trailerKey != null)
                        OutlinedButton.icon(
                          onPressed: () => launchUrl(Uri.parse('https://www.youtube.com/watch?v=${details.trailerKey}')),
                          icon: const Icon(Icons.smart_display_outlined),
                          label: const Text('Trailer'),
                        ),
                      IconButton(
                        tooltip: 'Favorite',
                        onPressed: () => library.toggleFavorite(item),
                        icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.redAccent : null),
                      ),
                      IconButton(
                        tooltip: 'Watchlist',
                        onPressed: () => library.toggleWatchlist(item),
                        icon: Icon(isWatchlist ? Icons.bookmark : Icons.bookmark_border),
                      ),
                      IconButton(
                        tooltip: 'Mark watched',
                        onPressed: () => isWatched ? library.markUnwatched(item.id) : library.markWatched(item),
                        icon: Icon(isWatched ? Icons.check_circle : Icons.check_circle_outline),
                      ),
                      IconButton(
                        tooltip: 'Choose source',
                        onPressed: () => _play(season: item.type.isTv ? _selectedSeason : null, episode: item.type.isTv ? (_episodes.isNotEmpty ? _episodes.first.episodeNumber : 1) : null),
                        icon: const Icon(Icons.hd_outlined),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (item.overview != null && item.overview!.isNotEmpty) ...[
                    Text('Overview', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(item.overview!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4)),
                  ],
                  const SizedBox(height: 16),
                  _ProviderAvailability(providers: _activeProviderNames()),
                  if (details.cast.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text('Cast', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 150,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: details.cast.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, i) {
                          final p = details.cast[i];
                          return SizedBox(
                            width: 84,
                            child: Column(children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(40),
                                child: SizedBox(
                                  width: 72,
                                  height: 72,
                                  child: p.profileUrl != null && p.profileUrl!.isNotEmpty
                                      ? CachedNetworkImage(imageUrl: p.profileUrl!, fit: BoxFit.cover,
                                          errorWidget: (_, __, ___) => const Icon(Icons.person))
                                      : const Icon(Icons.person),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                              Text(p.character ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                            ]),
                          );
                        },
                      ),
                    ),
                  ],
                  if (item.type.isTv && details.seasons.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text('Seasons', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: details.seasons.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          final s = details.seasons[i];
                          final selected = s.seasonNumber == _selectedSeason;
                          return ChoiceChip(
                            label: Text(s.name ?? 'Season ${s.seasonNumber}'),
                            selected: selected,
                            onSelected: (_) => _loadEpisodes(s.seasonNumber),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_loadingEpisodes)
                      const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
                    else
                      ..._episodes.map((e) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: e.stillUrl != null && e.stillUrl!.isNotEmpty
                                ? ClipRRect(borderRadius: BorderRadius.circular(8),
                                    child: SizedBox(width: 88, height: 50,
                                        child: CachedNetworkImage(imageUrl: e.stillUrl!, fit: BoxFit.cover,
                                            errorWidget: (_, __, ___) => const Icon(Icons.movie))))
                                : null,
                            title: Text('${e.episodeNumber}. ${e.name}'),
                            subtitle: Text(e.airDate ?? ''),
                            trailing: IconButton(
                              icon: const Icon(Icons.play_circle_outline),
                              onPressed: () => _play(season: e.seasonNumber, episode: e.episodeNumber, episodeName: e.name),
                            ),
                            onTap: () => _play(season: e.seasonNumber, episode: e.episodeNumber, episodeName: e.name),
                          )),
                  ],
                  if (details.similar.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text('Similar titles', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 120, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 2 / 3),
                      itemCount: details.similar.length,
                      itemBuilder: (context, i) => PosterTile(
                        item: details.similar[i],
                        onTap: () => context.push('/details/${details.similar[i].id}', extra: details.similar[i]),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _activeProviderNames() =>
      ref.read(pluginManagerProvider).activeProviders(currentPlatform()).map((p) => p.name).toList();

  Widget _backdrop(MediaItem item) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (item.backdropUrl != null && item.backdropUrl!.isNotEmpty)
          CachedNetworkImage(imageUrl: item.backdropUrl!, fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(color: scheme.surfaceContainerHighest))
        else
          Container(color: scheme.surfaceContainerHighest),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.9)],
            ),
          ),
        ),
      ],
    );
  }
}

class _ProviderAvailability extends StatelessWidget {
  const _ProviderAvailability({required this.providers});
  final List<String> providers;

  @override
  Widget build(BuildContext context) {
    if (providers.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Available on', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: providers
              .map((p) => Chip(
                    avatar: const Icon(Icons.circle, size: 10, color: Colors.green),
                    label: Text(p),
                  ))
              .toList(),
        ),
      ],
    );
  }
}
