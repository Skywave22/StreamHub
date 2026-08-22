import 'media_item.dart';

/// An item stored in the user's library (favorites / watchlist / watched).
class LibraryEntry {
  const LibraryEntry({required this.item, required this.addedAt});

  final MediaItem item;
  final DateTime addedAt;

  Map<String, dynamic> toJson() => {'item': item.toJson(), 'addedAt': addedAt.toIso8601String()};

  factory LibraryEntry.fromJson(Map<String, dynamic> json) => LibraryEntry(
        item: MediaItem.fromJson(json['item'] as Map<String, dynamic>),
        addedAt: DateTime.tryParse(json['addedAt'] as String? ?? '') ?? DateTime.now(),
      );
}
