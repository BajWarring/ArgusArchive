import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/models/file_entry.dart';
import '../../core/utils/path_utils.dart';
import '../../services/video/video_player_controller.dart';

enum GestureAxis { none, horizontal, vertical }

class VideoPlayerScreen extends StatefulWidget {
  final FileEntry entry;
  const VideoPlayerScreen({super.key, required this.entry});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _controller;
  bool _showControls = true;
  bool _isLocked = false;
  Timer? _hideTimer;
  
  // VLC Orientation Logic
  bool _isLandscape = true;
  int _aspectRatioMode = 0; // 0: Fit, 1: Stretch, 2: Crop
  final List<String> _aspectRatioLabels = ['Fit', 'Stretch', 'Crop'];
  final List<IconData> _aspectRatioIcons = [Icons.aspect_ratio, Icons.fit_screen, Icons.crop];

  // Gesture Matrix State
  GestureAxis _currentAxis = GestureAxis.none;
  Offset _dragStartPos = Offset.zero;
  double _currentVolume = 0.5;
  double _currentBrightness = 0.5;
  bool _isLeftHalfDrag = false;
  
  Duration _startSeekPos = Duration.zero;
  Duration _targetSeekPos = Duration.zero;
  double? _scrubberDragValue;

  // Visual Feedback
  String _gestureFeedback = "";
  IconData? _gestureIcon;
  bool _showGestureFeedback = false;
  Timer? _toastTimer;

  // Subtitle State
  int _subtitleDelayMs = 0;

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
    _hideTimer = Timer(const Duration(seconds: 3), () { // Reduced to 3s per requirements
      if (mounted && _showControls && !_isLocked) setState(() => _showControls = false);
    });
  }

    // INSTANT TAP TOGGLE
  void _toggleControls() {
    if (_isLocked) return; // Do nothing if locked
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _startHideTimer();
    } else {
      _hideTimer?.cancel();
    }
  }


  // VLC-Style Orientation Toggle
  void _toggleOrientation() {
    if (_isLandscape) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    }
    setState(() => _isLandscape = !_isLandscape);
  }
    void _setLandscape() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  }


  // ==========================================
  // GESTURE MATRIX (Runs even when overlay visible)
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

    if (_currentAxis == GestureAxis.none) {
      if (dx.abs() > 20) _currentAxis = GestureAxis.horizontal;
      else if (dy.abs() > 20) _currentAxis = GestureAxis.vertical;
    }

    if (_currentAxis == GestureAxis.horizontal) {
      final screenWidth = MediaQuery.of(context).size.width;
      final duration = _controller!.value.duration;
      
      // Dynamic sensitivity based on drag distance
      final seekPercentage = (dx / screenWidth) * 0.3;
      final seekDelta = Duration(milliseconds: (duration.inMilliseconds * seekPercentage).toInt());
      
      _targetSeekPos = _startSeekPos + seekDelta;
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
      final screenHeight = MediaQuery.of(context).size.height;
      final delta = -dy / screenHeight; 
      _dragStartPos = details.globalPosition;

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
    setState(() { _showGestureFeedback = true; _gestureFeedback = "2x Speed"; _gestureIcon = Icons.speed; });
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    if (_isLocked || _controller == null) return;
    _controller?.setSpeed(1.0);
    setState(() => _showGestureFeedback = false);
  }

  // ==========================================
  // UI RENDERING
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Hardware Video Layer
          AndroidView(
            viewType: 'com.app.argusarchive/video_player',
            creationParams: {'path': widget.entry.path},
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: _onPlatformViewCreated,
          ),

          // 2. Dimming Background (Toggles instantly)
          if (_showControls)
            Container(color: Colors.black54),

          // 3. Gesture Layer (Sits behind the buttons, covers entire screen)
          GestureDetector(
            onTap: _toggleControls,
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            onLongPressStart: _onLongPressStart,
            onLongPressEnd: _onLongPressEnd,
            onLongPressCancel: () => _onLongPressEnd(const LongPressEndDetails()),
            behavior: HitTestBehavior.translucent,
            child: Container(color: Colors.transparent),
          ),

          // 4. Gesture Toast Overlay
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

          // 5. Unlock Button Overlay (Only visible when locked)
          if (_isLocked)
            Positioned(
              left: 32, top: 32,
              child: IconButton(
                icon: const Icon(Icons.lock, color: Colors.white70, size: 32),
                onPressed: () => setState(() => _isLocked = false),
              ),
            ),

          // 6. Interactive Controls Button Layer (Sits on top)
          if (_showControls && !_isLocked && _controller != null)
            _buildInteractiveControls(),
        ],
      ),
    );
  }

  Widget _buildInteractiveControls() {
    return SafeArea(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // TOP BAR: Title & Subtitles (Replaced 3-dots with CC)
          Row(
            children: [
              IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
              Expanded(child: Text(PathUtils.getName(widget.entry.path), style: const TextStyle(color: Colors.white, fontSize: 16), overflow: TextOverflow.ellipsis)),
              IconButton(icon: const Icon(Icons.audiotrack, color: Colors.white), onPressed: () => _showTrackSelector(true)),
              // The new CC Subtitle Menu Button
              IconButton(icon: const Icon(Icons.closed_caption, color: Colors.white, size: 28), onPressed: () => _showSubtitleTools()),
              const SizedBox(width: 8),
            ],
          ),

          // CENTER CONTROLS (20% Larger)
          StreamBuilder<VideoPlaybackState>(
            stream: _controller!.stateStream,
            builder: (ctx, snap) {
              final isPlaying = snap.data?.isPlaying ?? false;
              final isBuffering = snap.data?.status == 'buffering';
              final pos = snap.data?.position ?? Duration.zero;

              return isBuffering 
                  ? const CircularProgressIndicator(color: Colors.tealAccent)
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(iconSize: 56, icon: const Icon(Icons.skip_previous, color: Colors.white), onPressed: () => _controller!.seekTo(pos - const Duration(seconds: 10))),
                        const SizedBox(width: 32),
                        IconButton(
                          iconSize: 96, // 20% larger play/pause
                          icon: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, color: Colors.white),
                          onPressed: () => isPlaying ? _controller!.pause() : _controller!.play(),
                        ),
                        const SizedBox(width: 32),
                        IconButton(iconSize: 56, icon: const Icon(Icons.skip_next, color: Colors.white), onPressed: () => _controller!.seekTo(pos + const Duration(seconds: 10))),
                      ],
                    );
            }
          ),

          // BOTTOM BAR GROUPING (Left: Lock/Orient, Center: Progress, Right: Aspect/PiP)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0, left: 16, right: 16),
            child: Row(
              children: [
                // LEFT GROUP
                IconButton(icon: const Icon(Icons.lock_open, color: Colors.white), onPressed: () => setState(() { _isLocked = true; _showControls = false; })),
                IconButton(icon: Icon(_isLandscape ? Icons.screen_rotation : Icons.screen_lock_portrait, color: Colors.white), onPressed: _toggleOrientation),
                
                // CENTER: High-Frequency Progress Bar
                Expanded(
                  child: StreamBuilder<VideoPlaybackState>(
                    stream: _controller!.stateStream,
                    builder: (ctx, snap) {
                      final state = snap.data ?? VideoPlaybackState();
                      final maxDur = state.duration.inMilliseconds.toDouble();
                      final bufDur = state.buffered.inMilliseconds.toDouble();
                      final currentPos = _scrubberDragValue ?? state.position.inMilliseconds.toDouble();
                      
                      return Row(
                        children: [
                          const SizedBox(width: 8),
                          Text(_formatDuration(Duration(milliseconds: currentPos.toInt())), style: const TextStyle(color: Colors.white, fontSize: 12)),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 3,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                              ),
                              child: Slider(
                                activeColor: Colors.tealAccent,
                                inactiveColor: Colors.white24,
                                secondaryActiveColor: Colors.white54,
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
                                  // Live Preview Update (Frame updates while dragging)
                                  _controller!.liveSeekTo(Duration(milliseconds: val.toInt()));
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
                          const SizedBox(width: 8),
                        ],
                      );
                    }
                  ),
                ),

                // RIGHT GROUP
                IconButton(
                  icon: Icon(_aspectRatioIcons[_aspectRatioMode], color: Colors.white),
                  onPressed: () {
                    setState(() {
                      _aspectRatioMode = (_aspectRatioMode + 1) % 3;
                      _controller?.setAspectRatio(_aspectRatioMode);
                      _toastTimer?.cancel();
                      setState(() { _gestureFeedback = _aspectRatioLabels[_aspectRatioMode]; _gestureIcon = _aspectRatioIcons[_aspectRatioMode]; _showGestureFeedback = true; });
                      _toastTimer = Timer(const Duration(milliseconds: 800), () => setState(() => _showGestureFeedback = false));
                    });
                  },
                ),
                IconButton(icon: const Icon(Icons.picture_in_picture_alt, color: Colors.white), onPressed: () => _controller!.enterPiP()),
              ],
            ),
          )
        ],
      ),
    );
  }

  // The new Advanced Subtitle Menu (CC Button)
  void _showSubtitleTools() {
    _hideTimer?.cancel();
    final state = _controller!.value;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Subtitle Tools', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 16),
                  
                  // Embedded Tracks Selection
                  const Text('Select Track', style: TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold)),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Disable Subtitles', style: TextStyle(color: Colors.white)),
                    onTap: () { _controller!.disableSubtitles(); Navigator.pop(ctx); },
                  ),
                  ...state.subtitleTracks.map((t) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(t.isSelected ? Icons.radio_button_checked : Icons.radio_button_off, color: Colors.tealAccent),
                    title: Text('${t.language.toUpperCase()} - ${t.label}', style: const TextStyle(color: Colors.white)),
                    onTap: () { _controller!.selectTrack(t, false); Navigator.pop(ctx); },
                  )),
                  const Divider(color: Colors.white24),
                  
                  // Synchronization / Delay
                  const Text('Synchronization (Delay)', style: TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.white),
                        onPressed: () {
                          setModalState(() => _subtitleDelayMs -= 100);
                          _controller!.setSubtitleDelay(_subtitleDelayMs);
                        }
                      ),
                      Text('${_subtitleDelayMs > 0 ? "+" : ""}$_subtitleDelayMs ms', style: const TextStyle(color: Colors.white, fontSize: 16)),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                        onPressed: () {
                          setModalState(() => _subtitleDelayMs += 100);
                          _controller!.setSubtitleDelay(_subtitleDelayMs);
                        }
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24),

                  // Online Search
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.cloud_download, color: Colors.blue),
                    title: const Text('Search Online (OpenSubtitles)', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('OpenSubtitles API integration pending.')));
                    },
                  ),
                ],
              ),
            ),
          );
        }
      ),
    ).then((_) => _startHideTimer());
  }

  void _showTrackSelector(bool isAudio) {
    _hideTimer?.cancel();
    final state = _controller!.value;
    final tracks = state.audioTracks;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(padding: EdgeInsets.all(16.0), child: Text('Audio Tracks', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white))),
            ...tracks.map((t) => ListTile(
              leading: Icon(t.isSelected ? Icons.radio_button_checked : Icons.radio_button_off, color: Colors.tealAccent),
              title: Text('${t.language.toUpperCase()} - ${t.label}', style: const TextStyle(color: Colors.white)),
              onTap: () { _controller!.selectTrack(t, true); Navigator.pop(ctx); },
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
