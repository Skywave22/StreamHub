import '../core/errors/app_exception.dart';
import '../core/models/episode.dart';
import '../core/models/media_details.dart';
import '../core/models/media_item.dart';
import '../core/models/media_type.dart';
import '../core/models/person.dart';
import '../core/models/season.dart';
import '../core/networking/api_client.dart';
import '../core/storage/secure_storage.dart';
import '../core/utils/json_util.dart';

/// TMDB metadata integration.
///
/// The user supplies their own API key (stored in [SecureStorage]); the key is
/// never logged, never hard-coded and never committed.
class TmdbService {
  TmdbService({required ApiClient api, required SecureStorage keyStore})
      : _api = api,
        _keyStore = keyStore;

  static const String _base = 'https://api.themoviedb.org/3';
  static const String _keyName = 'tmdb.api_key';
  static const String _language = 'en-US';

  final ApiClient _api;
  final SecureStorage _keyStore;

  final Map<String, Map<int, String>> _genreMapCache = {};

  // ---- Key management ------------------------------------------------------

  Future<String?> getApiKey() => _keyStore.read(_keyName);

  Future<bool> get hasApiKey async => (await getApiKey())?.isNotEmpty ?? false;

  Future<void> saveApiKey(String key) => _keyStore.write(_keyName, key.trim());

  Future<void> clearApiKey() => _keyStore.delete(_keyName);

  /// Verifies a key by calling a lightweight TMDB endpoint.
  Future<bool> testKey(String key) async {
    try {
      final resp = await _api.get('$_base/configuration', query: {'api_key': key});
      return resp.isOk;
    } on HttpException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) return false;
      rethrow;
    }
  }

  // ---- Helpers -------------------------------------------------------------

  Future<Map<String, String>> _authQuery() async {
    final key = await getApiKey();
    if (key == null || key.isEmpty) {
      throw const AppException(
        AppErrorKind.tmdbAuth,
        message: 'TMDB is not configured.\nAdd your API key in Settings → TMDB.',
      );
    }
    return {'api_key': key, 'language': _language};
  }

  Future<Map<String, dynamic>> _getJson(String path, Map<String, String> query, {Duration? ttl}) async {
    final auth = await _authQuery();
    try {
      final resp = await _api.get('$_base$path', query: {...auth, ...query}, cacheTtl: ttl ?? const Duration(hours: 6));
      final json = resp.json;
      if (json == null) {
        throw const AppException(AppErrorKind.tmdbError, message: 'TMDB returned an unexpected response.');
      }
      return json;
    } on HttpException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        throw const AppException(
          AppErrorKind.tmdbAuth,
          message: 'TMDB authentication failed.\nCheck your API key in Settings → TMDB.',
        );
      }
      if (e.statusCode == 429) {
        throw const AppException(AppErrorKind.tmdbError, message: 'TMDB rate limit reached.\nPlease try again later.');
      }
      throw AppException(AppErrorKind.tmdbError, message: 'TMDB is unavailable right now.', technical: e.technical);
    }
  }

  // ---- Search --------------------------------------------------------------

  Future<List<MediaItem>> search(
    String query, {
    MediaType? type,
    int? year,
    String? genre,
    int page = 1,
  }) async {
    if (query.trim().isEmpty) return const [];
    final path = type == null ? '/search/multi' : (type.isTv ? '/search/tv' : '/search/movie');
    final json = await _getJson(path, {'query': query.trim(), 'page': '$page'}, ttl: const Duration(minutes: 30));
    var items = await _itemsFromResults(asMapList(json['results']));
    if (type != null) {
      items = items.where((i) => i.type == type).toList();
    }
    if (year != null) {
      items = items.where((i) => i.releaseYear == year).toList();
    }
    if (genre != null && genre.isNotEmpty) {
      items = items.where((i) => i.genres.map((g) => g.toLowerCase()).contains(genre.toLowerCase())).toList();
    }
    return items;
  }

  // ---- Home rows -----------------------------------------------------------

  Future<List<MediaItem>> trending({MediaType? type, String timeWindow = 'week'}) async {
    final path = type == null ? '/trending/all/$timeWindow' : (type.isTv ? '/trending/tv/$timeWindow' : '/trending/movie/$timeWindow');
    final json = await _getJson(path, {});
    final items = await _itemsFromResults(asMapList(json['results']));
    if (type == null) return items;
    return items.where((i) => i.type == type).toList();
  }

  Future<List<MediaItem>> popularMovies() async {
    final json = await _getJson('/movie/popular', {});
    return _itemsFromResults(asMapList(json['results']), defaultType: MediaType.movie);
  }

  Future<List<MediaItem>> popularTv() async {
    final json = await _getJson('/tv/popular', {});
    return _itemsFromResults(asMapList(json['results']), defaultType: MediaType.tv);
  }

  Future<List<MediaItem>> newReleases() async {
    final movies = await _getJson('/movie/now_playing', {});
    final tv = await _getJson('/tv/on_the_air', {});
    final items = [
      ...await _itemsFromResults(asMapList(movies['results']), defaultType: MediaType.movie),
      ...await _itemsFromResults(asMapList(tv['results']), defaultType: MediaType.tv),
    ];
    items.sort((a, b) => (b.releaseDate ?? '').compareTo(a.releaseDate ?? ''));
    return items;
  }

  Future<List<MediaItem>> similar(String mediaId, MediaType type) async {
    final id = _idOf(mediaId);
    final path = type.isTv ? '/tv/$id/similar' : '/movie/$id/similar';
    final json = await _getJson(path, {});
    return _itemsFromResults(asMapList(json['results']), defaultType: type);
  }

  Future<List<MediaItem>> recommendations(String mediaId, MediaType type) async {
    final id = _idOf(mediaId);
    final path = type.isTv ? '/tv/$id/recommendations' : '/movie/$id/recommendations';
    final json = await _getJson(path, {});
    return _itemsFromResults(asMapList(json['results']), defaultType: type);
  }

  Future<List<String>> genres(MediaType type) async {
    final map = await _genreMap(type);
    return map.values.toSet().toList()..sort();
  }

  // ---- Details -------------------------------------------------------------

  Future<MediaDetails?> getDetails(String mediaId) async {
    final type = mediaId.startsWith('tmdb:tv:') ? MediaType.tv : MediaType.movie;
    final id = _idOf(mediaId);
    final path = type.isTv ? '/tv/$id' : '/movie/$id';
    final json = await _getJson(path, {
      'append_to_response': 'credits,similar,videos,recommendations',
    });

    final genres = asMapList(json['genres']).map((g) => g['name'] as String? ?? '').where((s) => s.isNotEmpty).toList();
    final item = MediaItem(
      id: mediaId,
      type: type,
      title: (type.isTv ? asString(json, 'name') : asString(json, 'title')) ?? '',
      originalTitle: asString(json, 'original_title') ?? asString(json, 'original_name'),
      overview: asString(json, 'overview'),
      posterUrl: MediaItem.imageUrl(asString(json, 'poster_path')),
      backdropUrl: MediaItem.imageUrl(asString(json, 'backdrop_path'), size: 'w780'),
      releaseYear: _yearOf(asString(json, 'first_air_date') ?? asString(json, 'release_date')),
      releaseDate: asString(json, 'first_air_date') ?? asString(json, 'release_date'),
      rating: asDouble(json, 'vote_average'),
      voteCount: asInt(json, 'vote_count'),
      genres: genres,
    );

    final credits = asMap(json, 'credits');
    final cast = asMapList(credits['cast'])
        .map((c) => Person(
              name: c['name'] as String? ?? '',
              character: c['character'] as String?,
              profileUrl: MediaItem.imageUrl(c['profile_path'] as String?, size: 'w185'),
            ))
        .toList();
    final crew = asMapList(credits['crew'])
        .map((c) => Person(
              name: c['name'] as String? ?? '',
              job: c['job'] as String? ?? c['department'] as String?,
              profileUrl: MediaItem.imageUrl(c['profile_path'] as String?, size: 'w185'),
            ))
        .toList();

    final similar = await _itemsFromResults(asMapList(asMap(json, 'similar')['results']), defaultType: type);
    final trailerKey = _trailerKey(asMap(json, 'videos'));

    final seasons = (asList(json, 'seasons'))
        .whereType<Map>()
        .map((s) {
          final m = Map<String, dynamic>.from(s);
          return Season(
            seasonNumber: m['season_number'] as int? ?? 0,
            name: m['name'] as String?,
            overview: m['overview'] as String?,
            posterUrl: MediaItem.imageUrl(m['poster_path'] as String?, size: 'w342'),
            airDate: m['air_date'] as String?,
            episodeCount: m['episode_count'] as int? ?? 0,
          );
        })
        .toList();

    return MediaDetails(
      item: item,
      tagline: asString(json, 'tagline'),
      runtimeMinutes: (asInt(json, 'runtime') ?? asInt(json, 'episode_run_time')),
      cast: cast,
      crew: crew,
      similar: similar,
      trailerKey: trailerKey,
      seasons: seasons,
    );
  }

  Future<List<Season>> getSeasons(String mediaId) async {
    final details = await getDetails(mediaId);
    return details?.seasons ?? const [];
  }

  Future<List<Episode>> getEpisodes(String mediaId, int seasonNumber) async {
    final type = mediaId.startsWith('tmdb:tv:') ? MediaType.tv : MediaType.movie;
    if (type.isMovie) return const [];
    final id = _idOf(mediaId);
    final json = await _getJson('/tv/$id/season/$seasonNumber', {}, ttl: const Duration(hours: 12));
    return asMapList(json['episodes'])
        .map((e) => Episode(
              seasonNumber: seasonNumber,
              episodeNumber: e['episode_number'] as int? ?? 0,
              name: e['name'] as String? ?? '',
              overview: e['overview'] as String?,
              stillUrl: MediaItem.imageUrl(e['still_path'] as String?, size: 'w400'),
              airDate: e['air_date'] as String?,
              runtimeMinutes: e['runtime'] as int?,
              rating: asDouble(e, 'vote_average'),
            ))
        .toList();
  }

  // ---- Internals -----------------------------------------------------------

  String _idOf(String mediaId) {
    // "tmdb:123" / "tmdb:tv:123" -> "123"
    final parts = mediaId.split(':');
    return parts.isEmpty ? mediaId : parts.last;
  }

  int? _yearOf(String? date) {
    if (date == null || date.length < 4) return null;
    return int.tryParse(date.substring(0, 4));
  }

  String? _trailerKey(Map<String, dynamic> videos) {
    for (final v in asMapList(videos['results'])) {
      if ((v['type'] as String? ?? '').toLowerCase() == 'trailer' && (v['site'] as String? ?? '') == 'YouTube') {
        return v['key'] as String?;
      }
    }
    return null;
  }

  Future<Map<int, String>> _genreMap(MediaType type) async {
    final cached = _genreMapCache[type.apiValue];
    if (cached != null) return cached;
    final path = type.isTv ? '/genre/tv/list' : '/genre/movie/list';
    final json = await _getJson(path, {}, ttl: const Duration(hours: 24));
    final map = <int, String>{};
    for (final g in asMapList(json['genres'])) {
      final id = g['id'];
      final name = g['name'];
      if (id is int && name is String) map[id] = name;
    }
    _genreMapCache[type.apiValue] = map;
    return map;
  }

  Future<List<MediaItem>> _itemsFromResults(List<Map<String, dynamic>> results, {MediaType? defaultType}) async {
    // Preload genre maps once per call (avoids duplicate requests).
    final neededTypes = <MediaType>{};
    for (final r in results) {
      if (asList(r, 'genre_ids').isNotEmpty) {
        neededTypes.add(defaultType ?? MediaType.fromApi(asString(r, 'media_type')));
      }
    }
    final maps = <MediaType, Map<int, String>>{};
    for (final t in neededTypes) {
      try {
        maps[t] = await _genreMap(t);
      } catch (_) {
        maps[t] = const {};
      }
    }

    final items = <MediaItem>[];
    for (final r in results) {
      final type = defaultType ?? MediaType.fromApi(asString(r, 'media_type'));
      // Trending "all" can include people; skip non-media entries.
      if (r['id'] == null) continue;
      final genreIds = asList(r, 'genre_ids').whereType<int>().toList();
      final map = maps[type] ?? const <int, String>{};
      final genreNames = genreIds.map((id) => map[id]).whereType<String>().toList();
      items.add(MediaItem(
        id: 'tmdb:${type.apiValue == 'tv' ? 'tv:' : ''}${r['id']}',
        type: type,
        title: (type.isTv ? asString(r, 'name') : asString(r, 'title')) ?? '',
        originalTitle: asString(r, 'original_title') ?? asString(r, 'original_name'),
        overview: asString(r, 'overview'),
        posterUrl: MediaItem.imageUrl(asString(r, 'poster_path')),
        backdropUrl: MediaItem.imageUrl(asString(r, 'backdrop_path'), size: 'w780'),
        releaseYear: _yearOf(asString(r, 'first_air_date') ?? asString(r, 'release_date')),
        releaseDate: asString(r, 'first_air_date') ?? asString(r, 'release_date'),
        rating: asDouble(r, 'vote_average'),
        voteCount: asInt(r, 'vote_count'),
        genres: genreNames,
      ));
    }
    return items;
  }
}
