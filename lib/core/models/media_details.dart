import 'episode.dart';
import 'media_item.dart';
import 'person.dart';
import 'season.dart';

/// Full metadata for a movie or TV show detail page.
class MediaDetails {
  const MediaDetails({
    required this.item,
    this.tagline,
    this.runtimeMinutes,
    this.cast = const [],
    this.crew = const [],
    this.similar = const [],
    this.trailerKey,
    this.seasons = const [],
    this.episodes = const [],
    this.providerAvailability = const {},
  });

  final MediaItem item;
  final String? tagline;
  final int? runtimeMinutes;
  final List<Person> cast;
  final List<Person> crew;
  final List<MediaItem> similar;
  final String? trailerKey;
  final List<Season> seasons;

  /// For a TV show, the episodes of the currently selected season.
  final List<Episode> episodes;

  /// providerId -> list of human readable availability labels.
  final Map<String, List<String>> providerAvailability;

  bool get isMovie => item.type.isMovie;
  bool get isTv => item.type.isTv;

  int get seasonCount => seasons.length;
  int get totalEpisodeCount => seasons.fold(0, (a, s) => a + s.episodeCount);
}
