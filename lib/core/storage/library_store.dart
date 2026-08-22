import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../models/continue_watching_entry.dart';
import '../models/library_entry.dart';
import '../models/media_item.dart';

/// Local library persistence (favorites, watchlist, watched, continue watching)
/// backed by a Hive box. Entries are JSON-encoded strings keyed by media id.
class LibraryStore extends ChangeNotifier {
  LibraryStore(this._box);

  final Box<String> _box;

  static const _fav = 'fav:';
  static const _watchlist = 'wl:';
  static const _watched = 'watched:';
  static const _continue = 'cw:';

  // ---- Favorites -----------------------------------------------------------

  bool isFavorite(String mediaId) => _box.containsKey('$_fav$mediaId');

  Future<void> toggleFavorite(MediaItem item) async {
    final key = '$_fav${item.id}';
    if (_box.containsKey(key)) {
      await _box.delete(key);
    } else {
      await _box.put(key, jsonEncode(LibraryEntry(item: item, addedAt: DateTime.now()).toJson()));
    }
    notifyListeners();
  }

  Future<void> removeFavorite(String mediaId) async {
    await _box.delete('$_fav$mediaId');
    notifyListeners();
  }

  List<MediaItem> favorites() => _sorted(_fav);

  // ---- Watchlist -----------------------------------------------------------

  bool isInWatchlist(String mediaId) => _box.containsKey('$_watchlist$mediaId');

  Future<void> toggleWatchlist(MediaItem item) async {
    final key = '$_watchlist${item.id}';
    if (_box.containsKey(key)) {
      await _box.delete(key);
    } else {
      await _box.put(key, jsonEncode(LibraryEntry(item: item, addedAt: DateTime.now()).toJson()));
    }
    notifyListeners();
  }

  List<MediaItem> watchlist() => _sorted(_watchlist);

  // ---- Watched -------------------------------------------------------------

  bool isWatched(String mediaId) => _box.containsKey('$_watched$mediaId');

  DateTime? watchedAt(String mediaId) {
    final raw = _box.get('$_watched$mediaId');
    if (raw == null) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return DateTime.tryParse(m['watchedAt'] as String? ?? '');
    } catch (_) {
      return null;
    }
  }

  Future<void> markWatched(MediaItem item) async {
    await _box.put(
      '$_watched${item.id}',
      jsonEncode({'item': item.toJson(), 'watchedAt': DateTime.now().toIso8601String()}),
    );
    notifyListeners();
  }

  Future<void> markUnwatched(String mediaId) async {
    await _box.delete('$_watched$mediaId');
    notifyListeners();
  }

  List<MediaItem> recentlyWatched({int limit = 20}) {
    final entries = <(DateTime, MediaItem)>[];
    for (final key in _box.keys.map((k) => k.toString())) {
      if (!key.startsWith(_watched)) continue;
      final raw = _box.get(key);
      if (raw == null) continue;
      try {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        final ts = DateTime.tryParse(m['watchedAt'] as String? ?? '');
        final item = MediaItem.fromJson(m['item'] as Map<String, dynamic>);
        if (ts != null) entries.add((ts, item));
      } catch (_) {
        // ignore corrupt entries
      }
    }
    entries.sort((a, b) => b.$1.compareTo(a.$1));
    return entries.take(limit).map((e) => e.$2).toList();
  }

  // ---- Continue watching ---------------------------------------------------

  Future<void> saveProgress(ContinueWatchingEntry entry) async {
    await _box.put('$_continue${entry.mediaId}', jsonEncode(entry.toJson()));
    notifyListeners();
  }

  ContinueWatchingEntry? continueEntry(String mediaId) {
    final raw = _box.get('$_continue$mediaId');
    if (raw == null) return null;
    try {
      return ContinueWatchingEntry.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> removeProgress(String mediaId) async {
    await _box.delete('$_continue$mediaId');
    notifyListeners();
  }

  List<ContinueWatchingEntry> continueWatching({int limit = 20}) {
    final entries = <ContinueWatchingEntry>[];
    for (final key in _box.keys.map((k) => k.toString())) {
      if (!key.startsWith(_continue)) continue;
      final raw = _box.get(key);
      if (raw == null) continue;
      try {
        entries.add(ContinueWatchingEntry.fromJson(jsonDecode(raw) as Map<String, dynamic>));
      } catch (_) {
        // ignore corrupt entries
      }
    }
    entries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return entries.take(limit).toList();
  }

  // ---- Helpers -------------------------------------------------------------

  List<MediaItem> _sorted(String prefix) {
    final entries = <(DateTime, MediaItem)>[];
    for (final key in _box.keys.map((k) => k.toString())) {
      if (!key.startsWith(prefix)) continue;
      final raw = _box.get(key);
      if (raw == null) continue;
      try {
        final entry = LibraryEntry.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        entries.add((entry.addedAt, entry.item));
      } catch (_) {
        // ignore corrupt entries
      }
    }
    entries.sort((a, b) => b.$1.compareTo(a.$1));
    return entries.map((e) => e.$2).toList();
  }

  Future<void> clear() async {
    await _box.clear();
    notifyListeners();
  }
}
