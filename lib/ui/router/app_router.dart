import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/episode.dart';
import '../../core/models/media_item.dart';
import '../../core/models/media_source.dart';
import '../screens/details_screen.dart';
import '../screens/home_screen.dart';
import '../screens/library_screen.dart';
import '../screens/player_screen.dart';
import '../screens/search_screen.dart';
import '../screens/settings/about_screen.dart';
import '../screens/settings/add_plugin_screen.dart';
import '../screens/settings/plugin_manager_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/settings/tmdb_settings_screen.dart';
import '../widgets/app_shell.dart';

/// Everything the player needs to start a session.
class PlayerRequest {
  const PlayerRequest({
    required this.item,
    required this.source,
    this.sources = const [],
    this.seasonNumber,
    this.episodeNumber,
    this.episodeName,
    this.upcoming = const [],
    this.episodes = const [],
    this.currentEpisodeIndex = -1,
  });

  final MediaItem item;
  final MediaSource source;
  final List<MediaSource> sources;
  final int? seasonNumber;
  final int? episodeNumber;
  final String? episodeName;
  final List<Episode> upcoming;
  final List<Episode> episodes;
  final int currentEpisodeIndex;
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
          GoRoute(path: '/search', builder: (context, state) => const SearchScreen()),
          GoRoute(path: '/library', builder: (context, state) => const LibraryScreen()),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
            routes: [
              GoRoute(path: 'plugins', builder: (context, state) => const PluginManagerScreen()),
              GoRoute(path: 'plugins/add', builder: (context, state) => const AddPluginScreen()),
              GoRoute(path: 'tmdb', builder: (context, state) => const TmdbSettingsScreen()),
              GoRoute(path: 'about', builder: (context, state) => const AboutScreen()),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/details/:id',
        builder: (context, state) =>
            DetailsScreen(mediaId: state.pathParameters['id']!, initialItem: state.extra as MediaItem?),
      ),
      GoRoute(
        path: '/player',
        builder: (context, state) => PlayerScreen(request: state.extra as PlayerRequest),
      ),
    ],
  );
});
