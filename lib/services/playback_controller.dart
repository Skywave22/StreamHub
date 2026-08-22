import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/models/continue_watching_entry.dart';
import '../core/models/episode.dart';
import '../core/models/media_item.dart';
import '../core/models/media_source.dart';
import '../core/storage/library_store.dart';
import '../core/storage/settings_store.dart';

enum PlaybackStatus { idle, loading, playing, paused, buffering, ended, error }

/// Pure-Dart playback state machine: position, duration, speed, volume,
/// resume, autoplay-next countdown and progress persistence. The actual media
/// pipeline is injected via [PlaybackEngine], so this controller is fully
/// unit-testable without a real player.
class PlaybackController extends ChangeNotifier {
  PlaybackController({required LibraryStore libraryStore, required SettingsStore settings})
      : _library = libraryStore,
        _settings = settings;

  final LibraryStore _library;
  final SettingsStore _settings;

  PlaybackStatus _status = PlaybackStatus.idle;
  MediaItem? _item;
  MediaSource? _source;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _speed = 1.0;
  double _volume = 1.0;
  bool _muted = false;
  int? _seasonNumber;
  int? _episodeNumber;
  String? _episodeName;
  List<Episode> _upcoming = const [];
  String? _errorMessage;
  bool _autoplayActive = false;
  int _countdown = 5;
  Timer? _countdownTimer;
  Timer? _saveTimer;

  PlaybackStatus get status => _status;
  MediaItem? get item => _item;
  MediaSource? get source => _source;
  Duration get position => _position;
  Duration get duration => _duration;
  double get speed => _speed;
  double get volume => _volume;
  bool get muted => _muted;
  int? get seasonNumber => _seasonNumber;
  int? get episodeNumber => _episodeNumber;
  String? get episodeName => _episodeName;
  String? get errorMessage => _errorMessage;
  bool get autoplayActive => _autoplayActive;
  int get countdown => _countdown;
  bool get hasUpcoming => _upcoming.isNotEmpty;

  double get progress => _duration.inMilliseconds <= 0
      ? 0
      : (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0);

  /// Called when the user confirms autoplay (the UI resolves the next source).
  void Function(Episode next)? onRequestNextEpisode;
  void Function()? onRequestPreviousEpisode;

  /// Loads a title for playback, resuming automatically when enabled.
  Future<void> load({
    required MediaItem item,
    required MediaSource source,
    int? season,
    int? episode,
    String? episodeName,
    List<Episode> upcoming = const [],
    bool resume = true,
  }) async {
    _cancelTimers();
    _item = item;
    _source = source;
    _seasonNumber = season;
    _episodeNumber = episode;
    _episodeName = episodeName;
    _upcoming = upcoming;
    _status = PlaybackStatus.loading;
    _duration = Duration.zero;
    _position = Duration.zero;
    _errorMessage = null;
    _speed = _settings.playbackSpeed;
    notifyListeners();

    if (resume && _settings.resumePlayback) {
      final entry = _library.continueEntry(item.id);
      if (entry != null && entry.positionSeconds > 0) {
        _position = Duration(seconds: entry.positionSeconds);
      }
    }
  }

  // ---- Events from the engine ---------------------------------------------

  void onReady(Duration duration) {
    _duration = duration;
    _status = PlaybackStatus.playing;
    _startSaving();
    notifyListeners();
  }

  void onPosition(Duration position) {
    _position = position;
    // Avoid notifying on every tick — the UI binds its own stream.
  }

  void onPlaying() {
    if (_status == PlaybackStatus.playing) return;
    _status = PlaybackStatus.playing;
    notifyListeners();
  }

  void onPaused() {
    _status = PlaybackStatus.paused;
    _saveNow();
    notifyListeners();
  }

  void onBuffering() {
    if (_status != PlaybackStatus.playing) return;
    _status = PlaybackStatus.buffering;
    notifyListeners();
  }

  void onEnded() {
    _status = PlaybackStatus.ended;
    _saveNow();
    notifyListeners();
    _startAutoplayCountdown();
  }

  void onError(String message) {
    _status = PlaybackStatus.error;
    _errorMessage = message;
    notifyListeners();
  }

  // ---- User controls -------------------------------------------------------

  void togglePlay() {
    if (_status == PlaybackStatus.playing) {
      onPaused();
    } else if (_status == PlaybackStatus.paused || _status == PlaybackStatus.ended) {
      onPlaying();
    }
  }

  void seek(Duration position) {
    _position = position;
    notifyListeners();
  }

  void setSpeed(double speed) {
    _speed = speed.clamp(0.25, 4.0);
    notifyListeners();
  }

  void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
    if (_volume > 0) _muted = false;
    notifyListeners();
  }

  void toggleMute() {
    _muted = !_muted;
    notifyListeners();
  }

  double get effectiveVolume => _muted ? 0 : _volume;

  // ---- Autoplay next episode ----------------------------------------------

  void _startAutoplayCountdown() {
    if (!_settings.autoplayNext || _upcoming.isEmpty) return;
    _autoplayActive = true;
    _countdown = 5;
    notifyListeners();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      _countdown--;
      if (_countdown <= 0) {
        t.cancel();
        _autoplayActive = false;
        final next = _upcoming.first;
        notifyListeners();
        onRequestNextEpisode?.call(next);
      } else {
        notifyListeners();
      }
    });
  }

  void cancelAutoplay() {
    _countdownTimer?.cancel();
    _autoplayActive = false;
    notifyListeners();
  }

  void requestNextEpisode() {
    cancelAutoplay();
    if (_upcoming.isEmpty) return;
    onRequestNextEpisode?.call(_upcoming.first);
  }

  void requestPreviousEpisode() {
    cancelAutoplay();
    onRequestPreviousEpisode?.call();
  }

  // ---- Persistence ---------------------------------------------------------

  void _startSaving() {
    _saveTimer?.cancel();
    _saveTimer = Timer.periodic(const Duration(seconds: 10), (_) => _saveNow());
  }

  void _saveNow() {
    final item = _item;
    if (item == null || _duration.inSeconds <= 0) return;
    _library.saveProgress(
      ContinueWatchingEntry(
        mediaId: item.id,
        type: item.type,
        title: item.title,
        posterUrl: item.posterUrl,
        seasonNumber: _seasonNumber,
        episodeNumber: _episodeNumber,
        episodeName: _episodeName,
        positionSeconds: _position.inSeconds,
        durationSeconds: _duration.inSeconds,
        updatedAt: DateTime.now(),
      ),
    );
  }

  void saveNow() => _saveNow();

  void _cancelTimers() {
    _countdownTimer?.cancel();
    _saveTimer?.cancel();
    _autoplayActive = false;
  }

  void reset() {
    _cancelTimers();
    _status = PlaybackStatus.idle;
    _item = null;
    _source = null;
    _position = Duration.zero;
    _duration = Duration.zero;
    notifyListeners();
  }

  @override
  void dispose() {
    _cancelTimers();
    super.dispose();
  }
}
