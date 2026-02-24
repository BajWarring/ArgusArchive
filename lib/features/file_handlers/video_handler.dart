import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/models/file_entry.dart';
import '../../core/interfaces/storage_adapter.dart';
import '../../core/utils/path_utils.dart';
import '../../services/video/video_player_controller.dart';
import 'file_handler.dart';

enum GestureAxis { none, horizontal, vertical }

class VideoHandler implements FileHandler {
  final List<String> _exts = ['mp4', 'mkv', 'webm', 'avi', 'mov', 'flv', 'ts'];

  @override
  bool canHandle(FileEntry entry) => _exts.contains(PathUtils.getExtension(entry.path));

  @override
  Widget buildPreview(FileEntry entry, StorageAdapter adapter) => const Icon(Icons.movie, color: Colors.indigo);

  @override
  Future<void> open(BuildContext context, FileEntry entry, StorageAdapter adapter) async {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => _VideoPlayerScreen(entry: entry)));
  }
}

class _VideoPlayerScreen extends StatefulWidget {
  final FileEntry entry;
  const _VideoPlayerScreen({required this.entry});

  @override
  State<_VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<_VideoPlayerScreen> {
  VideoPlayerController? _controller;
  bool _showControls = true;
  bool _isLocked = false;
  Timer? _hideTimer;
  
  // Custom Controls State
  bool _isLandscape = true;
  int _aspectRatioMode = 0; // 0: Fit, 1: Stretch/Fill, 2: Crop/Zoom
  final List<String> _aspectRatioLabels = ['Fit', 'Stretch', 'Crop'];
  final List<IconData> _aspectRatioIcons = [Icons.aspect_ratio, Icons.fit_screen, Icons.crop];

  // Axis-Locked Gesture State
  GestureAxis _currentAxis = GestureAxis.none;
  Offset _dragStartPos = Offset.zero;
  
  // Vertical Gesture
  double _currentVolume = 0.5;
  double _currentBrightness = 0.5;
  bool _isLeftHalfDrag = false;
  
  // Horizontal Gesture (Seek)
  Duration _startSeekPos = Duration.zero;
  Duration _targetSeekPos = Duration.zero;
  
  // Scrubber State
  double? _scrubberDragValue;

  // Visual Feedback Toast
  String _gestureFeedback = "";
  IconData? _gestureIcon;
  bool _showGestureFeedback = false;
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _setLandscape();
    _startHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _toastTimer?.cancel();
    _controller?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _onPlatformViewCreated(int id) => setState(() => _controller = VideoPlayerController(id));

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _showControls && !_isLocked) setState(() => _showControls = false);
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _startHideTimer();
  }

  void _toggleOrientation() {
    if (_isLandscape) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    }
    setState(() => _isLandscape = !_isLandscape);
  }

  void _cycleAspectRatio() {
    setState(() {
      _aspectRatioMode = (_aspectRatioMode + 1) % 3;
      _controller?.setAspectRatio(_aspectRatioMode);
      _showToast(_aspectRatioLabels[_aspectRatioMode], _aspectRatioIcons[_aspectRatioMode]);
    });
  }

  // ==========================================
  // PREMIUM GESTURE MATRIX
  // ==========================================

  void _onPanStart(DragStartDetails details) {
    if (_isLocked || _controller == null) return;
    _dragStartPos = details.globalPosition;
    _currentAxis = GestureAxis.none;
    _startSeekPos = _controller!.value.position;
    
    final screenWidth = MediaQuery.of(context).size.width;
    _isLeftHalfDrag = details.globalPosition.dx < (screenWidth / 2);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_isLocked || _controller == null) return;
    
    final dx = details.globalPosition.dx - _dragStartPos.dx;
    final dy = details.globalPosition.dy - _dragStartPos.dy;

    // Strict 20px Axis Lock Threshold (Fixed curly braces for analysis)
    if (_currentAxis == GestureAxis.none) {
      if (dx.abs() > 20) {
        _currentAxis = GestureAxis.horizontal;
      } else if (dy.abs() > 20) {
        _currentAxis = GestureAxis.vertical;
      }
    }

    if (_currentAxis == GestureAxis.horizontal) {
      // Horizontal: Velocity/Distance based seeking
      final screenWidth = MediaQuery.of(context).size.width;
      final duration = _controller!.value.duration;
      
      // Calculate seek amount (1 full screen swipe = ~30% of video)
      final seekPercentage = (dx / screenWidth) * 0.3;
      final seekDelta = Duration(milliseconds: (duration.inMilliseconds * seekPercentage).toInt());
      
      _targetSeekPos = _startSeekPos + seekDelta;
      
      // Clamp
      if (_targetSeekPos < Duration.zero) _targetSeekPos = Duration.zero;
      if (_targetSeekPos > duration) _targetSeekPos = duration;

      final deltaSec = seekDelta.inSeconds;
      final sign = deltaSec > 0 ? "+" : "";
      
      setState(() {
        _showGestureFeedback = true;
        _gestureFeedback = "$sign${deltaSec}s\n${_formatDuration(_targetSeekPos)}";
        _gestureIcon = deltaSec > 0 ? Icons.fast_forward : Icons.fast_rewind;
      });
      
    } else if (_currentAxis == GestureAxis.vertical) {
      // Vertical: Volume or Brightness
      final screenHeight = MediaQuery.of(context).size.height;
      // Negative dy means sliding UP (increase)
      final delta = -dy / screenHeight; 
      _dragStartPos = details.globalPosition; // Reset for relative continuous drag

      setState(() {
        _showGestureFeedback = true;
        if (_isLeftHalfDrag) {
          _currentBrightness = (_currentBrightness + delta).clamp(0.0, 1.0);
          _controller?.setBrightness(_currentBrightness);
          _gestureFeedback = "${(_currentBrightness * 100).toInt()}%";
          _gestureIcon = Icons.brightness_6;
        } else {
          _currentVolume = (_currentVolume + delta).clamp(0.0, 1.0);
          _controller?.setVolume(_currentVolume);
          _gestureFeedback = "${(_currentVolume * 100).toInt()}%";
          _gestureIcon = Icons.volume_up;
        }
      });
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (_currentAxis == GestureAxis.horizontal) {
      _controller?.seekTo(_targetSeekPos);
    }
    setState(() {
      _showGestureFeedback = false;
      _currentAxis = GestureAxis.none;
    });
  }

  void _onLongPressStart(LongPressStartDetails details) {
    if (_isLocked || _controller == null) return;
    HapticFeedback.lightImpact();
    _controller?.setSpeed(2.0);
    setState(() {
      _showGestureFeedback = true;
      _gestureFeedback = "2x Speed";
      _gestureIcon = Icons.speed;
    });
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    if (_isLocked || _controller == null) return;
    _controller?.setSpeed(1.0);
    setState(() {
      _showGestureFeedback = false;
    });
  }

  void _onDoubleTap(TapDownDetails details) {
    if (_isLocked || _controller == null) return;
    final screenWidth = MediaQuery.of(context).size.width;
    final pos = _controller!.value.position;
    
    if (details.globalPosition.dx < screenWidth / 2) {
      _controller!.seekTo(pos - const Duration(seconds: 10));
      _showToast("-10s", Icons.replay_10);
    } else {
      _controller!.seekTo(pos + const Duration(seconds: 10));
      _showToast("+10s", Icons.forward_10);
    }
  }

  void _showToast(String text, IconData icon) {
    setState(() { _gestureFeedback = text; _gestureIcon = icon; _showGestureFeedback = true; });
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showGestureFeedback = false);
    });
  }

  void _setLandscape() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  }

  // ==========================================
  // BUILD UI
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Native Hardware Player
          AndroidView(
            viewType: 'com.app.argusarchive/video_player',
            creationParams: {'path': widget.entry.path},
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: _onPlatformViewCreated,
          ),

          // 2. Gesture Overlay Matrix
          GestureDetector(
            onTap: _toggleControls,
            onDoubleTapDown: _onDoubleTap,
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            onLongPressStart: _onLongPressStart,
            onLongPressEnd: _onLongPressEnd,
            onLongPressCancel: () => _onLongPressEnd(const LongPressEndDetails()),
            behavior: HitTestBehavior.translucent,
            child: Container(color: Colors.transparent),
          ),

          // 3. Gesture Feedback Toast
          if (_showGestureFeedback)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(16)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_gestureIcon != null) Icon(_gestureIcon, color: Colors.tealAccent, size: 36),
                    const SizedBox(height: 8),
                    Text(_gestureFeedback, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),

          // 4. Lock Overlay Icon (if controls hidden but locked)
          if (_isLocked && !_showControls)
            Positioned(
              left: 32, top: 32,
              child: IconButton(
                icon: const Icon(Icons.lock, color: Colors.white38),
                onPressed: _toggleControls,
              ),
            ),

          // 5. Full Controls Overlay
          if (_showControls && _controller != null)
            _buildControlsOverlay(),
        ],
      ),
    );
  }

  Widget _buildControlsOverlay() {
    return Container(
      color: Colors.black54, 
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // TOP BAR
            Row(
              children: [
                IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
                Expanded(child: Text(PathUtils.getName(widget.entry.path), style: const TextStyle(color: Colors.white, fontSize: 16), overflow: TextOverflow.ellipsis)),
                if (!_isLocked) ...[
                  // NEW: 3-dots Menu for Settings/Equalizer
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    color: const Color(0xFF1E1E1E),
                    onSelected: (value) {
                      _hideTimer?.cancel(); // Pause hide timer while viewing snackbar
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$value configuration coming soon!')),
                      );
                      _startHideTimer();
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'Equalizer', child: Row(children: [Icon(Icons.equalizer, size: 20), SizedBox(width: 12), Text('Equalizer')])),
                      const PopupMenuItem(value: 'Settings', child: Row(children: [Icon(Icons.settings, size: 20), SizedBox(width: 12), Text('Player Settings')])),
                    ],
                  ),
                  IconButton(icon: const Icon(Icons.audiotrack, color: Colors.white), onPressed: () => _showTrackSelector(true)),
                  IconButton(icon: const Icon(Icons.subtitles, color: Colors.white), onPressed: () => _showTrackSelector(false)),
                ],
              ],
            ),

            // MIDDLE PLAY/PAUSE
            if (!_isLocked)
              StreamBuilder<VideoPlaybackState>(
                stream: _controller!.stateStream,
                builder: (ctx, snap) {
                  final isPlaying = snap.data?.isPlaying ?? false;
                  final isBuffering = snap.data?.status == 'buffering';
                  return isBuffering 
                      ? const CircularProgressIndicator(color: Colors.tealAccent)
                      : IconButton(
                          iconSize: 72,
                          icon: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, color: Colors.white),
                          onPressed: () => isPlaying ? _controller!.pause() : _controller!.play(),
                        );
                }
              ),

            // BOTTOM BAR GROUPING
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Scrubber Line
                if (!_isLocked)
                  StreamBuilder<VideoPlaybackState>(
                    stream: _controller!.stateStream,
                    builder: (ctx, snap) {
                      final state = snap.data ?? VideoPlaybackState();
                      final maxDur = state.duration.inMilliseconds.toDouble();
                      final bufDur = state.buffered.inMilliseconds.toDouble();
                      // Use drag value if scrubbing, else stream position
                      final currentPos = _scrubberDragValue ?? state.position.inMilliseconds.toDouble();
                      
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          children: [
                            Text(_formatDuration(Duration(milliseconds: currentPos.toInt())), style: const TextStyle(color: Colors.white, fontSize: 12)),
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 4,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                                ),
                                child: Slider(
                                  activeColor: Colors.tealAccent,
                                  inactiveColor: Colors.white24,
                                  secondaryActiveColor: Colors.white54, // Buffer visualization
                                  secondaryTrackValue: bufDur.clamp(0, maxDur > 0 ? maxDur : 1),
                                  min: 0,
                                  max: maxDur > 0 ? maxDur : 1,
                                  value: currentPos.clamp(0, maxDur > 0 ? maxDur : 1),
                                  onChangeStart: (val) {
                                    _hideTimer?.cancel();
                                    setState(() => _scrubberDragValue = val);
                                  },
                                  onChanged: (val) {
                                    setState(() => _scrubberDragValue = val);
                                  },
                                  onChangeEnd: (val) {
                                    _controller!.seekTo(Duration(milliseconds: val.toInt()));
                                    setState(() => _scrubberDragValue = null);
                                    _startHideTimer();
                                  },
                                ),
                              ),
                            ),
                            Text(_formatDuration(state.duration), style: const TextStyle(color: Colors.white, fontSize: 12)),
                          ],
                        ),
                      );
                    }
                  ),

                // Button Groups
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // LEFT GROUP: Lock, Orientation
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(_isLocked ? Icons.lock : Icons.lock_open, color: _isLocked ? Colors.tealAccent : Colors.white),
                            onPressed: () => setState(() { _isLocked = !_isLocked; _startHideTimer(); }),
                          ),
                          if (!_isLocked)
                            IconButton(
                              icon: Icon(_isLandscape ? Icons.screen_rotation : Icons.screen_lock_portrait, color: Colors.white),
                              onPressed: _toggleOrientation,
                            ),
                        ],
                      ),

                      // CENTER GROUP: RW, Play/Pause (Small), FF
                      if (!_isLocked)
                        StreamBuilder<VideoPlaybackState>(
                          stream: _controller!.stateStream,
                          builder: (ctx, snap) {
                            final state = snap.data ?? VideoPlaybackState();
                            return Row(
                              children: [
                                IconButton(icon: const Icon(Icons.replay_10, color: Colors.white), onPressed: () => _controller!.seekTo(state.position - const Duration(seconds: 10))),
                                IconButton(
                                  icon: Icon(state.isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
                                  onPressed: () => state.isPlaying ? _controller!.pause() : _controller!.play(),
                                ),
                                IconButton(icon: const Icon(Icons.forward_10, color: Colors.white), onPressed: () => _controller!.seekTo(state.position + const Duration(seconds: 10))),
                              ],
                            );
                          }
                        ),

                      // RIGHT GROUP: Aspect Ratio, PiP
                      if (!_isLocked)
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(_aspectRatioIcons[_aspectRatioMode], color: Colors.white),
                              onPressed: _cycleAspectRatio,
                              tooltip: 'Aspect Ratio',
                            ),
                            IconButton(
                              icon: const Icon(Icons.picture_in_picture_alt, color: Colors.white),
                              onPressed: () => _controller!.enterPiP(),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  void _showTrackSelector(bool isAudio) {
    _hideTimer?.cancel();
    final state = _controller!.value;
    final tracks = isAudio ? state.audioTracks : state.subtitleTracks;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(isAudio ? 'Audio Tracks' : 'Subtitles', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
            if (!isAudio)
              ListTile(
                title: const Text('Disable Subtitles', style: TextStyle(color: Colors.white)),
                onTap: () { _controller!.disableSubtitles(); Navigator.pop(ctx); },
              ),
            ...tracks.map((t) => ListTile(
              leading: Icon(t.isSelected ? Icons.radio_button_checked : Icons.radio_button_off, color: Colors.tealAccent),
              title: Text('${t.language.toUpperCase()} - ${t.label}', style: const TextStyle(color: Colors.white)),
              onTap: () {
                _controller!.selectTrack(t, isAudio);
                Navigator.pop(ctx);
              },
            ))
          ],
        ),
      ),
    ).then((_) => _startHideTimer());
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    if (d.inHours > 0) return "${d.inHours}:${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}";
    return "${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}";
  }
}
