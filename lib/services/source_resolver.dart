import '../core/models/media_item.dart';
import '../core/models/media_source.dart';
import '../core/platform/platform_info.dart';
import '../core/storage/settings_store.dart';
import '../providers/plugin_manager.dart';

/// Gathers and ranks playable sources across all active providers, and applies
/// the user's source-selection preference.
class SourceResolver {
  SourceResolver({required this.pluginManager});

  final PluginManager pluginManager;

  Future<List<MediaSource>> gather(
    MediaItem item, {
    int? season,
    int? episode,
    AppPlatform? platform,
  }) async {
    final providers = pluginManager.activeProviders(platform ?? currentPlatform());
    final out = <MediaSource>[];
    for (final provider in providers) {
      try {
        final sources = await provider.getSources(item.id, season: season, episode: episode);
        out.addAll(sources);
      } catch (_) {
        // provider unavailable — skip
      }
    }
    return out;
  }

  /// Returns the chosen source for a given mode, or null when the caller should
  /// show the manual picker.
  MediaSource? pick(List<MediaSource> sources, SourceSelectionMode mode) {
    if (sources.isEmpty) return null;
    final sorted = [...sources]..sort((a, b) => _qualityRank(b).compareTo(_qualityRank(a)));
    switch (mode) {
      case SourceSelectionMode.manual:
        return null;
      case SourceSelectionMode.highestQuality:
        return sorted.first;
      case SourceSelectionMode.fastest:
        return sources.first;
      case SourceSelectionMode.auto:
        return sorted.first;
    }
  }

  static int _qualityRank(MediaSource s) {
    final label = '${s.resolution ?? ''} ${s.quality ?? ''}';
    final m = RegExp(r'(\d{3,4})').firstMatch(label);
    if (m == null) return 0;
    return int.tryParse(m.group(1)!) ?? 0;
  }
}
