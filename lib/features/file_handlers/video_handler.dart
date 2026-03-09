import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/file_entry.dart';
import '../../core/interfaces/storage_adapter.dart';
import '../../core/utils/path_utils.dart';
import '../../services/media_player_app/video_player_controller.dart'; 
import '../../providers/media_history_provider.dart'; // NEW
import 'file_handler.dart';

class VideoHandler implements FileHandler {
  final List<String> _exts = ['mp4', 'mkv', 'webm', 'avi', 'mov', 'flv', 'ts', 'wmv', 'm4v', '3gp'];
  @override
  bool canHandle(FileEntry entry) => _exts.contains(PathUtils.getExtension(entry.path));
  @override
  Widget buildPreview(FileEntry entry, StorageAdapter adapter) => const Icon(Icons.movie, color: Colors.indigo);
  @override
  Future<void> open(BuildContext context, FileEntry entry, StorageAdapter adapter) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => VideoPlayerScreen(entry: entry)));
  }
}

enum GestureType { none, seek, volume, brightness, zoom }
enum VideoFitMode { fit, crop, stretch }
enum ActivePanel { none, audio, cc, ccCustomization, more }

class VideoPlayerScreen extends ConsumerStatefulWidget {
  final FileEntry entry;
  const VideoPlayerScreen({super.key, required this.entry});
  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen> with TickerProviderStateMixin {
  VideoPlayerController? _ctrl;
  late AnimationController _playPauseAnimController;
  
  bool _showUI = true;
  Timer? _hideTimer;
  bool _isLocked = false;
  bool _isOrientationLocked = false;
  VideoFitMode _fitMode = VideoFitMode.fit;
  ActivePanel _activePanel = ActivePanel.none;

  GestureType _currentGesture = GestureType.none;
  double _simulatedBrightness = 1.0;
  double _volume = 0.5;
  bool _isSpeedingUp = false;

  double _currentScale = 1.0;
  double _baseScale = 1.0;
  Duration _seekStartPos = Duration.zero;
  double _accumulatedSeekSeconds = 0.0;

  String _activeOverlay = '';
  int _animKey = 0;
  Timer? _overlayTimer;
  bool _centerPlayVisible = false;

  double _audioDelayMs = 0.0;
  double _ccDelayMs = 0.0;
  final List<double> _equalizerBands = List.filled(10, 0.0);
  double _ccBottomMargin = 8.0;
  bool _ccHasBackground = true;

  @override
  void initState() {
    super.initState();
    _playPauseAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // FREE ROTATION: Allows portrait, reverse portrait, and both landscapes dynamically
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _startHideTimer();
  }

  void _onViewCreated(int id) {
    final ctrl = VideoPlayerController(id);
    setState(() => _ctrl = ctrl);
    ctrl.stateStream.listen((state) {
      if (!mounted) return;
      if (state.isPlaying && _playPauseAnimController.status != AnimationStatus.forward) _playPauseAnimController.forward();
      else if (!state.isPlaying && _playPauseAnimController.status != AnimationStatus.reverse) _playPauseAnimController.reverse();
      setState(() {}); 
    });
    _loadHistorySettings();
  }

  void _loadHistorySettings() {
    final history = ref.read(mediaHistoryProvider);
    final item = history.where((e) => e.path == widget.entry.path).firstOrNull;
    if (item != null) {
      _audioDelayMs = item.audioDelayMs;
      _ccDelayMs = item.subtitleDelayMs;
      _ctrl?.setAudioDelay(_audioDelayMs.toInt());
      _ctrl?.setSubtitleDelay(_ccDelayMs.toInt());
      _ctrl?.seekTo(Duration(milliseconds: item.positionMs));
    }
  }

  @override
  void dispose() {
    _saveHistory();
    _ctrl?.dispose();
    _playPauseAnimController.dispose();
    _hideTimer?.cancel();
    _overlayTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    // RESTORE PORTRAIT ON EXIT
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _saveHistory() {
    if (_ctrl == null) return;
    final item = MediaHistoryItem(
      path: widget.entry.path,
      title: PathUtils.getName(widget.entry.path),
      type: 'video', // NEW
      positionMs: _ctrl!.value.position.inMilliseconds,
      durationMs: _ctrl!.value.duration.inMilliseconds,
      audioDelayMs: _audioDelayMs,
      subtitleDelayMs: _ccDelayMs,
      lastPlayed: DateTime.now(),
    );
    ref.read(mediaHistoryProvider.notifier).save(item);
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && (_ctrl?.value.isPlaying ?? false) && _currentGesture == GestureType.none && _activePanel == ActivePanel.none) {
        setState(() => _showUI = false);
      }
    });
  }

  void _handleSingleTap() {
    if (_isLocked) { setState(() => _showUI = true); _startHideTimer(); return; }
    if (_activePanel != ActivePanel.none) { setState(() => _activePanel = ActivePanel.none); _startHideTimer(); return; }
    setState(() { _showUI = !_showUI; if (_showUI) _startHideTimer(); });
  }

  void _handleScaleStart(ScaleStartDetails details) {
    if (_isLocked || _activePanel != ActivePanel.none || _ctrl == null) return;
    _baseScale = _currentScale; _seekStartPos = _ctrl!.value.position; _accumulatedSeekSeconds = 0.0; _currentGesture = GestureType.none; _showUI = true;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (_isLocked || _activePanel != ActivePanel.none || _ctrl == null) return;
    if (details.pointerCount >= 2) {
      setState(() { _currentGesture = GestureType.zoom; _currentScale = (_baseScale * details.scale).clamp(0.5, 1.5); _activeOverlay = 'zoom'; });
      return;
    }
    if (details.pointerCount == 1) {
      final dx = details.focalPointDelta.dx; final dy = details.focalPointDelta.dy;
      if (_currentGesture == GestureType.none) {
        if (dx.abs() > dy.abs() && dx.abs() > 1.5) _currentGesture = GestureType.seek;
        else if (dy.abs() > 1.5) _currentGesture = details.focalPoint.dx < MediaQuery.of(context).size.width / 2 ? GestureType.volume : GestureType.brightness;
      }
      setState(() {
        if (_currentGesture == GestureType.seek) { _accumulatedSeekSeconds += dx * 0.2; _activeOverlay = 'seek'; }
        else if (_currentGesture == GestureType.brightness) { _simulatedBrightness = (_simulatedBrightness - dy * 0.005).clamp(0.1, 1.0); _activeOverlay = 'brightness'; }
        else if (_currentGesture == GestureType.volume) { _volume = (_volume - dy * 0.005).clamp(0.0, 1.0); _ctrl?.setVolume(_volume); _activeOverlay = 'volume'; }
      });
    }
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    if (_isLocked || _activePanel != ActivePanel.none || _ctrl == null) return;
    if (_currentGesture == GestureType.seek) {
      final target = _seekStartPos + Duration(seconds: _accumulatedSeekSeconds.toInt());
      _ctrl!.seekTo(Duration(milliseconds: target.inMilliseconds.clamp(0, _ctrl!.value.duration.inMilliseconds)));
    }
    _currentGesture = GestureType.none;
    _overlayTimer?.cancel();
    _overlayTimer = Timer(const Duration(milliseconds: 800), () { if (mounted) setState(() => _activeOverlay = ''); });
    if (_ctrl!.value.isPlaying) _startHideTimer();
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    if (_isLocked || _activePanel != ActivePanel.none || _ctrl == null) return;
    final width = MediaQuery.of(context).size.width; final x = details.globalPosition.dx;
    setState(() {
      _animKey++;
      if (x < width * 0.4) { _activeOverlay = 'left_skip'; _ctrl!.seekTo(_ctrl!.value.position - const Duration(seconds: 10)); }
      else if (x > width * 0.6) { _activeOverlay = 'right_skip'; _ctrl!.seekTo(_ctrl!.value.position + const Duration(seconds: 10)); }
      else { _centerPlayVisible = true; _ctrl!.togglePlayPause(); }
    });
    _overlayTimer?.cancel();
    _overlayTimer = Timer(const Duration(milliseconds: 600), () { if (mounted) setState(() { _activeOverlay = ''; _centerPlayVisible = false; }); });
  }

  void _showEqualizerDialog() {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.grey.shade900, isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.7, padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text('Equalizer', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(10, (index) => Column(
                      children: [
                        Expanded(
                          child: RotatedBox(
                            quarterTurns: 3,
                            child: Slider(
                              min: -12.0, max: 12.0, value: _equalizerBands[index],
                              onChanged: (v) { setModalState(() => _equalizerBands[index] = v); _ctrl?.setEqualizer(_equalizerBands); },
                            ),
                          ),
                        ),
                        Text('${(index+1)*100}Hz', style: const TextStyle(color: Colors.white54, fontSize: 10)),
                      ],
                    )),
                  ),
                )
              ],
            ),
          );
        }
      )
    );
  }

  void _showCastDialog() {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.grey.shade900,
      builder: (ctx) => const Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cast to Device', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), SizedBox(height: 16),
            ListTile(leading: Icon(Icons.tv, color: Colors.white), title: Text('Living Room TV', style: TextStyle(color: Colors.white)), subtitle: Text('Available', style: TextStyle(color: Colors.green))),
            SizedBox(height: 16), Center(child: CircularProgressIndicator()), Center(child: Padding(padding: EdgeInsets.all(8.0), child: Text('Searching for devices...', style: TextStyle(color: Colors.white54))))
          ],
        ),
      )
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return duration.inHours > 0 ? '${duration.inHours}:$minutes:$seconds' : '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Transform.scale(
              scale: _currentScale,
              child: AndroidView(viewType: 'com.app.argusarchive/video_player', creationParams: {'path': widget.entry.path}, creationParamsCodec: const StandardMessageCodec(), onPlatformViewCreated: _onViewCreated),
            ),
          ),
          IgnorePointer(child: Container(color: Colors.black.withValues(alpha: 1.0 - _simulatedBrightness))),
          GestureDetector(
            onTap: _handleSingleTap, onDoubleTapDown: _handleDoubleTapDown, onScaleStart: _handleScaleStart, onScaleUpdate: _handleScaleUpdate, onScaleEnd: _handleScaleEnd,
            onLongPressStart: (_) { if (_isLocked || _activePanel != ActivePanel.none) return; setState(() => _isSpeedingUp = true); _ctrl?.setSpeed(2.0); HapticFeedback.lightImpact(); },
            onLongPressEnd: (_) { if (_isLocked) return; setState(() => _isSpeedingUp = false); _ctrl?.setSpeed(1.0); },
            behavior: HitTestBehavior.translucent, child: Container(color: Colors.transparent),
          ),
          
          if (_activeOverlay == 'left_skip') Align(alignment: Alignment.centerLeft, child: _TriangleArrows(key: ValueKey('L$_animKey'), isForward: false)),
          if (_centerPlayVisible) Align(alignment: Alignment.center, child: AnimatedIcon(icon: AnimatedIcons.play_pause, progress: _playPauseAnimController, color: Colors.white, size: 80)),
          if (_activeOverlay == 'right_skip') Align(alignment: Alignment.centerRight, child: _TriangleArrows(key: ValueKey('R$_animKey'), isForward: true)),
          
          if (_isSpeedingUp) const Positioned(top: 40, left: 0, right: 0, child: Center(child: Chip(backgroundColor: Colors.black87, avatar: Icon(Icons.fast_forward, color: Colors.white, size: 18), label: Text('2.0x Speed', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))))),
          if (_activeOverlay == 'zoom') Align(alignment: Alignment.topCenter, child: Padding(padding: const EdgeInsets.only(top: 80), child: Chip(backgroundColor: Colors.black87, label: Text('Zoom: ${(_currentScale * 100).toInt()}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))))),
          if (_activeOverlay == 'seek') Align(alignment: Alignment.center, child: Container(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(16)), child: Text('Seek to: ${_formatDuration(_seekStartPos + Duration(seconds: _accumulatedSeekSeconds.toInt()))}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)))),
          
          if (_activeOverlay == 'volume' || _activeOverlay == 'brightness')
            Align(
              alignment: _activeOverlay == 'volume' ? Alignment.centerRight : Alignment.centerLeft,
              child: Padding(
                padding: _activeOverlay == 'volume' ? const EdgeInsets.only(right: 32) : const EdgeInsets.only(left: 32),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24), decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(30)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_activeOverlay == 'volume' ? Icons.volume_up : Icons.brightness_6, color: Colors.white, size: 24), const SizedBox(height: 12),
                      SizedBox(height: 100, width: 4, child: Stack(alignment: Alignment.bottomCenter, children: [Container(decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))), FractionallySizedBox(heightFactor: _activeOverlay == 'volume' ? _volume : _simulatedBrightness, child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2))))])),
                    ],
                  ),
                ),
              ),
            ),

          AnimatedOpacity(
            opacity: _showUI && _activePanel == ActivePanel.none ? 1.0 : 0.0, duration: const Duration(milliseconds: 300),
            child: IgnorePointer(ignoring: !_showUI || _activePanel != ActivePanel.none, child: _isLocked ? Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.only(left: 32.0), child: IconButton(icon: const Icon(Icons.lock, color: Colors.white, size: 32), onPressed: () { setState(() => _isLocked = false); _startHideTimer(); }))) : _buildUnlockedUI()),
          ),

          AnimatedPositioned(
            duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic, top: 0, bottom: 0, right: _activePanel != ActivePanel.none ? 0 : -400,
            child: Container(width: 350, color: const Color(0xFF000000), child: SafeArea(child: Column(children: [Expanded(child: SingleChildScrollView(child: _buildRightPanelContent()))]))),
          ),
        ],
      ),
    );
  }

  Widget _buildUnlockedUI() {
    final pos = _ctrl?.value.position ?? Duration.zero;
    final dur = _ctrl?.value.duration ?? Duration.zero;
    final maxMs = dur.inMilliseconds.toDouble() > 0 ? dur.inMilliseconds.toDouble() : 1.0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black87, Colors.transparent])),
          child: Row(
            children: [
              IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
              Expanded(child: Text(PathUtils.getName(widget.entry.path), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2))),
              IconButton(icon: const Icon(Icons.cast, color: Colors.white), onPressed: _showCastDialog),
              IconButton(icon: const Icon(Icons.audiotrack, color: Colors.white), onPressed: () => setState(()=> _activePanel = ActivePanel.audio)),
              IconButton(icon: const Icon(Icons.closed_caption, color: Colors.white), onPressed: () => setState(()=> _activePanel = ActivePanel.cc)),
              IconButton(icon: const Icon(Icons.more_vert, color: Colors.white), onPressed: () => setState(()=> _activePanel = ActivePanel.more)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 40, 16, 16), decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black87, Colors.transparent])),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(_formatDuration(pos), style: const TextStyle(color: Colors.white, fontSize: 13)), const SizedBox(width: 8),
                  Expanded(
                    child: SliderTheme(
                      data: const SliderThemeData(trackHeight: 2, activeTrackColor: Color(0xFF4285F4), inactiveTrackColor: Colors.white24, thumbColor: Color(0xFF4285F4)),
                      child: Slider(value: pos.inMilliseconds.toDouble().clamp(0, maxMs), min: 0.0, max: maxMs, onChanged: (val) { _hideTimer?.cancel(); _ctrl?.seekTo(Duration(milliseconds: val.toInt())); }, onChangeEnd: (_) => _startHideTimer()),
                    ),
                  ), const SizedBox(width: 8),
                  Text(_formatDuration(dur), style: const TextStyle(color: Colors.white, fontSize: 13)),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(icon: const Icon(Icons.lock_open, color: Colors.white), onPressed: () => setState(() { _isLocked = true; _showUI = false; })),
                      IconButton(icon: Icon(_isOrientationLocked ? Icons.screen_lock_rotation : Icons.screen_rotation, color: _isOrientationLocked ? const Color(0xFF4285F4) : Colors.white), onPressed: () {
                        setState(() {
                          _isOrientationLocked = !_isOrientationLocked;
                          if (_isOrientationLocked) {
                            // Lock to current physical orientation
                            final orientation = MediaQuery.of(context).orientation;
                            if (orientation == Orientation.landscape) {
                              SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
                            } else {
                              SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
                            }
                          } else {
                            SystemChrome.setPreferredOrientations(DeviceOrientation.values);
                          }
                        });
                      }),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(iconSize: 28, icon: const Icon(Icons.replay_10, color: Colors.white), onPressed: () => _ctrl?.seekBy(const Duration(seconds: -10))), const SizedBox(width: 16),
                      IconButton(iconSize: 42, icon: AnimatedIcon(icon: AnimatedIcons.play_pause, progress: _playPauseAnimController, color: Colors.white), onPressed: () => _ctrl?.togglePlayPause()), const SizedBox(width: 16),
                      IconButton(iconSize: 28, icon: const Icon(Icons.forward_10, color: Colors.white), onPressed: () => _ctrl?.seekBy(const Duration(seconds: 10))),
                    ],
                  ),
                  Row(children: [TextButton(onPressed: () { setState(() { _fitMode = _fitMode == VideoFitMode.fit ? VideoFitMode.crop : (_fitMode == VideoFitMode.crop ? VideoFitMode.stretch : VideoFitMode.fit); _ctrl?.setAspectRatio(_fitMode.index); }); }, child: const Text('FIT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))],),
                ],
              )
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRightPanelContent() {
    switch (_activePanel) {
      case ActivePanel.audio:
        final tracks = _ctrl?.value.audioTracks ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPanelHeader('Audio'),
            if (tracks.isEmpty) const Padding(padding: EdgeInsets.only(left: 16), child: Text('No tracks available', style: TextStyle(color: Colors.white54))),
            ...tracks.map((t) => _buildCheckboxListTile('${t.language.toUpperCase()} — ${t.label}', t.isSelected, () { _ctrl?.selectTrack(t, true); setState((){}); })),
            const Divider(color: Color(0xFF2C2C2E), height: 32),
            _buildDelayAdjuster('Synchronization', _audioDelayMs, (v) { setState(() => _audioDelayMs = v); _ctrl?.setAudioDelay(v.toInt()); }),
          ],
        );
      case ActivePanel.cc:
        final tracks = _ctrl?.value.subtitleTracks ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPanelHeader('Subtitle'),
            ListTile(title: const Text('Off', style: TextStyle(color: Colors.white)), onTap: () { _ctrl?.disableSubtitles(); setState((){}); }),
            ...tracks.map((t) => _buildCheckboxListTile('${t.language.toUpperCase()} — ${t.label}', t.isSelected, () { _ctrl?.selectTrack(t, false); setState((){}); })),
            const Divider(color: Color(0xFF2C2C2E), height: 32),
            _buildDelayAdjuster('Synchronization', _ccDelayMs, (v) { setState(() => _ccDelayMs = v); _ctrl?.setSubtitleDelay(v.toInt()); }),
            const Divider(color: Color(0xFF2C2C2E), height: 32),
            ListTile(title: const Text('Subtitles Customization', style: TextStyle(color: Colors.white, fontSize: 15)), trailing: const Icon(Icons.chevron_right, color: Colors.white), onTap: () => setState(() => _activePanel = ActivePanel.ccCustomization))
          ],
        );
      case ActivePanel.ccCustomization:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => setState(()=> _activePanel = ActivePanel.cc)), const Text('Subtitles Customization', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))]),
            const SizedBox(height: 16), const Padding(padding: EdgeInsets.only(left: 16.0), child: Text('Layout', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(children: [const Text('Bottom margins', style: TextStyle(color: Colors.grey)), Expanded(child: SliderTheme(data: const SliderThemeData(activeTrackColor: Colors.grey, inactiveTrackColor: Color(0xFF2C2C2E), thumbColor: Color(0xFF4285F4)), child: Slider(value: _ccBottomMargin, min: 0, max: 50, onChanged: (v) => setState(()=> _ccBottomMargin = v)))), Text('${_ccBottomMargin.toInt()}', style: const TextStyle(color: Colors.white))]),
            ),
            Theme(data: Theme.of(context).copyWith(unselectedWidgetColor: Colors.grey), child: CheckboxListTile(title: const Text('Background', style: TextStyle(color: Colors.white)), value: _ccHasBackground, onChanged: (v) { if (v != null) setState(()=> _ccHasBackground = v); }, controlAffinity: ListTileControlAffinity.leading, contentPadding: const EdgeInsets.symmetric(horizontal: 8))),
          ],
        );
      case ActivePanel.more:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPanelHeader('More Settings'),
            ListTile(leading: const Icon(Icons.equalizer, color: Colors.white), title: const Text('Equalizer', style: TextStyle(color: Colors.white)), onTap: _showEqualizerDialog),
            ListTile(leading: const Icon(Icons.speed, color: Colors.white), title: const Text('Playback Speed', style: TextStyle(color: Colors.white)), onTap: (){}),
          ],
        );
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildPanelHeader(String title) {
    return Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 24), child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)));
  }

  Widget _buildCheckboxListTile(String title, bool isSelected, VoidCallback onTap) {
    return Theme(data: Theme.of(context).copyWith(unselectedWidgetColor: Colors.grey[700]), child: CheckboxListTile(title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15)), value: isSelected, onChanged: (_) => onTap(), controlAffinity: ListTileControlAffinity.leading, contentPadding: const EdgeInsets.symmetric(horizontal: 8)));
  }

  Widget _buildDelayAdjuster(String title, double value, Function(double) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 15)),
          Row(
            children: [
              InkWell(onTap: () => onChanged((value - 100).clamp(-5000.0, 5000.0)), child: const Icon(Icons.remove, color: Colors.white)), const SizedBox(width: 12),
              Container(width: 70, height: 36, alignment: Alignment.center, decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(4)), child: Text('${value.toInt()}ms', style: const TextStyle(color: Colors.white, fontSize: 16))), const SizedBox(width: 12),
              InkWell(onTap: () => onChanged((value + 100).clamp(-5000.0, 5000.0)), child: const Icon(Icons.add, color: Colors.white)),
            ],
          )
        ],
      ),
    );
  }
}

class _TriangleArrows extends StatefulWidget {
  final bool isForward;
  const _TriangleArrows({super.key, required this.isForward});
  @override
  State<_TriangleArrows> createState() => _TriangleArrowsState();
}

class _TriangleArrowsState extends State<_TriangleArrows> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(); }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            double fade = (_ctrl.value - (index * 0.2)) * 3;
            if (fade < 0) fade = 0; if (fade > 1) fade = 1 - (fade - 1);
            fade = fade.clamp(0.0, 1.0);
            Widget arrow = Icon(Icons.play_arrow, color: Colors.white.withValues(alpha: fade), size: 48);
            if (!widget.isForward) arrow = Transform.rotate(angle: pi, child: arrow);
            return arrow; 
          }).toList()..replaceRange(0, 3, widget.isForward ? [_buildFadingTriangle(0), _buildFadingTriangle(1), _buildFadingTriangle(2)] : [_buildFadingTriangle(2), _buildFadingTriangle(1), _buildFadingTriangle(0)]),
        );
      },
    );
  }
  
  Widget _buildFadingTriangle(int index) {
    double fade = (_ctrl.value - (index * 0.2)) * 3;
    if (fade < 0) fade = 0; if (fade > 1) fade = 2 - fade;
    fade = fade.clamp(0.0, 1.0);
    Widget arrow = Icon(Icons.play_arrow, color: Colors.white.withValues(alpha: fade), size: 48);
    if (!widget.isForward) arrow = Transform.rotate(angle: pi, child: arrow);
    return arrow;
  }
}
