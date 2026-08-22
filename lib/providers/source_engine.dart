import '../core/errors/app_exception.dart';
import '../core/models/media_source.dart';
import '../core/networking/api_client.dart';

/// Isolated boundary for source discovery/resolution.
///
/// The core app never ships scraping logic. Providers plug a
/// [ProviderSourceEngine] in here; the default engine only *verifies* concrete
/// URLs by actually probing them, so StreamHub never claims a source works
/// without testing it.
abstract class ProviderSourceEngine {
  Future<List<MediaSource>> getSources({
    required String providerId,
    required String mediaId,
    int? season,
    int? episode,
  });

  Future<MediaSource> resolveSource(MediaSource source);
}

/// Parses user-configured direct sources from a provider's configuration.
/// These are legitimate, user-provided stream URLs (never scraped content).
List<MediaSource> directSourcesFromConfig(String providerId, Map<String, dynamic> config) {
  final raw = config['directSources'];
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((e) => sourceFromMap(providerId, Map<String, dynamic>.from(e)))
      .where((s) => s.url.isNotEmpty)
      .toList();
}

MediaSource sourceFromMap(String providerId, Map<String, dynamic> m) {
  final url = m['url'] as String? ?? '';
  return MediaSource(
    id: m['id'] as String? ?? 'direct-${url.hashCode.toRadixString(16)}',
    providerId: providerId,
    name: m['name'] as String? ?? 'Configured source',
    url: url,
    quality: m['quality'] as String?,
    resolution: m['resolution'] as String?,
    codec: m['codec'] as String?,
    language: m['language'] as String?,
    subtitles: (m['subtitles'] as List?)?.whereType<String>().toList() ?? const [],
    audioTracks: (m['audioTracks'] as List?)?.whereType<String>().toList() ?? const [],
  );
}

/// Default engine: finds nothing on its own, but performs real reachability
/// probes so only genuinely reachable sources are marked verified.
class ProbeSourceEngine implements ProviderSourceEngine {
  ProbeSourceEngine(this._api);

  final ApiClient _api;

  @override
  Future<List<MediaSource>> getSources({
    required String providerId,
    required String mediaId,
    int? season,
    int? episode,
  }) async {
    return const [];
  }

  @override
  Future<MediaSource> resolveSource(MediaSource source) async {
    final probe = await _api.probe(source.url);
    if (!probe.reachable) {
      throw AppException(
        AppErrorKind.sourceUnavailable,
        message: 'This source could not be reached. Try another source.',
        technical: source.url,
      );
    }
    return source.copyWith(verified: true);
  }
}
