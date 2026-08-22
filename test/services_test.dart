import 'package:flutter_test/flutter_test.dart';
import 'package:streamhub/core/errors/app_exception.dart';
import 'package:streamhub/core/models/media_source.dart';
import 'package:streamhub/core/models/media_type.dart';
import 'package:streamhub/core/models/search_filter.dart';
import 'package:streamhub/core/networking/cache_store.dart';
import 'package:streamhub/core/storage/settings_store.dart';
import 'package:streamhub/core/utils/versions.dart';
import 'package:streamhub/services/source_resolver.dart';
import 'package:streamhub/services/tmdb_service.dart';

import 'test_helpers.dart';

void main() {
  group('TmdbService key management', () {
    test('save/test/clear API key', () async {
      final adapter = FakeAdapter((o) async {
        final key = o.queryParameters['api_key'];
        if (key == 'good') return jsonBody({'images': {}});
        return jsonBody({'status_message': 'Invalid API key'}, 401);
      });
      final api = fakeApi(adapter);
      final tmdb = TmdbService(api: api, keyStore: MemorySecureStorage());

      expect(await tmdb.hasApiKey, isFalse);
      expect(await tmdb.testKey('good'), isTrue);
      expect(await tmdb.testKey('bad'), isFalse);

      await tmdb.saveApiKey('good');
      expect(await tmdb.hasApiKey, isTrue);
      expect(await tmdb.getApiKey(), 'good');

      await tmdb.clearApiKey();
      expect(await tmdb.hasApiKey, isFalse);
    });
  });

  group('TmdbService data', () {
    Future<Harness> harness() => buildHarness(handler: (o) async {
          final path = o.path;
          if (path.contains('/configuration')) return jsonBody({'images': {}});
          if (path.contains('/genre/movie/list')) {
            return jsonBody({
              'genres': [
                {'id': 28, 'name': 'Action'},
                {'id': 35, 'name': 'Comedy'},
              ],
            });
          }
          if (path.contains('/genre/tv/list')) {
            return jsonBody({
              'genres': [
                {'id': 10759, 'name': 'Action & Adventure'},
              ],
            });
          }
          if (path.contains('/search/tv')) return jsonBody({'results': [tvResult]});
          if (path.contains('/search/multi')) return jsonBody({'results': [movieResult, tvResult]});
          if (path.contains('/movie/550')) return jsonBody(movieDetails);
          return jsonBody({'results': <dynamic>[]});
        });

    test('search returns typed items with genres', () async {
      final h = await harness();
      final items = await h.tmdb.search('fight');
      expect(items.length, 2);
      final movie = items.firstWhere((i) => i.id == 'tmdb:550');
      expect(movie.title, 'Fight Club');
      expect(movie.releaseYear, 1999);
      expect(movie.rating, 8.4);
      expect(movie.genres, contains('Action'));
      final tv = items.firstWhere((i) => i.id == 'tmdb:tv:1399');
      expect(tv.type, MediaType.tv);
    });

    test('search filters by type and year', () async {
      final h = await harness();
      final tv = await h.tmdb.search('x', type: MediaType.tv);
      expect(tv.length, 1);
      expect(tv.first.id, 'tmdb:tv:1399');

      final y1999 = await h.tmdb.search('x', year: 1999);
      expect(y1999.length, 1);
      expect(y1999.first.id, 'tmdb:550');
    });

    test('getDetails parses full movie metadata', () async {
      final h = await harness();
      final details = await h.tmdb.getDetails('tmdb:550');
      expect(details, isNotNull);
      expect(details!.item.title, 'Fight Club');
      expect(details.runtimeMinutes, 139);
      expect(details.cast.first.name, 'Brad Pitt');
      expect(details.trailerKey, 'abc123');
    });

    test('401 maps to a TMDB auth error', () async {
      final h = await buildHarness(handler: (o) async => jsonBody({'status_message': 'bad'}, 401));
      expect(
        () => h.tmdb.getDetails('tmdb:550'),
        throwsA(predicate((e) => e is AppException && e.kind == AppErrorKind.tmdbAuth)),
      );
    });
  });

  group('CacheStore', () {
    test('stores, retrieves and expires entries', () async {
      final box = await openBox();
      final cache = CacheStore(box);
      await cache.putString('k', 'v', ttl: const Duration(minutes: 5));
      expect(await cache.getString('k'), 'v');
      await cache.putString('expired', 'v', ttl: Duration.zero);
      expect(await cache.getString('expired'), isNull);
      await cache.clear();
      expect(await cache.getString('k'), isNull);
    });
  });

  group('SearchService', () {
    test('aggregates providers and deduplicates results', () async {
      final h = await buildHarness(handler: (o) async {
        if (o.path.contains('/genre/movie/list')) {
          return jsonBody({'genres': [{'id': 28, 'name': 'Action'}]});
        }
        return jsonBody({'results': [movieResult, tvResult]});
      });
      final results = await h.searchService.search('fight');
      expect(results.length, 2);
      expect(results.map((r) => r.id).toSet().length, 2);
    });

    test('applies type filter', () async {
      final h = await buildHarness(handler: (o) async {
        if (o.path.contains('/search/tv')) return jsonBody({'results': [tvResult]});
        return jsonBody({'results': [movieResult]});
      });
      final results = await h.searchService.search('fight', filter: const SearchFilter(type: MediaType.tv));
      expect(results.length, 1);
      expect(results.first.type, MediaType.tv);
    });
  });

  group('SourceResolver', () {
    test('picks highest quality, fastest, manual', () async {
      final h = await buildHarness();
      final resolver = SourceResolver(pluginManager: h.pluginManager);
      final sources = [
        const MediaSource(id: 'a', providerId: 'p', name: 'SD', url: 'https://x/1', quality: '480p'),
        const MediaSource(id: 'b', providerId: 'p', name: 'HD', url: 'https://x/2', quality: '1080p'),
        const MediaSource(id: 'c', providerId: 'p', name: '4K', url: 'https://x/3', quality: '2160p'),
      ];
      expect(resolver.pick(sources, SourceSelectionMode.highestQuality)!.id, 'c');
      expect(resolver.pick(sources, SourceSelectionMode.fastest)!.id, 'a');
      expect(resolver.pick(sources, SourceSelectionMode.manual), isNull);
      expect(resolver.pick(sources, SourceSelectionMode.auto)!.id, 'c');
      expect(resolver.pick(const [], SourceSelectionMode.auto), isNull);
    });
  });

  group('Versions', () {
    test('compares semantic versions', () {
      expect(compareVersions('1.0.0', '1.0.1'), lessThan(0));
      expect(compareVersions('1.0.1', '1.0.0'), greaterThan(0));
      expect(compareVersions('2.0.0', '1.9.9'), greaterThan(0));
      expect(compareVersions('1.0.0', '1.0.0'), 0);
    });
  });
}
