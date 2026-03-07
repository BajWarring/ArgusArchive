import 'dart:async';
import 'package:flutter/services.dart';

// ─── Track Model ──────────────────────────────────────────────────────────────
class VideoTrack {
  final String id;
  final String language;
  final String label;
  final bool isSelected;
  final int groupIndex;
  final int trackIndex;

  const VideoTrack({
    required this.id,
    required this.language,
    required this.label,
    required this.isSelected,
    required this.groupIndex,
    required this.trackIndex,
  });

  factory VideoTrack.fromMap(Map<dynamic, dynamic> map) => VideoTrack(
        id: map['id']?.toString() ?? '',
        language: map['language']?.toString() ?? 'Unknown',
        label: map['label']?.toString() ?? 'Track',
        isSelected: map['selected'] as bool? ?? false,
        groupIndex: map['groupIndex'] as int? ?? 0,
        trackIndex: map['trackIndex'] as int? ?? 0,
      );

  VideoTrack copyWith({bool? isSelected}) => VideoTrack(
        id: id,
        language: language,
        label: label,
        isSelected: isSelected ?? this.isSelected,
        groupIndex: groupIndex,
        trackIndex: trackIndex,
      );
}

// ─── Playback State ───────────────────────────────────────────────────────────
class VideoPlaybackState {
  final Duration position;
  final Duration duration;
  final Duration buffered;
  final bool isPlaying;
  final String status; // idle | buffering | ready | ended | error
  final List<VideoTrack> audioTracks;
  final List<VideoTrack> subtitleTracks;
  final String? errorMessage;

  const VideoPlaybackState({
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.buffered = Duration.zero,
    this.isPlaying = false,
    this.status = 'idle',
    this.audioTracks = const [],
    this.subtitleTracks = const [],
    this.errorMessage,
  });

  bool get isBuffering => status == 'buffering';
  bool get isEnded => status == 'ended';
  bool get hasError => status == 'error';

  double get progress {
    final total = duration.inMilliseconds;
    if (total <= 0) return 0.0;
    return (position.inMilliseconds / total).clamp(0.0, 1.0);
  }

  VideoPlaybackState copyWith({
    Duration? position,
    Duration? duration,
    Duration? buffered,
    bool? isPlaying,
    String? status,
    List<VideoTrack>? audioTracks,
    List<VideoTrack>? subtitleTracks,
    String? errorMessage,
  }) {
    return VideoPlaybackState(
      position: position ?? this.position,
      duration: duration ?? this.duration,
      buffered: buffered ?? this.buffered,
      isPlaying: isPlaying ?? this.isPlaying,
      status: status ?? this.status,
      audioTracks: audioTracks ?? this.audioTracks,
      subtitleTracks: subtitleTracks ?? this.subtitleTracks,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

// ─── Controller ───────────────────────────────────────────────────────────────
class VideoPlayerController {
  final int viewId;

  late final MethodChannel _method;
  late final EventChannel _events;

  VideoPlaybackState _state = const VideoPlaybackState();
  VideoPlaybackState get value => _state;

  final _stateController = StreamController<VideoPlaybackState>.broadcast();
  Stream<VideoPlaybackState> get stateStream => _stateController.stream;

  StreamSubscription? _eventSub;

  VideoPlayerController(this.viewId) {
    _method = MethodChannel('com.app.argusarchive/video_player_$viewId');
    _events = EventChannel('com.app.argusarchive/video_events_$viewId');
    _listenToNativeEvents();
  }

  void _listenToNativeEvents() {
    _eventSub = _events.receiveBroadcastStream().listen(
      (dynamic raw) {
        if (raw == null || _stateController.isClosed) return;
        final map = Map<String, dynamic>.from(raw as Map);

        switch (map['event'] as String?) {
          case 'progress':
            final rawDur = map['duration'] as int? ?? -1;
            final validDur = rawDur > 0 ? Duration(milliseconds: rawDur) : _state.duration;
            _state = _state.copyWith(
              position: Duration(milliseconds: map['position'] as int? ?? 0),
              duration: validDur,
              buffered: Duration(milliseconds: map['buffered'] as int? ?? 0),
            );
            break;

          case 'state':
            _state = _state.copyWith(status: map['state'] as String? ?? 'idle');
            break;

          case 'isPlaying':
            _state = _state.copyWith(isPlaying: map['isPlaying'] as bool? ?? false);
            break;

          case 'tracks':
            final audioRaw = (map['audio'] as List?) ?? [];
            final subRaw = (map['subs'] as List?) ?? [];
            _state = _state.copyWith(
              audioTracks: audioRaw.map((t) => VideoTrack.fromMap(t as Map)).toList(),
              subtitleTracks: subRaw.map((t) => VideoTrack.fromMap(t as Map)).toList(),
            );
            break;

          case 'error':
            _state = _state.copyWith(
              status: 'error',
              errorMessage: map['message'] as String?,
            );
            break;
        }

        if (!_stateController.isClosed) _stateController.add(_state);
      },
      onError: (_) {},
    );
  }

  // ─── Playback Controls ────────────────────────────────────────────────────
  Future<void> play() async {
    try { await _method.invokeMethod('play'); } catch (_) {}
  }

  Future<void> pause() async {
    try { await _method.invokeMethod('pause'); } catch (_) {}
  }

  Future<void> togglePlayPause() async {
    _state.isPlaying ? await pause() : await play();
  }

  Future<void> seekTo(Duration position) async {
    try {
      await _method.invokeMethod('seekTo', {'position': position.inMilliseconds});
    } catch (_) {}
  }

  Future<void> seekBy(Duration delta) async {
    final target = _state.position + delta;
    final clamped = Duration(
      milliseconds: target.inMilliseconds.clamp(0, _state.duration.inMilliseconds),
    );
    await seekTo(clamped);
  }

  // ─── A/V Controls ─────────────────────────────────────────────────────────
  Future<void> setSpeed(double speed) async {
    try { await _method.invokeMethod('setSpeed', {'speed': speed}); } catch (_) {}
  }

  Future<void> setVolume(double volume) async {
    try {
      await _method.invokeMethod('setVolume', {'volume': volume.clamp(0.0, 1.0)});
    } catch (_) {}
  }

  Future<void> setBrightness(double brightness) async {
    try {
      await _method.invokeMethod('setBrightness', {'brightness': brightness.clamp(0.0, 1.0)});
    } catch (_) {}
  }

  // ─── Track Selection ──────────────────────────────────────────────────────
  Future<void> selectTrack(VideoTrack track, bool isAudio) async {
    try {
      await _method.invokeMethod('selectTrack', {
        'groupIndex': track.groupIndex,
        'trackIndex': track.trackIndex,
        'isAudio': isAudio,
      });
    } catch (_) {}
  }

  Future<void> disableSubtitles() async {
    try { await _method.invokeMethod('disableSubtitles'); } catch (_) {}
  }

  Future<void> setSubtitleDelay(int delayMs) async {
    try { await _method.invokeMethod('setSubtitleDelay', {'delayMs': delayMs}); } catch (_) {}
  }

  // ─── Display Controls ─────────────────────────────────────────────────────
  Future<void> setAspectRatio(int mode) async {
    try { await _method.invokeMethod('setAspectRatio', {'mode': mode}); } catch (_) {}
  }

  Future<void> enterPiP() async {
    try { await _method.invokeMethod('enterPiP'); } catch (_) {}
  }

  // ─── Lifecycle ────────────────────────────────────────────────────────────
  void dispose() {
    _eventSub?.cancel();
    if (!_stateController.isClosed) _stateController.close();
  }
}
