import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamhub/core/models/continue_watching_entry.dart';
import 'package:streamhub/core/models/media_item.dart';
import 'package:streamhub/core/models/media_type.dart';
import 'package:streamhub/core/storage/library_store.dart';
import 'package:streamhub/core/storage/settings_store.dart';

import 'test_helpers.dart';

MediaItem _item(String id, String title, {MediaType type = MediaType.movie}) =>
    MediaItem(id: id, type: type, title: title);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LibraryStore', () {
    test('toggles favorites and keeps ordering', () async {
      final store = LibraryStore(await openBox());
      final a = _item('tmdb:1', 'A');
      final b = _item('tmdb:2', 'B');

      await store.toggleFavorite(a);
      expect(store.isFavorite('tmdb:1'), isTrue);
      expect(store.favorites().length, 1);

      await store.toggleFavorite(b);
      // Most recently added first.
      expect(store.favorites().first.id, 'tmdb:2');

      await store.toggleFavorite(a);
      expect(store.isFavorite('tmdb:1'), isFalse);
    });

    test('tracks watched history', () async {
      final store = LibraryStore(await openBox());
      await store.markWatched(_item('tmdb:1', 'A'));
      await store.markWatched(_item('tmdb:2', 'B'));
      expect(store.isWatched('tmdb:1'), isTrue);
      expect(store.recentlyWatched().first.id, 'tmdb:2');
      await store.markUnwatched('tmdb:2');
      expect(store.isWatched('tmdb:2'), isFalse);
    });

    test('persists and sorts continue-watching entries', () async {
      final store = LibraryStore(await openBox());
      await store.saveProgress(ContinueWatchingEntry(
        mediaId: 'tmdb:1',
        type: MediaType.movie,
        title: 'A',
        positionSeconds: 60,
        durationSeconds: 120,
        updatedAt: DateTime(2026, 1, 1),
      ));
      await store.saveProgress(ContinueWatchingEntry(
        mediaId: 'tmdb:2',
        type: MediaType.tv,
        title: 'B',
        positionSeconds: 30,
        durationSeconds: 60,
        updatedAt: DateTime(2026, 1, 2),
      ));
      final entries = store.continueWatching();
      expect(entries.length, 2);
      expect(entries.first.mediaId, 'tmdb:2');
      expect(entries.first.progress, 0.5);
      await store.removeProgress('tmdb:2');
      expect(store.continueWatching().length, 1);
    });
  });

  group('SettingsStore', () {
    test('defaults and persistence with change notifications', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsStore(prefs);

      var notifications = 0;
      settings.addListener(() => notifications++);

      expect(settings.themePreference, ThemePreference.system);
      expect(settings.autoplayNext, isTrue);
      expect(settings.playbackSpeed, 1.0);
      expect(settings.defaultQuality, 'Auto');

      settings.themePreference = ThemePreference.dark;
      settings.autoplayNext = false;
      settings.playbackSpeed = 1.5;

      expect(settings.themePreference, ThemePreference.dark);
      expect(settings.autoplayNext, isFalse);
      expect(settings.playbackSpeed, 1.5);
      expect(notifications, 3);

      // Reload from a fresh instance backed by the same prefs.
      final again = SettingsStore(prefs);
      expect(again.themePreference, ThemePreference.dark);
      expect(again.playbackSpeed, 1.5);
    });
  });
}
