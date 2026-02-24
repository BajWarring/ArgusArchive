import 'dart:async';
import 'package:flutter/services.dart';

class VideoPlaybackState {
  final Duration position;
  final Duration duration;
  final Duration buffered;
  final bool isPlaying;

  VideoPlaybackState({
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.buffered = Duration.zero,
    this.isPlaying = false,
  });
}

class VideoPlayerController {
  final int viewId;
  late final MethodChannel _methodChannel;
  late final EventChannel _eventChannel;
  
  final _stateController = StreamController<VideoPlaybackState>.broadcast();
  Stream<VideoPlaybackState> get stateStream => _stateController.stream;

  VideoPlaybackState _currentState = VideoPlaybackState();

  VideoPlayerController(this.viewId) {
    _methodChannel = MethodChannel('com.app.argusarchive/video_player_$viewId');
    _eventChannel = EventChannel('com.app.argusarchive/video_events_$viewId');
    
    _eventChannel.receiveBroadcastStream().listen((event) {
      final map = Map<String, dynamic>.from(event);
      if (map['event'] == 'progress') {
        _currentState = VideoPlaybackState(
          position: Duration(milliseconds: map['position'] ?? 0),
          duration: Duration(milliseconds: map['duration'] ?? 0),
          buffered: Duration(milliseconds: map['buffered'] ?? 0),
          isPlaying: _currentState.isPlaying,
        );
        _stateController.add(_currentState);
      } else if (map['event'] == 'isPlaying') {
        _currentState = VideoPlaybackState(
          position: _currentState.position,
          duration: _currentState.duration,
          buffered: _currentState.buffered,
          isPlaying: map['isPlaying'] == true,
        );
        _stateController.add(_currentState);
      }
    });
  }

  Future<void> play() => _methodChannel.invokeMethod('play');
  Future<void> pause() => _methodChannel.invokeMethod('pause');
  Future<void> seekTo(Duration position) => _methodChannel.invokeMethod('seekTo', {'position': position.inMilliseconds});
  Future<void> setSpeed(double speed) => _methodChannel.invokeMethod('setSpeed', {'speed': speed});

  void dispose() {
    _stateController.close();
  }
}
