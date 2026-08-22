import '../core/errors/app_exception.dart';
import '../core/models/episode.dart';
import '../core/models/media_details.dart';
import '../core/models/media_item.dart';
import '../core/models/media_source.dart';
import '../core/models/search_filter.dart';
import '../core/models/season.dart';
import '../core/platform/platform_info.dart';
import 'provider.dart';
import 'source_engine.dart';

/// A provider installed from a raw plugin URL / short code.
///
/// Its lifecycle (enable/disable/update/reload/remove/configure) is managed by
/// [PluginManager]; source resolution is isolated behind the
/// [ProviderSourceEngine]. The core app never executes downloaded plugin code.
class ExternalStreamProvider implements StreamProvider {
  ExternalStreamProvider({required this.record, required this.engine});

  final InstalledPlugin record;
  final ProviderSourceEngine engine;

  @override
  String get id => record.id;
  @override
  String get name => record.name;
  @override
  String get version => record.version;
  @override
  String get description => record.description ?? 'Installed plugin';
  @override
  Set<ProviderPlatform> get supportedPlatforms => record.platforms;
  @override
  ProviderCapabilities get capabilities => record.capabilities;

  @override
  bool isSupportedOn(AppPlatform platform) =>
      supportedPlatforms.contains(ProviderPlatform.fromAppPlatform(platform));

  @override
  Future<void> initialize() async {}

  @override
  Future<void> shutdown() async {}

  @override
  Future<List<MediaItem>> search(String query, {SearchFilter? filter, int page = 1}) async {
    throw const AppException(
      AppErrorKind.providerUnavailable,
      message: 'This plugin is installed, but its engine is not bundled with StreamHub.',
    );
  }

  @override
  Future<MediaDetails?> getDetails(String mediaId) async => null;

  @override
  Future<List<Season>> getSeasons(String mediaId) async => const [];

  @override
  Future<List<Episode>> getEpisodes(String mediaId, int seasonNumber) async => const [];

  @override
  Future<List<MediaSource>> getSources(String mediaId, {int? season, int? episode}) async {
    final direct = directSourcesFromConfig(id, record.config);
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
