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
import '../../core/utils/json_util.dart';
import '../provider.dart';
import 'addon_models.dart';
import 'addon_service.dart';

/// A `StreamProvider` backed by a real Nuvio/Stremio-compatible addon.
/// Metadata and streams are fetched over the addon's JSON API.
class AddonProvider implements StreamProvider {
  AddonProvider({required this.addon, required this.service, required this.api});

  final ManagedAddon addon;
  final AddonService service;
  final ApiClient api;

  AddonManifest get manifest => addon.manifest;
  String get base => manifest.baseUrl(addon.manifestUrl);

  @override
  String get id => 'addon:${manifest.id}';

  @override
  String get name => manifest.name;

  @override
  String get version => manifest.version;

  @override
  String get description => manifest.description ?? 'Stremio-compatible addon';

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
        sources: true,
        resolveSource: true,
        subtitles: true,
      );

  @override
  bool isSupportedOn(AppPlatform platform) =>
      supportedPlatforms.contains(ProviderPlatform.fromAppPlatform(platform));

  static String mediaIdFor(String addonId, String type, String id) =>
      'addon:$addonId:$type:${base64Url.encode(utf8.encode(id))}';

  static (String addonId, String type, String id) decodeMediaId(String mediaId) {
    final parts = mediaId.split(':');
    if (parts.length < 4) throw const AppException(AppErrorKind.storage, message: 'Invalid addon item.');
    final addonId = parts[1];
    final type = parts[2];
    final encoded = parts.sublist(3).join(':');
    try {
      return (addonId, type, utf8.decode(base64Url.decode(encoded)));
    } catch (_) {
      throw const AppException(AppErrorKind.storage, message: 'Invalid addon item.');
    }
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<void> shutdown() async {}

  @override
  Future<List<MediaItem>> search(String query, {SearchFilter? filter, int page = 1}) async {
    final q = query.trim().toLowerCase();
    final out = <MediaItem>[];
    final seen = <String>{};
    final types = manifest.types.isEmpty ? const ['movie', 'series'] : manifest.types;
    for (final cat in manifest.catalogs) {
      if (!types.contains(cat.type)) continue;
      try {
        final metas = await service.catalog(manifest, base, cat.type, cat.id);
        for (final m in metas) {
          final name = (m['name'] ?? '').toString().toLowerCase();
          if (!name.contains(q)) continue;
          final item = _itemFromMeta(m, cat.type);
          if (seen.add(item.id)) out.add(item);
        }
      } on AppException {
        // skip failing catalogs
      }
      if (out.length >= 40) break;
    }
    return out;
  }

  @override
  Future<MediaDetails?> getDetails(String mediaId) async {
    if (!mediaId.startsWith('addon:')) return null;
    final (addonId, type, id) = decodeMediaId(mediaId);
    if (addonId != manifest.id) return null;
    final meta = await service.meta(manifest, base, type, id);
    if (meta.isEmpty) return null;
    final item = _itemFromMeta(meta, type);
    final cast = asMapList(meta['cast'])
        .map((c) => Person(
              name: (c['name'] ?? '').toString(),
              character: c['character'] as String?,
              profileUrl: c['photo'] as String?,
            ))
        .where((p) => p.name.isNotEmpty)
        .toList();
    return MediaDetails(
      item: item,
      tagline: meta['tagline'] as String?,
      runtimeMinutes: meta['runtime'] as int?,
      cast: cast,
      crew: const [],
      similar: const [],
      trailerKey: null,
      seasons: const [],
      episodes: const [],
      providerAvailability: {manifest.id: [manifest.name]},
    );
  }

  @override
  Future<List<Season>> getSeasons(String mediaId) async => const [];

  @override
  Future<List<Episode>> getEpisodes(String mediaId, int seasonNumber) async => const [];

  @override
  Future<List<MediaSource>> getSources(String mediaId, {int? season, int? episode}) async {
    if (!mediaId.startsWith('addon:')) return const [];
    final (addonId, type, id) = decodeMediaId(mediaId);
    if (addonId != manifest.id) return const [];
    final streams = await service.streams(manifest, base, type, id);
    return streams.where((s) => (s['url'] ?? '').toString().isNotEmpty).map(_sourceFromJson).toList();
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

  MediaItem _itemFromMeta(Map<String, dynamic> m, String type) {
    final id = (m['id'] ?? '').toString();
    final mediaType = type == 'movie' ? MediaType.movie : MediaType.tv;
    return MediaItem(
      id: mediaIdFor(manifest.id, type, id),
      type: mediaType,
      title: (m['name'] ?? '').toString(),
      overview: m['description'] as String?,
      posterUrl: m['poster'] as String?,
      backdropUrl: m['background'] as String?,
      releaseYear: _year(m),
      releaseDate: m['released'] as String?,
      rating: (m['imdbRating'] as num?)?.toDouble() ?? (m['rating'] as num?)?.toDouble(),
      genres: (m['genres'] as List?)?.whereType<String>().toList() ?? const [],
    );
  }

  int? _year(Map<String, dynamic> m) {
    final released = m['released'] as String? ?? m['year']?.toString();
    if (released == null) return null;
    final match = RegExp(r'(\d{4})').firstMatch(released);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  MediaSource _sourceFromJson(Map<String, dynamic> s) {
    final url = (s['url'] ?? '').toString();
    final name = (s['title'] ?? s['name'] ?? 'Stream').toString();
    final subtitles = asMapList(s['subtitles'])
        .map((sub) => (sub['lang'] ?? sub['label'] ?? '').toString())
        .where((x) => x.isNotEmpty)
        .toList();
    return MediaSource(
      id: 'addon-src-${url.hashCode.toRadixString(16)}',
      providerId: id,
      name: name,
      url: url,
      quality: name,
      subtitles: subtitles,
      headers: const {},
    );
  }
}
