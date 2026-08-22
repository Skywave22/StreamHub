import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/errors/app_exception.dart';
import '../../core/models/episode.dart';
import '../../core/models/media_source.dart';
import '../../core/providers.dart';
import '../../services/playback_controller.dart';
import '../../services/playback_engine.dart';
import '../router/app_router.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key, required this.request});

  final PlayerRequest request;

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  final List<StreamSubscription<dynamic>> _subs = [];
  final GlobalKey<VideoState> _videoKey = GlobalKey<VideoState>();
  bool _controlsVisible = true;
  Timer? _hideTimer;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  PlaybackController get _controller => ref.read(playbackControllerProvider);
  PlaybackEngine get _engine => ref.read(playbackEngineProvider);

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _wire();
    _start();
  }

  Future<void> _start() async {
    final request = widget.request;
    await _controller.load(
      item: request.item,
      source: request.source,
      season: request.seasonNumber,
      episode: request.episodeNumber,
      episodeName: request.episodeName,
      upcoming: request.upcoming,
    );
    await _engine.open(request.source, startAt: _controller.position);
  }

  void _wire() {
    _controller.onRequestNextEpisode = _playEpisode;
    _controller.onRequestPreviousEpisode = _playPrevious;
    _subs.add(_engine.positionStream.listen((p) {
      if (mounted) setState(() => _position = p);
    }));
    _subs.add(_engine.durationStream.listen((d) {
      if (mounted) setState(() => _duration = d);
      _controller.onReady(d);
    }));
    _subs.add(_engine.playingStream.listen((playing) {
      if (playing) {
        _controller.onPlaying();
      } else {
        // pause vs buffering resolved via buffering stream
      }
    }));
    _subs.add(_engine.bufferingStream.listen((b) {
      if (b) _controller.onBuffering();
    }));
    _subs.add(_engine.errorStream.listen((e) => _controller.onError(e)));
    _subs.add(_engine.completedStream.listen((c) {
      if (c) _controller.onEnded();
    }));
  }

  Future<void> _playEpisode(Episode ep) async {
    final request = widget.request;
    final resolver = ref.read(sourceResolverProvider);
    final sources = await resolver.gather(request.item, season: ep.seasonNumber, episode: ep.episodeNumber);
    if (!mounted) return;
    if (sources.isEmpty) {
      _snack('No source for ${ep.name}.');
      return;
    }
    final picked = resolver.pick(sources, ref.read(settingsStoreProvider).sourceSelectionMode) ?? sources.first;
    try {
      final provider = ref.read(pluginManagerProvider).provider(picked.providerId);
      final verified = provider != null ? await provider.resolveSource(picked) : picked;
      await _controller.load(
        item: request.item,
        source: verified,
        season: ep.seasonNumber,
        episode: ep.episodeNumber,
        episodeName: ep.name,
        upcoming: request.episodes.where((x) => x.episodeNumber > ep.episodeNumber).toList(),
        resume: false,
      );
      await _engine.open(verified);
    } catch (e) {
      if (mounted) _snack(e is AppException ? e.message : 'Could not play ${ep.name}.');
    }
  }

  Future<void> _playPrevious() async {
    final request = widget.request;
    final idx = request.currentEpisodeIndex;
    if (idx <= 0 || request.episodes.isEmpty) {
      _snack('No previous episode.');
      return;
    }
    await _playEpisode(request.episodes[idx - 1]);
  }

  Future<void> _switchSource(MediaSource source) async {
    try {
      await _engine.open(source, startAt: _position);
      await _controller.load(
        item: widget.request.item,
        source: source,
        season: widget.request.seasonNumber,
        episode: widget.request.episodeNumber,
        episodeName: widget.request.episodeName,
        upcoming: widget.request.upcoming,
        resume: false,
      );
    } catch (e) {
      if (mounted) _snack(e is AppException ? e.message : 'Could not switch source.');
    }
  }

  void _snack(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _controller.status == PlaybackStatus.playing) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _hideTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _controller.saveNow();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(playbackControllerProvider);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: _engine.videoController != null
                ? Video(
                    key: _videoKey,
                    controller: _engine.videoController!,
                    controls: (state) => const SizedBox.shrink(),
                    fit: BoxFit.contain,
                  )
                : const SizedBox.shrink(),
          ),
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleControls,
            ),
          ),
          if (_controlsVisible) _buildTopBar(controller),
          if (_controlsVisible) _buildCenter(controller),
          if (_controlsVisible) _buildBottomBar(controller),
        ],
      ),
    );
  }

  Widget _buildTopBar(PlaybackController c) {
    final episodeLabel = c.episodeName != null ? ' · ${c.episodeName}' : '';
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 4),
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black87, Colors.transparent]),
        ),
        child: Row(
          children: [
            IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => context.pop()),
            Expanded(
              child: Text(
                '${c.item?.title ?? ''}$episodeLabel',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenter(PlaybackController c) {
    final children = <Widget>[];
    switch (c.status) {
      case PlaybackStatus.loading:
      case PlaybackStatus.buffering:
        children.add(const CircularProgressIndicator(color: Colors.white));
      case PlaybackStatus.playing:
      case PlaybackStatus.paused:
        children.add(IconButton(
          iconSize: 72,
          icon: Icon(c.status == PlaybackStatus.playing ? Icons.pause_circle_filled : Icons.play_circle_filled, color: Colors.white),
          onPressed: _togglePlay,
        ));
      case PlaybackStatus.ended:
        children.add(Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (c.autoplayActive) ...[
              const Text('Next episode in', style: TextStyle(color: Colors.white, fontSize: 16)),
              const SizedBox(height: 4),
              Text('${c.countdown}', style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              TextButton(onPressed: c.cancelAutoplay, child: const Text('Cancel')),
            ] else ...[
              IconButton(iconSize: 72, icon: const Icon(Icons.replay_circle_filled, color: Colors.white), onPressed: _retry),
              const Text('Ended', style: TextStyle(color: Colors.white70)),
            ],
          ],
        ));
      case PlaybackStatus.error:
        children.add(Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 8),
            const Text('Playback failed.', style: TextStyle(color: Colors.white)),
            const SizedBox(height: 8),
            FilledButton(onPressed: _retry, child: const Text('Retry')),
          ],
        ));
      case PlaybackStatus.idle:
        break;
    }
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: children));
  }

  Future<void> _togglePlay() async {
    final c = _controller;
    if (c.status == PlaybackStatus.playing) {
      await _engine.pause();
      c.onPaused();
    } else {
      await _engine.play();
      c.onPlaying();
    }
    _scheduleHide();
  }

  Future<void> _retry() async {
    await _engine.open(_controller.source!, startAt: _position);
  }

  Widget _buildBottomBar(PlaybackController c) {
    final positionText = _fmt(_position);
    final durationText = _fmt(_duration);
    final speedLabel = c.speed == 1.0 ? '1×' : '${c.speed}×';
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black87, Colors.transparent]),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(positionText, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                Expanded(
                  child: Slider(
                    value: _duration.inMilliseconds == 0 ? 0 : (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0),
                    onChanged: (v) {
                      final target = Duration(milliseconds: (_duration.inMilliseconds * v).round());
                      setState(() => _position = target);
                      _engine.seek(target);
                      _controller.seek(target);
                    },
                  ),
                ),
                Text(durationText, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
            Row(
              children: [
                IconButton(icon: const Icon(Icons.play_arrow, color: Colors.white), onPressed: _togglePlay),
                _volumeControl(c),
                const Spacer(),
                if (widget.request.sources.isNotEmpty)
                  _menuButton<MediaSource>(
                    icon: const Icon(Icons.hd_outlined, color: Colors.white),
                    items: {for (final s in widget.request.sources) s: s.name},
                    onSelected: (s) => _switchSource(s),
                  ),
                _menuButton<double>(
                  icon: Text(speedLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  items: {0.5: '0.5×', 0.75: '0.75×', 1.0: '1×', 1.25: '1.25×', 1.5: '1.5×', 2.0: '2×'},
                  onSelected: (v) {
                    _controller.setSpeed(v);
                    _engine.setRate(v);
                  },
                ),
                if (_engine.subtitleTracks.isNotEmpty)
                  _menuButton<String?>(
                    icon: const Icon(Icons.subtitles_outlined, color: Colors.white),
                    items: {null: 'Off', for (final t in _engine.subtitleTracks) t.id: t.title},
                    onSelected: (id) => _engine.setSubtitleTrack(id),
                  ),
                if (_engine.audioTracks.isNotEmpty)
                  _menuButton<String?>(
                    icon: const Icon(Icons.audiotrack_outlined, color: Colors.white),
                    items: {null: 'Default', for (final t in _engine.audioTracks) t.id: t.title},
                    onSelected: (id) => _engine.setAudioTrack(id),
                  ),
                IconButton(
                  icon: const Icon(Icons.fullscreen, color: Colors.white),
                  onPressed: () => _videoKey.currentState?.enterFullscreen(),
                ),
                if (c.hasUpcoming)
                  IconButton(icon: const Icon(Icons.skip_next, color: Colors.white), onPressed: c.requestNextEpisode),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _volumeControl(PlaybackController c) {
    return SizedBox(
      width: 120,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(c.muted ? Icons.volume_off : Icons.volume_up, color: Colors.white),
            onPressed: () {
              c.toggleMute();
              _engine.setVolume(c.effectiveVolume * 100);
            },
          ),
          Expanded(
            child: Slider(
              value: c.muted ? 0 : c.volume,
              onChanged: (v) {
                c.setVolume(v);
                _engine.setVolume(v * 100);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuButton<T>({required Widget icon, required Map<T, String> items, required ValueChanged<T> onSelected}) {
    return PopupMenuButton<T>(
      icon: icon,
      color: const Color(0xFF1E1E28),
      onSelected: onSelected,
      itemBuilder: (context) => items.entries
          .map((e) => PopupMenuItem<T>(value: e.key, child: Text(e.value, style: const TextStyle(color: Colors.white))))
          .toList(),
    );
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}
