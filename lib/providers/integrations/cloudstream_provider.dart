import '../provider.dart';
import '../tmdb_backed_provider.dart';

/// CloudStream integration — Android only.
///
/// CloudStream uses its legitimate extension-repository architecture (short
/// codes / repository URLs). Because CloudStream is an Android application, this
/// provider is restricted to Android and is hidden on Windows and Linux. The
/// native extension engine is an isolated integration point; the core app does
/// not bypass any CloudStream security, authentication or access control.
class CloudStreamProvider extends TmdbBackedProvider {
  CloudStreamProvider({required super.tmdb, required super.engine, required super.config});

  @override
  String get id => 'cloudstream';

  @override
  String get name => 'CloudStream';

  @override
  String get version => '1.0.0';

  @override
  String get description =>
      'CloudStream provider (Android only). Integrates via CloudStream extension repositories.';

  @override
  Set<ProviderPlatform> get supportedPlatforms => const {ProviderPlatform.android};

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
