import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:hive/hive.dart';
import 'package:streamhub/core/networking/api_client.dart';
import 'package:streamhub/core/storage/secure_storage.dart';
import 'package:streamhub/providers/integrations/cloudstream_provider.dart';
import 'package:streamhub/providers/integrations/nuvio_provider.dart';
import 'package:streamhub/providers/integrations/skystream_provider.dart';
import 'package:streamhub/providers/plugin_installer.dart';
import 'package:streamhub/providers/plugin_manager.dart';
import 'package:streamhub/providers/provider_registry.dart';
import 'package:streamhub/providers/shortcode_resolver.dart';
import 'package:streamhub/providers/source_engine.dart';
import 'package:streamhub/services/search_service.dart';
import 'package:streamhub/services/tmdb_service.dart';

/// In-memory secure storage for tests.
class MemorySecureStorage implements SecureStorage {
  final Map<String, String> map = {};

  @override
  Future<String?> read(String key) async => map[key];

  @override
  Future<void> write(String key, String value) async => map[key] = value;

  @override
  Future<void> delete(String key) async => map.remove(key);
}

/// A Dio adapter that routes requests through a handler function.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;
  int callCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    callCount++;
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonBody(Object data, [int status = 200, Map<String, List<String>> headers = const {}]) {
  return ResponseBody.fromString(
    jsonEncode(data),
    status,
    headers: {'content-type': ['application/json'], ...headers},
  );
}

ResponseBody textBody(String text, [int status = 200, Map<String, List<String>> headers = const {}]) {
  return ResponseBody.fromString(text, status, headers: headers);
}

ApiClient fakeApi(
  FakeAdapter adapter, {
  int maxRetries = 2,
  bool debugLogging = false,
  Duration baseDelay = const Duration(milliseconds: 1),
}) {
  final dio = Dio(BaseOptions(
    responseType: ResponseType.bytes,
    validateStatus: (s) => s != null && s < 600,
    followRedirects: true,
  ));
  dio.httpClientAdapter = adapter;
  return ApiClient(dio: dio, maxRetries: maxRetries, debugLogging: debugLogging, baseDelay: baseDelay);
}

bool _hiveReady = false;
int _boxCounter = 0;

Future<Box<String>> openBox() async {
  if (!_hiveReady) {
    final dir = Directory.systemTemp.createTempSync('streamhub_hive');
    Hive.init(dir.path);
    _hiveReady = true;
  }
  return Hive.openBox<String>('box_${_boxCounter++}');
}

/// A fully-wired harness with a fake HTTP layer.
class Harness {
  Harness({
    required this.api,
    required this.adapter,
    required this.secure,
    required this.tmdb,
    required this.engine,
    required this.registry,
    required this.pluginManager,
    required this.searchService,
    required this.installer,
  });

  final ApiClient api;
  final FakeAdapter adapter;
  final MemorySecureStorage secure;
  final TmdbService tmdb;
  final ProviderSourceEngine engine;
  final ProviderRegistry registry;
  final PluginManager pluginManager;
  final SearchService searchService;
  final PluginInstaller installer;
}

Future<Harness> buildHarness({Future<ResponseBody> Function(RequestOptions)? handler}) async {
  final adapter = FakeAdapter(handler ?? (o) async => jsonBody({'results': <dynamic>[]}));
  final api = fakeApi(adapter);
  final secure = MemorySecureStorage();
  final tmdb = TmdbService(api: api, keyStore: secure);
  await tmdb.saveApiKey('test-key');
  final engine = ProbeSourceEngine(api);
  final registry = ProviderRegistry();
  late final PluginManager pluginManager;
  registry.register(
    'skystream',
    () => SkyStreamProvider(tmdb: tmdb, engine: engine, config: () => pluginManager.byId('skystream')?.config ?? const {}),
  );
  registry.register(
    'nuvio',
    () => NuvioProvider(tmdb: tmdb, engine: engine, config: () => pluginManager.byId('nuvio')?.config ?? const {}),
  );
  registry.register(
    'cloudstream',
    () => CloudStreamProvider(tmdb: tmdb, engine: engine, config: () => pluginManager.byId('cloudstream')?.config ?? const {}),
  );
  final installer = PluginInstaller(api: api, shortCodes: ShortCodeResolver(api: api));
  final box = await openBox();
  pluginManager = PluginManager(registry: registry, box: box, installer: installer, engine: engine);
  await pluginManager.ensureSeeded();
  final search = SearchService(pluginManager: pluginManager);
  return Harness(
    api: api,
    adapter: adapter,
    secure: secure,
    tmdb: tmdb,
    engine: engine,
    registry: registry,
    pluginManager: pluginManager,
    searchService: search,
    installer: installer,
  );
}

// ---- Canned TMDB payloads --------------------------------------------------

final Map<String, dynamic> movieResult = {
  'id': 550,
  'media_type': 'movie',
  'title': 'Fight Club',
  'overview': 'An insomniac office worker...',
  'poster_path': '/pb.jpg',
  'release_date': '1999-10-15',
  'vote_average': 8.4,
  'genre_ids': [28],
};

final Map<String, dynamic> tvResult = {
  'id': 1399,
  'media_type': 'tv',
  'name': 'Game of Thrones',
  'first_air_date': '2011-04-17',
  'vote_average': 8.5,
  'genre_ids': <int>[],
};

final Map<String, dynamic> movieDetails = {
  'id': 550,
  'title': 'Fight Club',
  'original_title': 'Fight Club',
  'overview': 'An insomniac office worker...',
  'runtime': 139,
  'vote_average': 8.4,
  'release_date': '1999-10-15',
  'poster_path': '/pb.jpg',
  'backdrop_path': '/bd.jpg',
  'tagline': 'Mischief. Mayhem. Soap.',
  'genres': [
    {'id': 28, 'name': 'Action'},
  ],
  'credits': {
    'cast': [
      {'name': 'Brad Pitt', 'character': 'Tyler Durden'},
    ],
    'crew': [
      {'name': 'David Fincher', 'job': 'Director'},
    ],
  },
  'videos': {
    'results': [
      {'type': 'Trailer', 'site': 'YouTube', 'key': 'abc123'},
    ],
  },
  'similar': {'results': <dynamic>[]},
};
