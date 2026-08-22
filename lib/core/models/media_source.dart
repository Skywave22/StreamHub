/// A concrete playable source offered by a provider.
///
/// Sources are only marked [verified] after an actual reachability probe;
/// StreamHub never claims a source works without testing it.
class MediaSource {
  const MediaSource({
    required this.id,
    required this.providerId,
    required this.name,
    required this.url,
    this.quality,
    this.resolution,
    this.codec,
    this.language,
    this.subtitles = const [],
    this.audioTracks = const [],
    this.verified = false,
    this.headers = const {},
  });

  final String id;
  final String providerId;
  final String name;
  final String url;
  final String? quality;
  final String? resolution;
  final String? codec;
  final String? language;
  final List<String> subtitles;
  final List<String> audioTracks;
  final bool verified;
  final Map<String, String> headers;

  MediaSource copyWith({bool? verified}) => MediaSource(
        id: id,
        providerId: providerId,
        name: name,
        url: url,
        quality: quality,
        resolution: resolution,
        codec: codec,
        language: language,
        subtitles: subtitles,
        audioTracks: audioTracks,
        verified: verified ?? this.verified,
        headers: headers,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'providerId': providerId,
        'name': name,
        'url': url,
        'quality': quality,
        'resolution': resolution,
        'codec': codec,
        'language': language,
        'subtitles': subtitles,
        'audioTracks': audioTracks,
        'verified': verified,
      };

  factory MediaSource.fromJson(Map<String, dynamic> json) => MediaSource(
        id: json['id'] as String? ?? '',
        providerId: json['providerId'] as String? ?? '',
        name: json['name'] as String? ?? '',
        url: json['url'] as String? ?? '',
        quality: json['quality'] as String?,
        resolution: json['resolution'] as String?,
        codec: json['codec'] as String?,
        language: json['language'] as String?,
        subtitles: (json['subtitles'] as List?)?.whereType<String>().toList() ?? const [],
        audioTracks: (json['audioTracks'] as List?)?.whereType<String>().toList() ?? const [],
        verified: json['verified'] as bool? ?? false,
      );
}
