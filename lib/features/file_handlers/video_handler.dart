import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/models/file_entry.dart';
import '../../core/interfaces/storage_adapter.dart';
import '../../core/utils/path_utils.dart';
import '../../services/video/video_player_controller.dart';
import 'file_handler.dart';

// ─── MX Player Color Palette ──────────────────────────────────────────────────
const _kOrange = Color(0xFFFF8C00);
const _kOrangeDim = Color(0x99FF8C00);
const _kDarkOverlay = Color(0xCC000000);
const _kSurfaceOverlay = Color(0xDD1A1A1A);

// ─── Constants ────────────────────────────────────────────────────────────────
const _kSeekSeconds = 10;
const _kHideDelay = Duration(seconds: 3);
const _kFeedbackDuration = Duration(milliseconds: 900);

enum _GestureAxis { none, horizontal, vertical }
enum _TapZone { left, center, right }

// ─── File Handler ─────────────────────────────────────────────────────────────
class VideoHandler implements FileHandler {
  final List<String> _exts = ['mp4', 'mkv', 'webm', 'avi', 'mov', 'flv', 'ts', 'wmv', 'm4v', '3gp'];

  @override
  bool canHandle(FileEntry entry) => _exts.contains(PathUtils.getExtension(entry.path));

  @override
  Widget buildPreview(FileEntry entry, StorageAdapter adapter) =>
      const Icon(Icons.movie, color: Colors.indigo);

  @override
  Future<void> open(BuildContext context, FileEntry entry, StorageAdapter adapter) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => VideoPlayerScreen(entry: entry)),
    );
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class VideoPlayerScreen extends StatefulWidget {
  final FileEntry entry;
  const VideoPlayerScreen({super.key, required this.entry});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  // Controller
  VideoPlayerController? _ctrl;

  // UI State
  bool _showControls = true;
  bool _isLocked = false;
  bool _showLockButton = false;
  Timer? _hideTimer;

  // Double-tap seek animation
  bool _showLeftSeek = false;
  bool _showRightSeek = false;
  int _leftSeekCount = 1;
  int _rightSeekCount = 1;
  Timer? _leftSeekTimer;
  Timer? _rightSeekTimer;

  // Gesture state
  _GestureAxis _axis = _GestureAxis.none;
  Offset _dragStart = Offset.zero;
  bool _isLeftSide = false;
  Duration _seekStartPos = Duration.zero;
  Duration _seekTarget = Duration.zero;

  // A/V values
  double _volume = 0.5;
  double _brightness = 0.5;

  // Visual feedback overlay
  bool _showFeedback = false;
  String _feedbackText = '';
  IconData? _feedbackIcon;
  double? _feedbackValue; // 0.0-1.0 for vertical bar
  Timer? _feedbackTimer;

  // Scrubber
  double? _scrubValue;

  // Speed
  double _speed = 1.0;

  // Aspect ratio
  int _aspectMode = 0;
  static const _aspectLabels = ['Fit', 'Fill', 'Crop'];
  static const _aspectIcons = [Icons.fit_screen, Icons.aspect_ratio, Icons.crop];

  // Orientation
  bool _isLandscape = true;

  // Subtitle delay
  int _subDelayMs = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _forceLandscape();
    _scheduleHide();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _ctrl?.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    _feedbackTimer?.cancel();
    _leftSeekTimer?.cancel();
    _rightSeekTimer?.cancel();
    _ctrl?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _onViewCreated(int id) {
    setState(() => _ctrl = VideoPlayerController(id));
  }

  // ─── Orientation ────────────────────────────────────────────────────────
  void _forceLandscape() {
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    _isLandscape = true;
  }

  void _toggleOrientation() {
    if (_isLandscape) {
      SystemChrome.setPreferredOrientations(
          [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
    } else {
      SystemChrome.setPreferredOrientations(
          [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    }
    setState(() => _isLandscape = !_isLandscape);
  }

  // ─── Control visibility ──────────────────────────────────────────────────
  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_kHideDelay, () {
      if (mounted) setState(() { _showControls = false; _showLockButton = false; });
    });
  }

  void _showControlsNow() {
    setState(() {
      if (_isLocked) {
        _showLockButton = true;
        _showControls = false;
      } else {
        _showControls = true;
      }
    });
    _scheduleHide();
  }

  void _hideControlsNow() {
    _hideTimer?.cancel();
    setState(() { _showControls = false; _showLockButton = false; });
  }

  // ─── Gesture Feedback overlay ────────────────────────────────────────────
  void _showFeedbackOverlay({
    required String text,
    required IconData icon,
    double? value,
  }) {
    _feedbackTimer?.cancel();
    setState(() {
      _showFeedback = true;
      _feedbackText = text;
      _feedbackIcon = icon;
      _feedbackValue = value;
    });
    _feedbackTimer = Timer(_kFeedbackDuration, () {
      if (mounted) setState(() => _showFeedback = false);
    });
  }

  // ─── Double-tap seek animation ───────────────────────────────────────────
  void _triggerDoubleTap(_TapZone zone) {
    if (zone == _TapZone.left) {
      _ctrl?.seekBy(const Duration(seconds: -_kSeekSeconds));
      _leftSeekTimer?.cancel();
      setState(() { _showLeftSeek = true; _leftSeekCount++; });
      _leftSeekTimer = Timer(const Duration(milliseconds: 800), () {
        if (mounted) setState(() { _showLeftSeek = false; _leftSeekCount = 1; });
      });
    } else if (zone == _TapZone.right) {
      _ctrl?.seekBy(const Duration(seconds: _kSeekSeconds));
      _rightSeekTimer?.cancel();
      setState(() { _showRightSeek = true; _rightSeekCount++; });
      _rightSeekTimer = Timer(const Duration(milliseconds: 800), () {
        if (mounted) setState(() { _showRightSeek = false; _rightSeekCount = 1; });
      });
    } else {
      _ctrl?.togglePlayPause();
    }
  }

  // ─── Pan gestures ────────────────────────────────────────────────────────
  void _onPanStart(DragStartDetails d) {
    if (_isLocked || _ctrl == null) return;
    _dragStart = d.globalPosition;
    _axis = _GestureAxis.none;
    _seekStartPos = _ctrl!.value.position;
    final w = MediaQuery.of(context).size.width;
    _isLeftSide = d.globalPosition.dx < w / 2;
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_isLocked || _ctrl == null) return;
    final dx = d.globalPosition.dx - _dragStart.dx;
    final dy = d.globalPosition.dy - _dragStart.dy;

    if (_axis == _GestureAxis.none) {
      if (dx.abs() > 18) { _axis = _GestureAxis.horizontal; }
      else if (dy.abs() > 18) { _axis = _GestureAxis.vertical; }
    }

    if (_axis == _GestureAxis.horizontal) {
      final w = MediaQuery.of(context).size.width;
      final dur = _ctrl!.value.duration;
      final pct = (dx / w) * 0.35;
      _seekTarget = _seekStartPos + Duration(milliseconds: (dur.inMilliseconds * pct).toInt());
      _seekTarget = Duration(milliseconds: _seekTarget.inMilliseconds.clamp(0, dur.inMilliseconds));
      final delta = _seekTarget - _seekStartPos;
      final s = delta.inSeconds;
      final sign = s >= 0 ? '+' : '';
      setState(() {});
      _showFeedbackOverlay(
        text: '$sign${s}s\n${_fmt(_seekTarget)}',
        icon: s >= 0 ? Icons.fast_forward_rounded : Icons.fast_rewind_rounded,
      );
    } else if (_axis == _GestureAxis.vertical) {
      final h = MediaQuery.of(context).size.height;
      final delta = -(d.delta.dy / h) * 1.5;

      if (_isLeftSide) {
        _brightness = (_brightness + delta).clamp(0.0, 1.0);
        _ctrl?.setBrightness(_brightness);
        _showFeedbackOverlay(
          text: '${(_brightness * 100).toInt()}%',
          icon: _brightness > 0.6 ? Icons.brightness_high : Icons.brightness_medium,
          value: _brightness,
        );
      } else {
        _volume = (_volume + delta).clamp(0.0, 1.0);
        _ctrl?.setVolume(_volume);
        _showFeedbackOverlay(
          text: '${(_volume * 100).toInt()}%',
          icon: _volume > 0.6 ? Icons.volume_up : _volume > 0.1 ? Icons.volume_down : Icons.volume_off,
          value: _volume,
        );
      }
    }
  }

  void _onPanEnd(DragEndDetails _) {
    if (_axis == _GestureAxis.horizontal) {
      _ctrl?.seekTo(_seekTarget);
    }
    setState(() { _axis = _GestureAxis.none; _feedbackTimer?.cancel(); _showFeedback = false; });
  }

  // ─── Long press (2x speed) ───────────────────────────────────────────────
  void _onLongPressStart(LongPressStartDetails _) {
    if (_isLocked || _ctrl == null) return;
    HapticFeedback.lightImpact();
    _ctrl?.setSpeed(2.0);
    _showFeedbackOverlay(text: '2× Speed', icon: Icons.speed, value: null);
    _feedbackTimer?.cancel(); // keep it showing
    setState(() { _showFeedback = true; _feedbackText = '2× Speed'; _feedbackIcon = Icons.speed; _feedbackValue = null; });
  }

  void _onLongPressEnd(LongPressEndDetails _) {
    if (_isLocked || _ctrl == null) return;
    _ctrl?.setSpeed(_speed);
    setState(() => _showFeedback = false);
  }

  // ─── Bottom Sheets ───────────────────────────────────────────────────────
  void _showSpeedPanel() {
    _hideTimer?.cancel();
    showModalBottomSheet(
      context: context,
      backgroundColor: _kSurfaceOverlay,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _SpeedSheet(
        current: _speed,
        onSelect: (s) {
          setState(() => _speed = s);
          _ctrl?.setSpeed(s);
          Navigator.pop(context);
          _showFeedbackOverlay(text: '${s}x', icon: Icons.speed);
        },
      ),
    ).then((_) => _scheduleHide());
  }

  void _showAudioPanel() {
    _hideTimer?.cancel();
    final tracks = _ctrl?.value.audioTracks ?? [];
    showModalBottomSheet(
      context: context,
      backgroundColor: _kSurfaceOverlay,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _TrackSheet(
        title: 'Audio Tracks',
        tracks: tracks,
        onSelect: (t) { _ctrl?.selectTrack(t, true); Navigator.pop(context); },
      ),
    ).then((_) => _scheduleHide());
  }

  void _showSubtitlePanel() {
    _hideTimer?.cancel();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _kSurfaceOverlay,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _SubtitleSheet(
        tracks: _ctrl?.value.subtitleTracks ?? [],
        delayMs: _subDelayMs,
        onSelectTrack: (t) { _ctrl?.selectTrack(t, false); Navigator.pop(ctx); },
        onDisable: () { _ctrl?.disableSubtitles(); Navigator.pop(ctx); },
        onDelayChanged: (ms) {
          setState(() => _subDelayMs = ms);
          _ctrl?.setSubtitleDelay(ms);
        },
      ),
    ).then((_) => _scheduleHide());
  }

  // ─── Build ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // ── Native ExoPlayer surface ─────────────────────────────────
            AndroidView(
              viewType: 'com.app.argusarchive/video_player',
              creationParams: {'path': widget.entry.path},
              creationParamsCodec: const StandardMessageCodec(),
              onPlatformViewCreated: _onViewCreated,
            ),

            // ── Dark gradient overlay when controls visible ───────────────
            if (_showControls) ...[
              // Top gradient
              Positioned(
                top: 0, left: 0, right: 0, height: 140,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black87, Colors.transparent],
                    ),
                  ),
                ),
              ),
              // Bottom gradient
              Positioned(
                bottom: 0, left: 0, right: 0, height: 160,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black87, Colors.transparent],
                    ),
                  ),
                ),
              ),
            ],

            // ── Three-zone gesture layer ──────────────────────────────────
            _GestureZoneLayer(
              isLocked: _isLocked,
              onTapZone: (zone) {
                if (_showControls || _showLockButton) {
                  _hideControlsNow();
                } else {
                  _showControlsNow();
                }
              },
              onDoubleTapZone: _triggerDoubleTap,
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              onLongPressStart: _onLongPressStart,
              onLongPressEnd: _onLongPressEnd,
            ),

            // ── Double-tap seek ripples ───────────────────────────────────
            if (_showLeftSeek) _SeekRipple(isLeft: true, seconds: _leftSeekCount * _kSeekSeconds),
            if (_showRightSeek) _SeekRipple(isLeft: false, seconds: _rightSeekCount * _kSeekSeconds),

            // ── Gesture feedback (volume / brightness / seek) ─────────────
            if (_showFeedback) _FeedbackPill(text: _feedbackText, icon: _feedbackIcon, value: _feedbackValue),

            // ── Top controls bar ──────────────────────────────────────────
            if (_showControls && !_isLocked)
              Positioned(
                top: 0, left: 0, right: 0,
                child: SafeArea(child: _TopBar(
                  title: PathUtils.getName(widget.entry.path),
                  onBack: () => Navigator.of(context).pop(),
                  onPiP: () => _ctrl?.enterPiP(),
                  onSpeed: _showSpeedPanel,
                  speed: _speed,
                )),
              ),

            // ── Center play/pause (only when controls visible) ────────────
            if (_showControls && !_isLocked && _ctrl != null)
              Center(child: _CenterControls(stream: _ctrl!.stateStream, ctrl: _ctrl!)),

            // ── Bottom controls bar ───────────────────────────────────────
            if (_showControls && !_isLocked && _ctrl != null)
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: SafeArea(
                  child: _BottomBar(
                    stream: _ctrl!.stateStream,
                    ctrl: _ctrl!,
                    aspectMode: _aspectMode,
                    aspectIcons: _aspectIcons,
                    aspectLabels: _aspectLabels,
                    isLandscape: _isLandscape,
                    scrubValue: _scrubValue,
                    onScrubStart: (v) { _hideTimer?.cancel(); setState(() => _scrubValue = v); },
                    onScrubChanged: (v) => setState(() => _scrubValue = v),
                    onScrubEnd: (v) {
                      _ctrl?.seekTo(Duration(milliseconds: v.toInt()));
                      setState(() => _scrubValue = null);
                      _scheduleHide();
                    },
                    onLock: () {
                      setState(() { _isLocked = true; _showControls = false; });
                      _hideTimer?.cancel();
                    },
                    onAspectRatio: () {
                      final next = (_aspectMode + 1) % 3;
                      setState(() => _aspectMode = next);
                      _ctrl?.setAspectRatio(next);
                      _showFeedbackOverlay(text: _aspectLabels[next], icon: _aspectIcons[next]);
                    },
                    onRotate: _toggleOrientation,
                    onAudio: _showAudioPanel,
                    onSubtitle: _showSubtitlePanel,
                  ),
                ),
              ),

            // ── Lock overlay ──────────────────────────────────────────────
            if (_isLocked && _showLockButton)
              Positioned(
                left: 24, top: 0, bottom: 0,
                child: Center(
                  child: _LockButton(onUnlock: () {
                    setState(() { _isLocked = false; _showLockButton = false; _showControls = true; });
                    _scheduleHide();
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Gesture Zone Layer ───────────────────────────────────────────────────────
class _GestureZoneLayer extends StatefulWidget {
  final bool isLocked;
  final void Function(_TapZone) onTapZone;
  final void Function(_TapZone) onDoubleTapZone;
  final void Function(DragStartDetails) onPanStart;
  final void Function(DragUpdateDetails) onPanUpdate;
  final void Function(DragEndDetails) onPanEnd;
  final void Function(LongPressStartDetails) onLongPressStart;
  final void Function(LongPressEndDetails) onLongPressEnd;

  const _GestureZoneLayer({
    required this.isLocked,
    required this.onTapZone,
    required this.onDoubleTapZone,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
    required this.onLongPressStart,
    required this.onLongPressEnd,
  });

  @override
  State<_GestureZoneLayer> createState() => _GestureZoneLayerState();
}

class _GestureZoneLayerState extends State<_GestureZoneLayer> {
  // Per-zone double-tap tracking
  Timer? _leftTapTimer;
  Timer? _rightTapTimer;
  Timer? _centerTapTimer;
  int _leftTaps = 0;
  int _rightTaps = 0;
  int _centerTaps = 0;

  void _handleTap(double dx, double width) {
    final pct = dx / width;
    _TapZone zone;
    if (pct < 0.33) {
      zone = _TapZone.left;
    } else if (pct > 0.67) {
      zone = _TapZone.right;
    } else {
      zone = _TapZone.center;
    }

    if (zone == _TapZone.left) {
      _leftTaps++;
      _leftTapTimer?.cancel();
      if (_leftTaps >= 2) {
        _leftTaps = 0;
        widget.onDoubleTapZone(_TapZone.left);
      } else {
        _leftTapTimer = Timer(const Duration(milliseconds: 280), () {
          if (_leftTaps == 1) widget.onTapZone(_TapZone.left);
          _leftTaps = 0;
        });
      }
    } else if (zone == _TapZone.right) {
      _rightTaps++;
      _rightTapTimer?.cancel();
      if (_rightTaps >= 2) {
        _rightTaps = 0;
        widget.onDoubleTapZone(_TapZone.right);
      } else {
        _rightTapTimer = Timer(const Duration(milliseconds: 280), () {
          if (_rightTaps == 1) widget.onTapZone(_TapZone.right);
          _rightTaps = 0;
        });
      }
    } else {
      _centerTaps++;
      _centerTapTimer?.cancel();
      if (_centerTaps >= 2) {
        _centerTaps = 0;
        widget.onDoubleTapZone(_TapZone.center);
      } else {
        _centerTapTimer = Timer(const Duration(milliseconds: 280), () {
          if (_centerTaps == 1) widget.onTapZone(_TapZone.center);
          _centerTaps = 0;
        });
      }
    }
  }

  @override
  void dispose() {
    _leftTapTimer?.cancel();
    _rightTapTimer?.cancel();
    _centerTapTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapUp: (d) => _handleTap(d.localPosition.dx, constraints.maxWidth),
          onPanStart: widget.onPanStart,
          onPanUpdate: widget.onPanUpdate,
          onPanEnd: widget.onPanEnd,
          onLongPressStart: widget.onLongPressStart,
          onLongPressEnd: widget.onLongPressEnd,
          onLongPressCancel: () => widget.onLongPressEnd(const LongPressEndDetails()),
          child: Container(color: Colors.transparent),
        );
      },
    );
  }
}

// ─── Seek Ripple Widget ───────────────────────────────────────────────────────
class _SeekRipple extends StatefulWidget {
  final bool isLeft;
  final int seconds;
  const _SeekRipple({required this.isLeft, required this.seconds});

  @override
  State<_SeekRipple> createState() => _SeekRippleState();
}

class _SeekRippleState extends State<_SeekRipple> with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _scale = Tween(begin: 0.6, end: 1.1).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));
    _fade = Tween(begin: 0.85, end: 0.0).animate(CurvedAnimation(parent: _anim, curve: Curves.easeIn));
    _anim.forward();
  }

  @override
  void dispose() { _anim.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0, bottom: 0,
      left: widget.isLeft ? 0 : null,
      right: widget.isLeft ? null : 0,
      width: MediaQuery.of(context).size.width * 0.35,
      child: Center(
        child: AnimatedBuilder(
          animation: _anim,
          builder: (_, __) => Opacity(
            opacity: _fade.value,
            child: Transform.scale(
              scale: _scale.value,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        3,
                        (i) => Icon(
                          widget.isLeft ? Icons.chevron_left : Icons.chevron_right,
                          color: Colors.white.withValues(alpha: (0.4 + i * 0.3).clamp(0, 1)),
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.seconds}s',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Feedback Pill ────────────────────────────────────────────────────────────
class _FeedbackPill extends StatelessWidget {
  final String text;
  final IconData? icon;
  final double? value; // 0-1 for vertical bar

  const _FeedbackPill({required this.text, this.icon, this.value});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: _kDarkOverlay,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: _kOrange, size: 30),
              const SizedBox(width: 10),
            ],
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                  ),
                ),
                if (value != null) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 120,
                    height: 4,
                    child: LinearProgressIndicator(
                      value: value,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation(_kOrange),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Top Bar ──────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final VoidCallback onPiP;
  final VoidCallback onSpeed;
  final double speed;

  const _TopBar({
    required this.title,
    required this.onBack,
    required this.onPiP,
    required this.onSpeed,
    required this.speed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: onBack,
          ),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Speed indicator button
          GestureDetector(
            onTap: onSpeed,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: speed != 1.0 ? _kOrange.withValues(alpha: 0.3) : Colors.white12,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: speed != 1.0 ? _kOrange : Colors.transparent,
                ),
              ),
              child: Text(
                '${speed}x',
                style: TextStyle(
                  color: speed != 1.0 ? _kOrange : Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.picture_in_picture_alt, color: Colors.white),
            onPressed: onPiP,
            tooltip: 'Picture in Picture',
          ),
        ],
      ),
    );
  }
}

// ─── Center Controls ──────────────────────────────────────────────────────────
class _CenterControls extends StatelessWidget {
  final Stream<VideoPlaybackState> stream;
  final VideoPlayerController ctrl;

  const _CenterControls({required this.stream, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<VideoPlaybackState>(
      stream: stream,
      builder: (_, snap) {
        final state = snap.data ?? const VideoPlaybackState();
        if (state.isBuffering) {
          return const SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(color: _kOrange, strokeWidth: 3),
          );
        }
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CircleIconBtn(
              icon: Icons.replay_10,
              size: 36,
              onTap: () => ctrl.seekBy(const Duration(seconds: -10)),
            ),
            const SizedBox(width: 24),
            GestureDetector(
              onTap: ctrl.togglePlayPause,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white30, width: 1.5),
                ),
                child: Icon(
                  state.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 44,
                ),
              ),
            ),
            const SizedBox(width: 24),
            _CircleIconBtn(
              icon: Icons.forward_10,
              size: 36,
              onTap: () => ctrl.seekBy(const Duration(seconds: 10)),
            ),
          ],
        );
      },
    );
  }
}

class _CircleIconBtn extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;

  const _CircleIconBtn({required this.icon, required this.size, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: size),
      ),
    );
  }
}

// ─── Bottom Bar ───────────────────────────────────────────────────────────────
class _BottomBar extends StatelessWidget {
  final Stream<VideoPlaybackState> stream;
  final VideoPlayerController ctrl;
  final int aspectMode;
  final List<IconData> aspectIcons;
  final List<String> aspectLabels;
  final bool isLandscape;
  final double? scrubValue;
  final void Function(double) onScrubStart;
  final void Function(double) onScrubChanged;
  final void Function(double) onScrubEnd;
  final VoidCallback onLock;
  final VoidCallback onAspectRatio;
  final VoidCallback onRotate;
  final VoidCallback onAudio;
  final VoidCallback onSubtitle;

  const _BottomBar({
    required this.stream,
    required this.ctrl,
    required this.aspectMode,
    required this.aspectIcons,
    required this.aspectLabels,
    required this.isLandscape,
    required this.scrubValue,
    required this.onScrubStart,
    required this.onScrubChanged,
    required this.onScrubEnd,
    required this.onLock,
    required this.onAspectRatio,
    required this.onRotate,
    required this.onAudio,
    required this.onSubtitle,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<VideoPlaybackState>(
      stream: stream,
      builder: (_, snap) {
        final state = snap.data ?? const VideoPlaybackState();
        final maxMs = state.duration.inMilliseconds.toDouble();
        final bufMs = state.buffered.inMilliseconds.toDouble();
        final curMs = scrubValue ?? state.position.inMilliseconds.toDouble();
        final safeMax = maxMs > 0 ? maxMs : 1.0;

        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Progress row
              Row(
                children: [
                  Text(_fmt(Duration(milliseconds: curMs.toInt())),
                      style: const TextStyle(color: Colors.white, fontSize: 12)),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        activeTrackColor: _kOrange,
                        inactiveTrackColor: Colors.white24,
                        secondaryActiveTrackColor: Colors.white38,
                        thumbColor: _kOrange,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                        overlayColor: _kOrangeDim,
                      ),
                      child: Slider(
                        min: 0,
                        max: safeMax,
                        secondaryTrackValue: bufMs.clamp(0, safeMax),
                        value: curMs.clamp(0, safeMax),
                        onChangeStart: onScrubStart,
                        onChanged: onScrubChanged,
                        onChangeEnd: onScrubEnd,
                      ),
                    ),
                  ),
                  Text(_fmt(state.duration),
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
              // Controls row
              Row(
                children: [
                  _BarBtn(icon: Icons.lock_open_rounded, onTap: onLock, tooltip: 'Lock'),
                  _BarBtn(
                    icon: isLandscape ? Icons.screen_lock_landscape : Icons.screen_lock_portrait,
                    onTap: onRotate,
                    tooltip: 'Rotate',
                  ),
                  _BarBtn(icon: Icons.audiotrack, onTap: onAudio, tooltip: 'Audio'),
                  _BarBtn(icon: Icons.subtitles_outlined, onTap: onSubtitle, tooltip: 'Subtitles'),
                  const Spacer(),
                  _BarBtn(icon: aspectIcons[aspectMode], onTap: onAspectRatio, tooltip: aspectLabels[aspectMode]),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BarBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  const _BarBtn({required this.icon, required this.onTap, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 22),
        onPressed: onTap,
        padding: const EdgeInsets.all(6),
      ),
    );
  }
}

// ─── Lock Button ──────────────────────────────────────────────────────────────
class _LockButton extends StatelessWidget {
  final VoidCallback onUnlock;
  const _LockButton({required this.onUnlock});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onUnlock,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _kDarkOverlay,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white24),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock, color: Colors.white, size: 28),
            SizedBox(height: 4),
            Text('Tap to\nunlock', textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

// ─── Speed Sheet ─────────────────────────────────────────────────────────────
class _SpeedSheet extends StatelessWidget {
  final double current;
  final void Function(double) onSelect;
  static const _speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0, 4.0];

  const _SpeedSheet({required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Playback Speed',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _speeds.map((s) {
                final selected = s == current;
                return GestureDetector(
                  onTap: () => onSelect(s),
                  child: Container(
                    width: 72,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: selected ? _kOrange : Colors.white12,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected ? _kOrange : Colors.white24,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      '${s}x',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.white70,
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─── Track Sheet ──────────────────────────────────────────────────────────────
class _TrackSheet extends StatelessWidget {
  final String title;
  final List<VideoTrack> tracks;
  final void Function(VideoTrack) onSelect;

  const _TrackSheet({required this.title, required this.tracks, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Text(title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
            const Divider(height: 1, color: Colors.white12),
            if (tracks.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No tracks available', style: TextStyle(color: Colors.white54)),
              )
            else
              ...tracks.map((t) => ListTile(
                    leading: Icon(
                      t.isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: t.isSelected ? _kOrange : Colors.white54,
                    ),
                    title: Text(
                      '${t.language.toUpperCase()} — ${t.label}',
                      style: TextStyle(
                        color: t.isSelected ? _kOrange : Colors.white,
                        fontWeight: t.isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    onTap: () => onSelect(t),
                  )),
          ],
        ),
      ),
    );
  }
}

// ─── Subtitle Sheet ──────────────────────────────────────────────────────────
class _SubtitleSheet extends StatefulWidget {
  final List<VideoTrack> tracks;
  final int delayMs;
  final void Function(VideoTrack) onSelectTrack;
  final VoidCallback onDisable;
  final void Function(int) onDelayChanged;

  const _SubtitleSheet({
    required this.tracks,
    required this.delayMs,
    required this.onSelectTrack,
    required this.onDisable,
    required this.onDelayChanged,
  });

  @override
  State<_SubtitleSheet> createState() => _SubtitleSheetState();
}

class _SubtitleSheetState extends State<_SubtitleSheet> {
  late int _delay;

  @override
  void initState() { super.initState(); _delay = widget.delayMs; }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Subtitles',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 12),

            const Text('TRACK', style: TextStyle(fontSize: 11, color: _kOrange, fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(height: 8),

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.subtitles_off, color: Colors.white54),
              title: const Text('Off', style: TextStyle(color: Colors.white)),
              onTap: widget.onDisable,
            ),
            ...widget.tracks.map((t) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                t.isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: t.isSelected ? _kOrange : Colors.white54,
              ),
              title: Text(
                '${t.language.toUpperCase()} — ${t.label}',
                style: TextStyle(color: t.isSelected ? _kOrange : Colors.white),
              ),
              onTap: () => widget.onSelectTrack(t),
            )),

            const Divider(color: Colors.white12, height: 24),

            const Text('SYNC DELAY', style: TextStyle(fontSize: 11, color: _kOrange, fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _DelayBtn(
                  label: '−500ms',
                  onTap: () {
                    setState(() => _delay = (_delay - 500).clamp(-5000, 5000));
                    widget.onDelayChanged(_delay);
                  },
                ),
                const SizedBox(width: 8),
                _DelayBtn(
                  label: '−100ms',
                  onTap: () {
                    setState(() => _delay = (_delay - 100).clamp(-5000, 5000));
                    widget.onDelayChanged(_delay);
                  },
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_delay > 0 ? '+' : ''}$_delay ms',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _DelayBtn(
                  label: '+100ms',
                  onTap: () {
                    setState(() => _delay = (_delay + 100).clamp(-5000, 5000));
                    widget.onDelayChanged(_delay);
                  },
                ),
                const SizedBox(width: 8),
                _DelayBtn(
                  label: '+500ms',
                  onTap: () {
                    setState(() => _delay = (_delay + 500).clamp(-5000, 5000));
                    widget.onDelayChanged(_delay);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () {
                  setState(() => _delay = 0);
                  widget.onDelayChanged(0);
                },
                child: const Text('Reset', style: TextStyle(color: Colors.white54)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DelayBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _DelayBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24),
        ),
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ),
    );
  }
}

// ─── Helper ───────────────────────────────────────────────────────────────────
String _fmt(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  if (d.inHours > 0) return '${d.inHours}:${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}';
  return '${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}';
}
