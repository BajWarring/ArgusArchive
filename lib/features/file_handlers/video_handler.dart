import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/models/file_entry.dart';
import '../../core/interfaces/storage_adapter.dart';
import '../../core/utils/path_utils.dart';
import '../../services/video/video_player_controller.dart';
import 'file_handler.dart';

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
  
  // Gesture State
  double _dragStartY = 0;
  double _currentVolume = 0.5;
  double _currentBrightness = 0.5;
  String _gestureFeedback = "";
  bool _showGestureFeedback = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    _startHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _onPlatformViewCreated(int id) {
    setState(() => _controller = VideoPlayerController(id));
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _showControls) setState(() => _showControls = false);
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _startHideTimer();
  }

  // === GESTURE LOGIC ===
  void _onVerticalDragStart(DragStartDetails details) {
    _dragStartY = details.globalPosition.dy;
  }

  void _onVerticalDragUpdate(DragUpdateDetails details, BuildContext context) {
    if (_isLocked) return;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isLeftHalf = details.globalPosition.dx < (screenWidth / 2);
    
    // Calculate delta as percentage of screen height
    final delta = (_dragStartY - details.globalPosition.dy) / screenHeight;
    _dragStartY = details.globalPosition.dy;

    setState(() {
      _showGestureFeedback = true;
      if (isLeftHalf) {
        _currentBrightness = (_currentBrightness + delta).clamp(0.0, 1.0);
        _controller?.setBrightness(_currentBrightness);
        _gestureFeedback = "Brightness: ${(_currentBrightness * 100).toInt()}%";
      } else {
        _currentVolume = (_currentVolume + delta).clamp(0.0, 1.0);
        _controller?.setVolume(_currentVolume);
        _gestureFeedback = "Volume: ${(_currentVolume * 100).toInt()}%";
      }
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    setState(() => _showGestureFeedback = false);
  }

  void _onDoubleTap(TapDownDetails details, BuildContext context) {
    if (_isLocked || _controller == null) return;
    final screenWidth = MediaQuery.of(context).size.width;
    final pos = _controller!.value.position;
    
    if (details.globalPosition.dx < screenWidth / 2) {
      _controller!.seekTo(pos - const Duration(seconds: 10));
      _showTempFeedback("⏪ -10s");
    } else {
      _controller!.seekTo(pos + const Duration(seconds: 10));
      _showTempFeedback("⏩ +10s");
    }
  }

  void _showTempFeedback(String text) {
    setState(() { _gestureFeedback = text; _showGestureFeedback = true; });
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showGestureFeedback = false);
    });
  }

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

          // 2. Gesture Overlay Layer
          GestureDetector(
            onTap: _toggleControls,
            onDoubleTapDown: (d) => _onDoubleTap(d, context),
            onVerticalDragStart: _onVerticalDragStart,
            onVerticalDragUpdate: (d) => _onVerticalDragUpdate(d, context),
            onVerticalDragEnd: _onVerticalDragEnd,
            behavior: HitTestBehavior.translucent,
            child: Container(color: Colors.transparent),
          ),

          // 3. Gesture Feedback Toast
          if (_showGestureFeedback)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(30)),
                child: Text(_gestureFeedback, style: const TextStyle(color: Colors.white, fontSize: 18)),
              ),
            ),

          // 4. Buffering Indicator
          if (_controller != null)
            StreamBuilder<VideoPlaybackState>(
              stream: _controller!.stateStream,
              builder: (ctx, snap) {
                if (snap.data?.status == 'buffering') {
                  return const Center(child: CircularProgressIndicator(color: Colors.teal));
                }
                return const SizedBox.shrink();
              },
            ),

          // 5. Controls Overlay
          if (_showControls && _controller != null)
            _buildControlsOverlay(),
        ],
      ),
    );
  }

  Widget _buildControlsOverlay() {
    return Container(
      color: Colors.black45, // Darken background slightly when controls are visible
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Bar
            Row(
              children: [
                IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
                Expanded(child: Text(PathUtils.getName(widget.entry.path), style: const TextStyle(color: Colors.white, fontSize: 16), overflow: TextOverflow.ellipsis)),
                if (!_isLocked) ...[
                  IconButton(icon: const Icon(Icons.picture_in_picture_alt, color: Colors.white), onPressed: () => _controller!.enterPiP()),
                  IconButton(icon: const Icon(Icons.audiotrack, color: Colors.white), onPressed: () => _showTrackSelector(true)),
                  IconButton(icon: const Icon(Icons.subtitles, color: Colors.white), onPressed: () => _showTrackSelector(false)),
                ],
              ],
            ),

            // Center Play/Pause & Lock
            Row(
              mainAxisAlignment: _isLocked ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 16.0),
                  child: IconButton(
                    iconSize: 32,
                    icon: Icon(_isLocked ? Icons.lock : Icons.lock_open, color: Colors.white),
                    onPressed: () => setState(() => _isLocked = !_isLocked),
                  ),
                ),
                if (!_isLocked) ...[
                  const Spacer(),
                  StreamBuilder<VideoPlaybackState>(
                    stream: _controller!.stateStream,
                    builder: (ctx, snap) {
                      final isPlaying = snap.data?.isPlaying ?? false;
                      return IconButton(
                        iconSize: 72,
                        icon: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, color: Colors.white),
                        onPressed: () => isPlaying ? _controller!.pause() : _controller!.play(),
                      );
                    }
                  ),
                  const Spacer(),
                  const SizedBox(width: 48), // Balance for lock icon
                ]
              ],
            ),

            // Bottom Seek Bar
            if (!_isLocked)
              StreamBuilder<VideoPlaybackState>(
                stream: _controller!.stateStream,
                builder: (ctx, snap) {
                  final state = snap.data ?? VideoPlaybackState();
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      children: [
                        Text(_formatDuration(state.position), style: const TextStyle(color: Colors.white)),
                        Expanded(
                          child: Slider(
                            activeColor: Colors.tealAccent,
                            inactiveColor: Colors.white24,
                            min: 0,
                            max: state.duration.inMilliseconds.toDouble().clamp(1, double.infinity),
                            value: state.position.inMilliseconds.toDouble().clamp(0, state.duration.inMilliseconds.toDouble()),
                            onChangeStart: (_) => _hideTimer?.cancel(),
                            onChangeEnd: (_) => _startHideTimer(),
                            onChanged: (val) => _controller!.seekTo(Duration(milliseconds: val.toInt())),
                          ),
                        ),
                        Text(_formatDuration(state.duration), style: const TextStyle(color: Colors.white)),
                      ],
                    ),
                  );
                }
              )
          ],
        ),
      ),
    );
  }

  void _showTrackSelector(bool isAudio) {
    final state = _controller!.value;
    final tracks = isAudio ? state.audioTracks : state.subtitleTracks;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
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
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    if (d.inHours > 0) return "${d.inHours}:${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}";
    return "${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}";
  }
}
