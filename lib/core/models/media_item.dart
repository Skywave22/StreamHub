import 'media_type.dart';

/// TMDB image base URL — public and stable.
const String kTmdbImageBase = 'https://image.tmdb.org/t/p';

/// A lightweight, provider-agnostic media reference used for cards, search
/// results and library entries.
class MediaItem {
  const MediaItem({
    required this.id,
    required this.type,
    required this.title,
    this.originalTitle,
    this.overview,
    this.posterUrl,
    this.backdropUrl,
    this.releaseYear,
    this.releaseDate,
    this.rating,
    this.voteCount,
    this.genres = const [],
  });

  /// Canonical id such as `tmdb:550`.
  final String id;
  final MediaType type;
  final String title;
  final String? originalTitle;
  final String? overview;
  final String? posterUrl;
  final String? backdropUrl;
  final int? releaseYear;
  final String? releaseDate;
  final double? rating;
  final int? voteCount;
  final List<String> genres;

  MediaItem copyWith({
    String? id,
    MediaType? type,
    String? title,
    String? originalTitle,
    String? overview,
    String? posterUrl,
    String? backdropUrl,
    int? releaseYear,
    String? releaseDate,
    double? rating,
    int? voteCount,
    List<String>? genres,
  }) {
    return MediaItem(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      originalTitle: originalTitle ?? this.originalTitle,
      overview: overview ?? this.overview,
      posterUrl: posterUrl ?? this.posterUrl,
      backdropUrl: backdropUrl ?? this.backdropUrl,
      releaseYear: releaseYear ?? this.releaseYear,
      releaseDate: releaseDate ?? this.releaseDate,
      rating: rating ?? this.rating,
      voteCount: voteCount ?? this.voteCount,
      genres: genres ?? this.genres,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.apiValue,
        'title': title,
        'originalTitle': originalTitle,
        'overview': overview,
        'posterUrl': posterUrl,
        'backdropUrl': backdropUrl,
        'releaseYear': releaseYear,
        'releaseDate': releaseDate,
        'rating': rating,
        'voteCount': voteCount,
        'genres': genres,
      };

  factory MediaItem.fromJson(Map<String, dynamic> json) => MediaItem(
        id: json['id'] as String? ?? '',
        type: MediaType.fromApi(json['type'] as String?),
        title: json['title'] as String? ?? '',
        originalTitle: json['originalTitle'] as String?,
        overview: json['overview'] as String?,
        posterUrl: json['posterUrl'] as String?,
        backdropUrl: json['backdropUrl'] as String?,
        releaseYear: json['releaseYear'] as int?,
        releaseDate: json['releaseDate'] as String?,
        rating: (json['rating'] as num?)?.toDouble(),
        voteCount: json['voteCount'] as int?,
        genres: (json['genres'] as List?)?.whereType<String>().toList() ?? const [],
      );

  static String imageUrl(String? path, {String size = 'w500'}) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '$kTmdbImageBase/$size$path';
  }
}
