import '../core/models/media_item.dart';
import '../core/models/search_filter.dart';
import '../core/platform/platform_info.dart';
import '../providers/plugin_manager.dart';

/// Aggregates global search across all active, platform-compatible providers,
/// deduplicates results by canonical id, and applies client-side filters.
class SearchService {
  SearchService({required this.pluginManager});

  final PluginManager pluginManager;

  Future<List<MediaItem>> search(
    String query, {
    SearchFilter? filter,
    AppPlatform? platform,
    int page = 1,
  }) async {
    final p = platform ?? currentPlatform();
    if (query.trim().isEmpty) return const [];

    var providers = pluginManager.activeProviders(p);
    if (filter?.providerId != null) {
      providers = providers.where((prov) => prov.id == filter!.providerId).toList();
    }
    final seen = <String>{};
    final results = <MediaItem>[];

    final providerResults = await Future.wait(
      providers.map((provider) async {
        try {
          return await provider.search(query, filter: filter, page: page);
        } catch (_) {
          return const <MediaItem>[];
        }
      }),
    );

    for (final items in providerResults) {
      for (final item in items) {
        if (seen.add(item.id)) results.add(item);
      }
    }

    return _applyFilter(results, filter);
  }

  List<MediaItem> _applyFilter(List<MediaItem> items, SearchFilter? filter) {
    if (filter == null || filter.isEmpty) return items;
    return items.where((item) {
      if (filter.type != null && item.type != filter.type) return false;
      if (filter.year != null && item.releaseYear != filter.year) return false;
      if (filter.genre != null &&
          filter.genre!.isNotEmpty &&
          !item.genres.any((g) => g.toLowerCase() == filter.genre!.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();
  }
}
