import 'media_type.dart';

/// Filters for global search.
class SearchFilter {
  const SearchFilter({
    this.type,
    this.providerId,
    this.year,
    this.genre,
  });

  final MediaType? type;
  final String? providerId;
  final int? year;
  final String? genre;

  bool get isEmpty => type == null && providerId == null && year == null && genre == null;

  SearchFilter copyWith({MediaType? type, String? providerId, int? year, String? genre}) =>
      SearchFilter(
        type: type ?? this.type,
        providerId: providerId ?? this.providerId,
        year: year ?? this.year,
        genre: genre ?? this.genre,
      );

  /// Applies in-memory filtering to a result set.
  List<T> apply<T>(List<T> items, bool Function(T item) matches) {
    if (isEmpty) return items;
    return items.where(matches).toList();
  }
}
