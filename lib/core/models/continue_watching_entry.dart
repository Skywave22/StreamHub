import 'media_type.dart';

/// Persisted playback progress for the Continue Watching rail.
class ContinueWatchingEntry {
  const ContinueWatchingEntry({
    required this.mediaId,
    required this.type,
    required this.title,
    required this.positionSeconds,
    required this.durationSeconds,
    required this.updatedAt,
    this.posterUrl,
    this.seasonNumber,
    this.episodeNumber,
    this.episodeName,
  });

  final String mediaId;
  final MediaType type;
  final String title;
  final String? posterUrl;
  final int? seasonNumber;
  final int? episodeNumber;
  final String? episodeName;
  final int positionSeconds;
  final int durationSeconds;
  final DateTime updatedAt;

  double get progress => durationSeconds <= 0 ? 0 : (positionSeconds / durationSeconds).clamp(0.0, 1.0);

  Map<String, dynamic> toJson() => {
        'mediaId': mediaId,
        'type': type.apiValue,
        'title': title,
        'posterUrl': posterUrl,
        'seasonNumber': seasonNumber,
        'episodeNumber': episodeNumber,
        'episodeName': episodeName,
        'positionSeconds': positionSeconds,
        'durationSeconds': durationSeconds,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ContinueWatchingEntry.fromJson(Map<String, dynamic> json) => ContinueWatchingEntry(
        mediaId: json['mediaId'] as String? ?? '',
        type: MediaType.fromApi(json['type'] as String?),
        title: json['title'] as String? ?? '',
        posterUrl: json['posterUrl'] as String?,
        seasonNumber: json['seasonNumber'] as int?,
        episodeNumber: json['episodeNumber'] as int?,
        episodeName: json['episodeName'] as String?,
        positionSeconds: json['positionSeconds'] as int? ?? 0,
        durationSeconds: json['durationSeconds'] as int? ?? 0,
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
      );
}
