import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamhub/core/models/continue_watching_entry.dart';
import 'package:streamhub/core/models/episode.dart';
import 'package:streamhub/core/models/media_item.dart';
import 'package:streamhub/core/models/media_source.dart';
import 'package:streamhub/core/models/media_type.dart';
import 'package:streamhub/core/storage/library_store.dart';
import 'package:streamhub/core/storage/settings_store.dart';
import 'package:streamhub/services/playback_controller.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const item = MediaItem(id: 'tmdb:550', type: MediaType.movie, title: 'Fight Club');
  const source = MediaSource(id: 's1', providerId: 'skystream', name: 'HD', url: 'https://x/v.mp4');

  Future<PlaybackController> makeController() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    return PlaybackController(libraryStore: LibraryStore(await openBox()), settings: SettingsStore(prefs));
  }

  test('resumes from continue watching when enabled', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final lib = LibraryStore(await openBox());
    await lib.saveProgress(ContinueWatchingEntry(
      mediaId: 'tmdb:550',
      type: MediaType.movie,
      title: 'Fight Club',
      positionSeconds: 120,
      durationSeconds: 3600,
      updatedAt: DateTime.now(),
    ));
    final c = PlaybackController(libraryStore: lib, settings: SettingsStore(prefs));

    await c.load(item: item, source: source);
    expect(c.position, const Duration(seconds: 120));

    await c.load(item: item, source: source, resume: false);
    expect(c.position, Duration.zero);
  });

  test('onReady transitions to playing and records duration', () async {
    final c = await makeController();
    await c.load(item: item, source: source);
    expect(c.status, PlaybackStatus.loading);
    c.onReady(const Duration(seconds: 3600));
    expect(c.status, PlaybackStatus.playing);
    expect(c.duration, const Duration(seconds: 3600));
  });

  test('togglePlay toggles between paused and playing', () async {
    final c = await makeController();
    await c.load(item: item, source: source);
    c.onReady(const Duration(minutes: 10));
    c.togglePlay();
    expect(c.status, PlaybackStatus.paused);
    c.togglePlay();
    expect(c.status, PlaybackStatus.playing);
  });

  test('autoplay countdown triggers the next episode after 5 seconds', () async {
    final c = await makeController();
    Episode? requested;
    c.onRequestNextEpisode = (next) => requested = next;
    const e1 = Episode(seasonNumber: 1, episodeNumber: 2, name: 'E2');
    await c.load(item: item, source: source, upcoming: [e1]);

    fakeAsync((async) {
      c.onEnded();
      expect(c.autoplayActive, isTrue);
      async.elapse(const Duration(seconds: 5));
    });
    expect(requested, isNotNull);
    expect(requested!.episodeNumber, 2);
  });

  test('autoplay is skipped when disabled', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsStore(prefs);
    settings.autoplayNext = false;
    final c = PlaybackController(libraryStore: LibraryStore(await openBox()), settings: settings);
    await c.load(
      item: item,
      source: source,
      upcoming: const [Episode(seasonNumber: 1, episodeNumber: 2, name: 'E2')],
    );
    c.onEnded();
    expect(c.autoplayActive, isFalse);
  });

  test('saveNow persists progress', () async {
    final lib = LibraryStore(await openBox());
    SharedPreferences.setMockInitialValues({});
    final c = PlaybackController(libraryStore: lib, settings: SettingsStore(await SharedPreferences.getInstance()));
    await c.load(item: item, source: source, season: 1, episode: 3);
    c.onReady(const Duration(seconds: 100));
    c.onPosition(const Duration(seconds: 40));
    c.saveNow();
    final entry = lib.continueEntry('tmdb:550');
    expect(entry, isNotNull);
    expect(entry!.positionSeconds, 40);
    expect(entry.episodeNumber, 3);
  });
}
