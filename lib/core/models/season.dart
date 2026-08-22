import 'episode.dart';

class Season {
  const Season({
    required this.seasonNumber,
    this.name,
    this.overview,
    this.posterUrl,
    this.airDate,
    this.episodeCount = 0,
    this.episodes = const [],
  });

  final int seasonNumber;
  final String? name;
  final String? overview;
  final String? posterUrl;
  final String? airDate;
  final int episodeCount;
  final List<Episode> episodes;

  Season copyWith({List<Episode>? episodes}) => Season(
        seasonNumber: seasonNumber,
        name: name,
        overview: overview,
        posterUrl: posterUrl,
        airDate: airDate,
        episodeCount: episodeCount,
        episodes: episodes ?? this.episodes,
      );
}
