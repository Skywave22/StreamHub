import 'dart:convert';

import '../../core/errors/app_exception.dart';
import '../../core/models/episode.dart';
import '../../core/models/media_details.dart';
import '../../core/models/media_item.dart';
import '../../core/models/media_source.dart';
import '../../core/models/media_type.dart';
import '../../core/models/person.dart';
import '../../core/models/search_filter.dart';
import '../../core/models/season.dart';
import '../../core/networking/api_client.dart';
import '../../core/platform/platform_info.dart';
import '../provider.dart';
import 'extension_models.dart';
import 'js/extension_runner.dart';

/// A `StreamProvider` backed by a real installed JS extension. Search, details
/// and source discovery are performed by actually running the extension's
/// `search`/`load`/`loadStreams` entry points in QuickJS.
class JsExtensionProvider implements StreamProvider {
  JsExtensionProvider({
    required this.extension,
    required ExtensionRunner Function() runnerFactory,
    required this.api,
  }) : _runnerFactory = runnerFactory;

  final InstalledExtension extension;
  final ExtensionRunner Function() _runnerFactory;
  final ApiClient api;

  ExtensionRunner? _runner;
  final Map<String, Map<String, dynamic>> _detailCache = {};

  ExtensionRunner get _engine {
    final existing = _runner;
    if (existing != null) return existing;
    final runner = _runnerFactory();
    _runner = runner;
    return runner;
  }

  @override
  bool isSupportedOn(AppPlatform platform) =>
      supportedPlatforms.contains(ProviderPlatform.fromAppPlatform(platform));

  @override
  String get id => 'ext:${extension.packageName}';

  @override
  String get name => extension.name;

  @override
  String get version => '${extension.version}';

  @override
  String get description => extension.description ?? 'Installed extension';

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

  // ---- ids -----------------------------------------------------------------

  static String mediaIdFor(String packageName, String url) =>
      'ext:$packageName:${base64Url.encode(utf8.encode(url))}';

  static (String packageName, String url) decodeMediaId(String mediaId) {
    final parts = mediaId.split(':');
    if (parts.length < 3) throw const AppException(AppErrorKind.storage, message: 'Invalid extension item.');
    final pkg = parts[1];
    final encoded = parts.sublist(2).join(':');
    try {
      return (pkg, utf8.decode(base64Url.decode(encoded)));
    } catch (_) {
      throw const AppException(AppErrorKind.storage, message: 'Invalid extension item.');
    }
  }

  // ---- invocation helpers --------------------------------------------------

  Future<dynamic> _invoke(String fn, [List<dynamic>? args]) async {
    try {
      return await _engine.invoke(fn, args);
    } on AppException {
      rethrow;
    } catch (e) {
      throw runnerError(e);
    }
  }

  static List<Map<String, dynamic>> _dataList(dynamic result) {
    if (result is Map) {
      final d = result['data'];
      if (d is List) return d.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    if (result is List) return result.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    return const [];
  }

  static Map<String, dynamic>? _dataMap(dynamic result) {
    if (result is Map) {
      final d = result['data'];
      if (d is Map) return Map<String, dynamic>.from(d);
    }
    return null;
  }

  // ---- StreamProvider ------------------------------------------------------

  @override
  Future<void> initialize() async {
    await _engine.init();
  }

  @override
  Future<void> shutdown() async {
    _runner?.dispose();
    _runner = null;
  }

  @override
  Future<List<MediaItem>> search(String query, {SearchFilter? filter, int page = 1}) async {
    final result = await _invoke('search', [query]);
    return _dataList(result).map(_itemFromJson).where((i) => i.title.isNotEmpty).toList();
  }

  /// `getHome()` categories (used to enrich the home screen when available).
  Future<Map<String, List<MediaItem>>> getHome() async {
    final result = await _invoke('getHome');
    if (result is! Map || result['data'] is! Map) return const {};
    final data = Map<String, dynamic>.from(result['data'] as Map);
    final out = <String, List<MediaItem>>{};
    data.forEach((k, v) {
      if (v is List) out[k] = v.whereType<Map>().map((e) => _itemFromJson(Map<String, dynamic>.from(e))).toList();
    });
    return out;
  }

  @override
  Future<MediaDetails?> getDetails(String mediaId) async {
    if (!mediaId.startsWith('ext:')) return null;
    final (pkg, url) = decodeMediaId(mediaId);
    if (pkg != extension.packageName) return null;
    final result = await _invoke('load', [url]);
    final data = _dataMap(result);
    if (data == null) return null;
    _detailCache[mediaId] = data;
    final item = _itemFromJson(data);
    final episodes = (data['episodes'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => _episodeFromJson(Map<String, dynamic>.from(e)))
        .where((e) => e.episodeNumber > 0)
        .toList();
    final similar = (data['recommendations'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => _itemFromJson(Map<String, dynamic>.from(e)))
        .toList();
    final cast = (data['cast'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Person(
              name: (e['name'] ?? e['actor'] ?? '').toString(),
              character: e['character'] as String? ?? e['role'] as String?,
              profileUrl: e['photo'] as String? ?? e['image'] as String?,
            ))
        .where((p) => p.name.isNotEmpty)
        .toList();
    final seasons = <Season>[];
    final seasonNumbers = episodes.map((e) => e.seasonNumber).toSet();
    for (final n in seasonNumbers) {
      seasons.add(Season(
        seasonNumber: n,
        name: 'Season $n',
        episodeCount: episodes.where((e) => e.seasonNumber == n).length,
      ));
    }
    return MediaDetails(
      item: item,
      tagline: data['tagline'] as String?,
      runtimeMinutes: data['duration'] as int?,
      cast: cast,
      crew: const [],
      similar: similar,
      trailerKey: null,
      seasons: seasons,
      episodes: episodes,
      providerAvailability: {extension.packageName: [extension.name]},
    );
  }

  @override
  Future<List<Season>> getSeasons(String mediaId) async {
    final d = await getDetails(mediaId);
    return d?.seasons ?? const [];
  }

  @override
  Future<List<Episode>> getEpisodes(String mediaId, int seasonNumber) async {
    final d = await getDetails(mediaId);
    return d?.episodes.where((e) => e.seasonNumber == seasonNumber).toList() ?? const [];
  }

  @override
  Future<List<MediaSource>> getSources(String mediaId, {int? season, int? episode}) async {
    if (!mediaId.startsWith('ext:')) return const [];
    final (_, url) = decodeMediaId(mediaId);
    var targetUrl = url;
    if (season != null && episode != null) {
      final cached = _detailCache[mediaId];
      if (cached != null) {
        final eps = (cached['episodes'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e));
        for (final e in eps) {
          if ((e['season'] as num?)?.toInt() == season && (e['episode'] as num?)?.toInt() == episode) {
            final eu = e['url'];
            if (eu is String && eu.isNotEmpty) targetUrl = eu;
            break;
          }
        }
      }
    }
    final result = await _invoke('loadStreams', [targetUrl]);
    final list = _dataList(result);
    return list.map((s) => _sourceFromJson(s, targetUrl)).where((s) => s.url.isNotEmpty).toList();
  }

  @override
  Future<MediaSource> resolveSource(MediaSource source) async {
    final probe = await api.probe(source.url);
    if (!probe.reachable) {
      throw AppException(
        AppErrorKind.sourceUnavailable,
        message: 'This source could not be reached. Try another source.',
        technical: source.url,
      );
    }
    return source.copyWith(verified: true);
  }

  // ---- mapping -------------------------------------------------------------

  MediaItem _itemFromJson(Map<String, dynamic> j) {
    final typeStr = (j['type'] ?? j['contentType'] ?? 'movie').toString().toLowerCase();
    final type = typeStr == 'movie' ? MediaType.movie : MediaType.tv;
    final url = (j['url'] ?? '').toString();
    return MediaItem(
      id: mediaIdFor(extension.packageName, url),
      type: type,
      title: (j['title'] ?? '').toString(),
      originalTitle: null,
      overview: j['description'] as String?,
      posterUrl: _image(j['posterUrl']),
      backdropUrl: _image(j['bannerUrl']),
      releaseYear: (j['year'] as num?)?.toInt(),
      rating: (j['score'] as num?)?.toDouble(),
      genres: (j['tags'] as List?)?.whereType<String>().toList() ?? const [],
    );
  }

  Episode _episodeFromJson(Map<String, dynamic> j) => Episode(
        seasonNumber: (j['season'] as num?)?.toInt() ?? 1,
        episodeNumber: (j['episode'] as num?)?.toInt() ?? 0,
        name: (j['title'] ?? j['name'] ?? 'Episode').toString(),
        overview: j['description'] as String?,
        stillUrl: _image(j['posterUrl']),
        airDate: j['date'] as String?,
      );

  MediaSource _sourceFromJson(Map<String, dynamic> j, String fallbackUrl) {
    final url = (j['url'] ?? fallbackUrl).toString();
    final subtitles = (j['subtitles'] as List? ?? const [])
        .whereType<Map>()
        .map((s) => (s['label'] ?? s['lang'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .toList();
    final headers = (j['headers'] as Map?)?.map((k, v) => MapEntry(k.toString(), v.toString())) ?? const <String, String>{};
    return MediaSource(
      id: 'ext-src-${url.hashCode.toRadixString(16)}',
      providerId: id,
      name: (j['source'] ?? extension.name).toString(),
      url: url,
      quality: (j['source'] ?? j['quality']).toString(),
      resolution: j['resolution'] as String?,
      language: j['language'] as String?,
      subtitles: subtitles,
      headers: headers,
    );
  }

  static String? _image(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    if (s.isEmpty || s == 'null') return null;
    if (s.startsWith('http')) return s;
    return s;
  }
}
