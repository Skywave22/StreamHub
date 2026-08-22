import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../core/models/media_source.dart';

class PlaybackTrack {
  const PlaybackTrack({required this.id, required this.title, required this.kind, this.language});
  final String id;
  final String title;
  final String kind; // audio | subtitle | video
  final String? language;
}

/// Abstraction over the underlying media pipeline so the app can swap
/// implementations per platform and tests can use a no-op engine.
abstract class PlaybackEngine {
  Future<void> open(MediaSource source, {Duration? startAt});

  Future<void> play();

  Future<void> pause();

  Future<void> seek(Duration position);

  Future<void> setVolume(double volume);

  Future<void> setRate(double rate);

  Future<void> setSubtitleTrack(String? trackId);

  Future<void> setAudioTrack(String? trackId);

  List<PlaybackTrack> get subtitleTracks;

  List<PlaybackTrack> get audioTracks;

  Future<void> dispose();

  Stream<Duration> get positionStream;
  Stream<Duration> get durationStream;
  Stream<bool> get playingStream;
  Stream<bool> get bufferingStream;
  Stream<String> get errorStream;
  Stream<bool> get completedStream;

  VideoController? get videoController => null;
}

/// media_kit based engine (libmpv on desktop, bundled native libs on Android).
class MediaKitPlaybackEngine implements PlaybackEngine {
  MediaKitPlaybackEngine() {
    _player = Player();
    _controller = VideoController(_player);
  }

  late final Player _player;
  late final VideoController _controller;

  @override
  VideoController get videoController => _controller;

  @override
  Future<void> open(MediaSource source, {Duration? startAt}) async {
    await _player.open(
      Media(source.url, httpHeaders: source.headers),
      play: false,
    );
    if (startAt != null && startAt > Duration.zero) {
      await _player.seek(startAt);
    }
    await _player.play();
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume.clamp(0.0, 100.0));

  @override
  Future<void> setRate(double rate) => _player.setRate(rate);

  @override
  List<PlaybackTrack> get subtitleTracks => _player.state.tracks.subtitle
      .map((t) => PlaybackTrack(id: t.id, title: t.title ?? 'Subtitle', kind: 'subtitle', language: t.language))
      .toList();

  @override
  List<PlaybackTrack> get audioTracks => _player.state.tracks.audio
      .map((t) => PlaybackTrack(id: t.id, title: t.title ?? 'Audio', kind: 'audio', language: t.language))
      .toList();

  @override
  Future<void> setSubtitleTrack(String? trackId) async {
    if (trackId == null) {
      await _player.setSubtitleTrack(SubtitleTrack.no());
      return;
    }
    for (final t in _player.state.tracks.subtitle) {
      if (t.id == trackId) {
        await _player.setSubtitleTrack(t);
        return;
      }
    }
  }

  @override
  Future<void> setAudioTrack(String? trackId) async {
    if (trackId == null) {
      await _player.setAudioTrack(AudioTrack.no());
      return;
    }
    for (final t in _player.state.tracks.audio) {
      if (t.id == trackId) {
        await _player.setAudioTrack(t);
        return;
      }
    }
  }

  @override
  Stream<Duration> get positionStream => _player.stream.position;

  @override
  Stream<Duration> get durationStream => _player.stream.duration;

  @override
  Stream<bool> get playingStream => _player.stream.playing;

  @override
  Stream<bool> get bufferingStream => _player.stream.buffering;

  @override
  Stream<String> get errorStream => _player.stream.error;

  @override
  Stream<bool> get completedStream => _player.stream.completed;

  @override
  Future<void> dispose() async => _player.dispose();
}

/// No-op engine for tests and previews.
class NoopPlaybackEngine implements PlaybackEngine {
  @override
  List<PlaybackTrack> get audioTracks => const [];

  @override
  List<PlaybackTrack> get subtitleTracks => const [];

  @override
  Future<void> setAudioTrack(String? trackId) async {}

  @override
  Future<void> setSubtitleTrack(String? trackId) async {}

  @override
  VideoController? get videoController => null;

  @override
  Stream<bool> get bufferingStream => const Stream.empty();

  @override
  Stream<bool> get completedStream => const Stream.empty();

  @override
  Future<void> dispose() async {}

  @override
  Stream<Duration> get durationStream => const Stream.empty();

  @override
  Stream<String> get errorStream => const Stream.empty();

  @override
  Future<void> open(MediaSource source, {Duration? startAt}) async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> play() async {}

  @override
  Stream<Duration> get positionStream => const Stream.empty();

  @override
  Stream<bool> get playingStream => const Stream.empty();

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setRate(double rate) async {}

  @override
  Future<void> setVolume(double volume) async {}
}
