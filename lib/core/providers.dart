import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_dependencies.dart';
import '../providers/plugin_manager.dart';
import '../services/playback_controller.dart';
import '../services/playback_engine.dart';
import '../services/search_service.dart';
import '../services/source_resolver.dart';
import '../services/tmdb_service.dart';
import 'storage/library_store.dart';
import 'storage/settings_store.dart';

/// The single composition root, overridden at startup in main().
final depsProvider = Provider<AppDependencies>(
  (ref) => throw StateError('AppDependencies must be overridden at startup.'),
);

final settingsStoreProvider = Provider<SettingsStore>((ref) => ref.watch(depsProvider).settingsStore);
final libraryStoreProvider = Provider<LibraryStore>((ref) => ref.watch(depsProvider).libraryStore);
final tmdbServiceProvider = Provider<TmdbService>((ref) => ref.watch(depsProvider).tmdbService);
final pluginManagerProvider = Provider<PluginManager>((ref) => ref.watch(depsProvider).pluginManager);
final searchServiceProvider = Provider<SearchService>((ref) => ref.watch(depsProvider).searchService);
final playbackControllerProvider = Provider<PlaybackController>((ref) => ref.watch(depsProvider).playbackController);
final playbackEngineProvider = Provider<PlaybackEngine>((ref) => ref.watch(depsProvider).playbackEngine);
final sourceResolverProvider = Provider<SourceResolver>((ref) => SourceResolver(pluginManager: ref.watch(pluginManagerProvider)));
