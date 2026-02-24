import 'dart:async';
import 'package:flutter/services.dart';

class MediaTrack {
  final String id;
  final String language;
  final String label;
  final bool isSelected;
  final int groupIndex;
  final int trackIndex;

  MediaTrack({required this.id, required this.language, required this.label, required this.isSelected, required this.groupIndex, required this.trackIndex});
  
  factory MediaTrack.fromMap(Map map) => MediaTrack(
    id: map['id'], language: map['language'], label: map['label'], 
    isSelected: map['selected'], groupIndex: map['groupIndex'], trackIndex: map['trackIndex']
  );
}

class VideoPlaybackState {
  final String status; // idle, buffering, ready, ended
  final Duration position;
  final Duration duration;
  final Duration buffered;
  final bool isPlaying;
  final List<MediaTrack> audioTracks;
  final List<MediaTrack> subtitleTracks;
  final String? error;

  VideoPlaybackState({
    this.status = 'idle', this.position = Duration.zero, this.duration = Duration.zero, 
    this.buffered = Duration.zero, this.isPlaying = false, 
    this.audioTracks = const [], this.subtitleTracks = const [], this.error,
  });

  VideoPlaybackState copyWith({
    String? status, Duration? position, Duration? duration, Duration? buffered, 
    bool? isPlaying, List<MediaTrack>? audioTracks, List<MediaTrack>? subtitleTracks, String? error
  }) {
    return VideoPlaybackState(
      status: status ?? this.status, position: position ?? this.position,
      duration: duration ?? this.duration, buffered: buffered ?? this.buffered,
      isPlaying: isPlaying ?? this.isPlaying, audioTracks: audioTracks ?? this.audioTracks,
      subtitleTracks: subtitleTracks ?? this.subtitleTracks, error: error ?? this.error
    );
  }
}

class VideoPlayerController {
  final int viewId;
  late final MethodChannel _methodChannel;
  late final EventChannel _eventChannel;
  
  final _stateController = StreamController<VideoPlaybackState>.broadcast();
  Stream<VideoPlaybackState> get stateStream => _stateController.stream;

  VideoPlaybackState _state = VideoPlaybackState();
  VideoPlaybackState get value => _state;

  VideoPlayerController(this.viewId) {
    _methodChannel = MethodChannel('com.app.argusarchive/video_player_$viewId');
    _eventChannel = EventChannel('com.app.argusarchive/video_events_$viewId');
    
    _eventChannel.receiveBroadcastStream().listen((event) {
      final map = Map<String, dynamic>.from(event);
      switch (map['event']) {
        case 'progress':
          _state = _state.copyWith(
            position: Duration(milliseconds: map['position']),
            duration: Duration(milliseconds: map['duration']),
            buffered: Duration(milliseconds: map['buffered']),
          );
          break;
        case 'state': _state = _state.copyWith(status: map['state']); break;
        case 'isPlaying': _state = _state.copyWith(isPlaying: map['isPlaying']); break;
        case 'tracks':
          _state = _state.copyWith(
            audioTracks: (map['audio'] as List).map((e) => MediaTrack.fromMap(e)).toList(),
            subtitleTracks: (map['subs'] as List).map((e) => MediaTrack.fromMap(e)).toList(),
          );
          break;
        case 'error': _state = _state.copyWith(error: map['message']); break;
      }
      _stateController.add(_state);
    });
  }
 
  Future<void> setAspectRatio(int mode) => _methodChannel.invokeMethod('setAspectRatio', {'mode': mode});
  Future<void> play() => _methodChannel.invokeMethod('play');
  Future<void> pause() => _methodChannel.invokeMethod('pause');
  Future<void> seekTo(Duration pos) => _methodChannel.invokeMethod('seekTo', {'position': pos.inMilliseconds});
  Future<void> setSpeed(double speed) => _methodChannel.invokeMethod('setSpeed', {'speed': speed});
  Future<void> enterPiP() => _methodChannel.invokeMethod('enterPiP');
  Future<void> setBrightness(double b) => _methodChannel.invokeMethod('setBrightness', {'brightness': b});
  Future<void> setVolume(double v) => _methodChannel.invokeMethod('setVolume', {'volume': v});
  
  Future<void> selectTrack(MediaTrack track, bool isAudio) {
    return _methodChannel.invokeMethod('selectTrack', {'groupIndex': track.groupIndex, 'trackIndex': track.trackIndex, 'isAudio': isAudio});
  }
  Future<void> disableSubtitles() => _methodChannel.invokeMethod('disableSubtitles');

  void dispose() { _stateController.close(); }
}
