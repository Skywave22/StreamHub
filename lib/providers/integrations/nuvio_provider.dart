import '../provider.dart';
import '../tmdb_backed_provider.dart';

/// Nuvio integration.
///
/// Metadata is served by TMDB; sources are discovered through Nuvio plugins
/// installed via raw URL. The native source engine is an isolated integration
/// point and is never bundled with the core app.
class NuvioProvider extends TmdbBackedProvider {
  NuvioProvider({required super.tmdb, required super.engine, required super.config});

  @override
  String get id => 'nuvio';

  @override
  String get name => 'Nuvio';

  @override
  String get version => '1.0.0';

  @override
  String get description =>
      'Nuvio provider. Metadata via TMDB; sources via Nuvio plugins installed from a raw plugin URL.';

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
      );
}
