import '../core/models/episode.dart';
import '../core/models/media_details.dart';
import '../core/models/media_item.dart';
import '../core/models/media_source.dart';
import '../core/models/search_filter.dart';
import '../core/models/season.dart';
import '../core/platform/platform_info.dart';
import '../services/tmdb_service.dart';
import 'provider.dart';
import 'source_engine.dart';

/// Base class for bundled providers whose metadata is served by TMDB.
///
/// Source discovery is delegated to the isolated [ProviderSourceEngine]; the
/// core app never bundles scraping logic.
abstract class TmdbBackedProvider implements StreamProvider {
  TmdbBackedProvider({required this.tmdb, required this.engine, required this.config});

  final TmdbService tmdb;
  final ProviderSourceEngine engine;

  /// Reads this provider's live configuration (direct sources etc.).
  final Map<String, dynamic> Function() config;

  @override
  bool isSupportedOn(AppPlatform platform) =>
      supportedPlatforms.contains(ProviderPlatform.fromAppPlatform(platform));

  @override
  Future<void> initialize() async {}

  @override
  Future<void> shutdown() async {}

  @override
  Future<List<MediaItem>> search(String query, {SearchFilter? filter, int page = 1}) =>
      tmdb.search(query, type: filter?.type, year: filter?.year, genre: filter?.genre, page: page);

  @override
  Future<MediaDetails?> getDetails(String mediaId) => tmdb.getDetails(mediaId);

  @override
  Future<List<Season>> getSeasons(String mediaId) => tmdb.getSeasons(mediaId);

  @override
  Future<List<Episode>> getEpisodes(String mediaId, int seasonNumber) =>
      tmdb.getEpisodes(mediaId, seasonNumber);

  @override
  Future<List<MediaSource>> getSources(String mediaId, {int? season, int? episode}) async {
    final direct = directSourcesFromConfig(id, config());
    final engineSources = await engine.getSources(
      providerId: id,
      mediaId: mediaId,
      season: season,
      episode: episode,
    );
    return [...direct, ...engineSources];
  }

  @override
  Future<MediaSource> resolveSource(MediaSource source) => engine.resolveSource(source);
}
