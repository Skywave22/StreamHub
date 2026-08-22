import '../provider.dart';
import '../tmdb_backed_provider.dart';

/// SkyStream integration.
///
/// Metadata is served by TMDB (configured in Settings). Sources are discovered
/// through SkyStream repositories installed via short code or raw URL; the
/// scraping engine itself is an isolated integration point and is never
/// bundled with or executed by the core app.
class SkyStreamProvider extends TmdbBackedProvider {
  SkyStreamProvider({required super.tmdb, required super.engine, required super.config});

  @override
  String get id => 'skystream';

  @override
  String get name => 'SkyStream';

  @override
  String get version => '1.0.0';

  @override
  String get description =>
      'SkyStream provider. Metadata via TMDB; sources via installed SkyStream repositories (short code or raw URL).';

  @override
  Set<ProviderPlatform> get supportedPlatforms => const {
        ProviderPlatform.android,
        ProviderPlatform.windows,
        ProviderPlatform.linux,
      };

  @override
  ProviderCapabilities get capabilities => const ProviderCapabilities(
        search: true,
        details: true,
        seasons: true,
        episodes: true,
        sources: true,
        resolveSource: true,
        subtitles: true,
        trailers: true,
        shortCode: true,
      );
}
