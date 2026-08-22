class Episode {
  const Episode({
    required this.seasonNumber,
    required this.episodeNumber,
    required this.name,
    this.overview,
    this.stillUrl,
    this.airDate,
    this.runtimeMinutes,
    this.rating,
  });

  final int seasonNumber;
  final int episodeNumber;
  final String name;
  final String? overview;
  final String? stillUrl;
  final String? airDate;
  final int? runtimeMinutes;
  final double? rating;

  String get code => 'S${seasonNumber.toString().padLeft(2, '0')}E${episodeNumber.toString().padLeft(2, '0')}';
}
