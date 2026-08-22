import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/networking/api_client.dart';
import 'core/networking/cache_store.dart';
import 'core/storage/library_store.dart';
import 'core/storage/secure_storage.dart';
import 'core/storage/settings_store.dart';
import 'providers/addons/addon_manager.dart';
import 'providers/addons/addon_service.dart';
import 'providers/extensions/extension_manager.dart';
import 'providers/extensions/repository_service.dart';
import 'providers/integrations/cloudstream_provider.dart';
import 'providers/integrations/nuvio_provider.dart';
import 'providers/integrations/skystream_provider.dart';
import 'providers/plugin_installer.dart';
import 'providers/plugin_manager.dart';
import 'providers/provider_registry.dart';
import 'providers/shortcode_resolver.dart';
import 'providers/source_engine.dart';
import 'services/playback_controller.dart';
import 'services/playback_engine.dart';
import 'services/search_service.dart';
import 'services/tmdb_service.dart';

/// Composition root: constructs and wires every service once.
class AppDependencies {
  AppDependencies({
    required this.apiClient,
    required this.cacheStore,
    required this.secureStorage,
    required this.settingsStore,
    required this.libraryStore,
    required this.tmdbService,
    required this.shortCodeResolver,
    required this.pluginInstaller,
    required this.sourceEngine,
    required this.registry,
    required this.pluginManager,
    required this.searchService,
    required this.playbackController,
    required this.playbackEngine,
    required this.repositoryService,
    required this.extensionManager,
    required this.addonService,
    required this.addonManager,
  });

  final ApiClient apiClient;
  final CacheStore cacheStore;
  final SecureStorage secureStorage;
  final SettingsStore settingsStore;
  final LibraryStore libraryStore;
  final TmdbService tmdbService;
  final ShortCodeResolver shortCodeResolver;
  final PluginInstaller pluginInstaller;
  final ProviderSourceEngine sourceEngine;
  final ProviderRegistry registry;
  final PluginManager pluginManager;
  final SearchService searchService;
  final PlaybackController playbackController;
  final PlaybackEngine playbackEngine;
  final RepositoryService repositoryService;
  final ExtensionManager extensionManager;
  final AddonService addonService;
  final AddonManager addonManager;

  /// Builds the full dependency graph. [hiveDir] is used for tests to target a
  /// temporary directory; [engineFactory] lets tests inject a no-op engine.
  static Future<AppDependencies> create({
    String? hiveDir,
    PlaybackEngine Function()? engineFactory,
  }) async {
    if (hiveDir != null) {
      Hive.init(hiveDir);
    }
    final pluginsBox = await Hive.openBox<String>('plugins');
    final cacheBox = await Hive.openBox<String>('cache');
    final libraryBox = await Hive.openBox<String>('library');
    final extRepoBox = await Hive.openBox<String>('ext_repos');
    final extPluginBox = await Hive.openBox<String>('ext_plugins');
    final extDataBox = await Hive.openBox<String>('ext_data');
    final addonsBox = await Hive.openBox<String>('addons');

    final api = ApiClient();
    final cache = CacheStore(cacheBox);
    final secure = KeychainSecureStorage();
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsStore(prefs);
    final library = LibraryStore(libraryBox);
    final tmdb = TmdbService(api: api, keyStore: secure);
    final shortCodes = ShortCodeResolver(api: api);
    final installer = PluginInstaller(api: api, shortCodes: shortCodes);
    final engine = ProbeSourceEngine(api);

    final repositoryService = RepositoryService(api: api);
    final extensionManager = ExtensionManager(
      repoBox: extRepoBox,
      pluginBox: extPluginBox,
      dataBox: extDataBox,
      repositoryService: repositoryService,
      api: api,
    );
    final addonService = AddonService(api: api);
    final addonManager = AddonManager(box: addonsBox, service: addonService, api: api);

    final registry = ProviderRegistry();
    late final PluginManager pluginManager;
    registry.register(
      'skystream',
      () => SkyStreamProvider(
        tmdb: tmdb,
        engine: engine,
        config: () => pluginManager.byId('skystream')?.config ?? const {},
      ),
    );
    registry.register(
      'nuvio',
      () => NuvioProvider(
        tmdb: tmdb,
        engine: engine,
        config: () => pluginManager.byId('nuvio')?.config ?? const {},
      ),
    );
    registry.register(
      'cloudstream',
      () => CloudStreamProvider(
        tmdb: tmdb,
        engine: engine,
        config: () => pluginManager.byId('cloudstream')?.config ?? const {},
      ),
    );

    pluginManager = PluginManager(
      registry: registry,
      box: pluginsBox,
      installer: installer,
      engine: engine,
    );
    await pluginManager.ensureSeeded();
    // Contributed providers: real JS extensions + Stremio/Nuvio addons.
    pluginManager.extraProviders = () => [
          ...extensionManager.enabledProviders(),
          ...addonManager.enabledProviders(),
        ];

    final search = SearchService(pluginManager: pluginManager);
    final playbackController = PlaybackController(libraryStore: library, settings: settings);
    final playbackEngine = (engineFactory ?? MediaKitPlaybackEngine.new)();

    return AppDependencies(
      apiClient: api,
      cacheStore: cache,
      secureStorage: secure,
      settingsStore: settings,
      libraryStore: library,
      tmdbService: tmdb,
      shortCodeResolver: shortCodes,
      pluginInstaller: installer,
      sourceEngine: engine,
      registry: registry,
      pluginManager: pluginManager,
      searchService: search,
      playbackController: playbackController,
      playbackEngine: playbackEngine,
      repositoryService: repositoryService,
      extensionManager: extensionManager,
      addonService: addonService,
      addonManager: addonManager,
    );
  }
}
