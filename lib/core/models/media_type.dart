enum MediaType {
  movie('movie'),
  tv('tv');

  const MediaType(this.apiValue);

  final String apiValue;

  bool get isMovie => this == MediaType.movie;
  bool get isTv => this == MediaType.tv;

  static MediaType fromApi(String? v) => v == 'tv' ? MediaType.tv : MediaType.movie;
}
