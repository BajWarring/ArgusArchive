import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path/path.dart' as p;
import '../../core/models/file_entry.dart';
import '../../providers/video_history_provider.dart';

class VideoPlayerControllerScreen extends ConsumerStatefulWidget {
  final FileEntry file;
  const VideoPlayerControllerScreen({super.key, required this.file});

  @override
  ConsumerState<VideoPlayerControllerScreen> createState() => _VideoPlayerControllerScreenState();
}

class _VideoPlayerControllerScreenState extends ConsumerState<VideoPlayerControllerScreen> {
  late final Player _player;
  late final VideoController _controller;
  
  bool _showControls = true;
  Timer? _controlsTimer;
  
  // Custom Controls State
  double _audioDelayMs = 0;
  double _subtitleDelayMs = 0;
  final List<double> _equalizerBands = List.filled(10, 0.0);

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);

    _player = Player();
    _controller = VideoController(_player);
    
    _player.open(Media(widget.file.path));
    _startControlsTimer();
    
    _loadHistorySettings();
  }
  
  Future<void> _loadHistorySettings() async {
     final history = ref.read(videoHistoryProvider);
     final item = history.where((e) => e.path == widget.file.path).firstOrNull;
     
     if (item != null) {
       _audioDelayMs = item.audioDelayMs.toDouble();
       _subtitleDelayMs = item.subtitleDelayMs.toDouble();
       _player.setAudioDelay(Duration(milliseconds: item.audioDelayMs));
       _player.setSubtitleDelay(Duration(milliseconds: item.subtitleDelayMs));
       await _player.seek(Duration(milliseconds: item.positionMs));
     }
  }

  @override
  void dispose() {
    _saveHistory();
    _controlsTimer?.cancel();
    _player.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _saveHistory() {
    final item = VideoHistoryItem(
      path: widget.file.path,
      title: p.basename(widget.file.path),
      positionMs: _player.state.position.inMilliseconds,
      durationMs: _player.state.duration.inMilliseconds,
      audioTrackId: _player.state.track.audio.id,
      subtitleTrackId: _player.state.track.subtitle.id,
      audioDelayMs: _audioDelayMs.toInt(),
      subtitleDelayMs: _subtitleDelayMs.toInt(),
      lastPlayed: DateTime.now(),
    );
    ref.read(videoHistoryProvider.notifier).save(item);
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _startControlsTimer();
  }

  // --- Track Menus ---
  void _showTrackMenu(String title, List<Track> tracks, Track currentTrack, Function(Track) onSelect) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      builder: (ctx) => ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          ...tracks.map((t) => ListTile(
            title: Text(t.title ?? t.id, style: const TextStyle(color: Colors.white)),
            trailing: currentTrack.id == t.id ? const Icon(Icons.check, color: Colors.blue) : null,
            onTap: () {
              onSelect(t);
              Navigator.pop(ctx);
            },
          ))
        ],
      )
    );
  }

  // --- Custom Dialogs ---
  void _showDelayDialog(String title, double currentDelay, Function(double) onChanged) {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.grey.shade900,
            title: Text(title, style: const TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${currentDelay.toInt()} ms', style: const TextStyle(color: Colors.white, fontSize: 24)),
                Slider(
                  min: -5000, max: 5000, value: currentDelay,
                  onChanged: (v) {
                    setDialogState(() => currentDelay = v);
                    onChanged(v);
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(onPressed: () { setDialogState(() => currentDelay -= 100); onChanged(currentDelay); }, child: const Text('-100ms')),
                    TextButton(onPressed: () { setDialogState(() => currentDelay = 0); onChanged(currentDelay); }, child: const Text('Reset')),
                    TextButton(onPressed: () { setDialogState(() => currentDelay += 100); onChanged(currentDelay); }, child: const Text('+100ms')),
                  ],
                )
              ],
            ),
          );
        }
      )
    );
  }

  void _showEqualizerDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey.shade900,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            padding: const EdgeInsets.all(16),
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
                              min: -12.0, max: 12.0,
                              value: _equalizerBands[index],
                              onChanged: (v) {
                                setModalState(() => _equalizerBands[index] = v);
                                // MediaKit Equalizer logic (maps bands 0-9)
                                _player.setEqualizer(Equalizer(
                                  name: 'custom',
                                  bands: [EqualizerBand(_equalizerBands[index], (index + 1) * 100.0)],
                                ));
                              },
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
      context: context,
      backgroundColor: Colors.grey.shade900,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Cast to Device', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const ListTile(
              leading: Icon(Icons.tv, color: Colors.white),
              title: Text('Living Room TV', style: TextStyle(color: Colors.white)),
              subtitle: Text('Available', style: TextStyle(color: Colors.green)),
            ),
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
            const Center(child: Padding(
              padding: EdgeInsets.all(8.0),
              child: Text('Searching for devices...', style: TextStyle(color: Colors.white54)),
            ))
          ],
        ),
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            Center(child: Video(controller: _controller)),
            
            // --- Custom Overlay Controls ---
            if (_showControls) ...[
              Container(color: Colors.black54), // Dimmer
              
              // Top Bar
              Positioned(
                top: 20, left: 20, right: 20,
                child: Row(
                  children: [
                    IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
                    Expanded(child: Text(p.basename(widget.file.path), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), maxLines: 1)),
                    IconButton(icon: const Icon(Icons.cast, color: Colors.white), onPressed: _showCastDialog),
                    IconButton(
                      icon: const Icon(Icons.audiotrack, color: Colors.white),
                      onPressed: () => _showTrackMenu('Audio Tracks', _player.state.tracks.audio, _player.state.track.audio, (t) => _player.setAudioTrack(t as AudioTrack)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.subtitles, color: Colors.white),
                      onPressed: () => _showTrackMenu('Subtitle Tracks', _player.state.tracks.subtitle, _player.state.track.subtitle, (t) => _player.setSubtitleTrack(t as SubtitleTrack)),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                      color: Colors.grey.shade800,
                      onSelected: (val) {
                        if (val == 'audio_delay') _showDelayDialog('Audio Delay', _audioDelayMs, (v) { _audioDelayMs = v; _player.setAudioDelay(Duration(milliseconds: v.toInt())); });
                        if (val == 'cc_delay') _showDelayDialog('Subtitle Delay', _subtitleDelayMs, (v) { _subtitleDelayMs = v; _player.setSubtitleDelay(Duration(milliseconds: v.toInt())); });
                        if (val == 'eq') _showEqualizerDialog();
                      },
                      itemBuilder: (ctx) => const [
                        PopupMenuItem(value: 'audio_delay', child: Text('Adjust Audio Delay', style: TextStyle(color: Colors.white))),
                        PopupMenuItem(value: 'cc_delay', child: Text('Adjust Subtitle Delay', style: TextStyle(color: Colors.white))),
                        PopupMenuItem(value: 'eq', child: Text('Equalizer', style: TextStyle(color: Colors.white))),
                      ],
                    ),
                  ],
                ),
              ),

              // Bottom Playback Bar
              Positioned(
                bottom: 20, left: 20, right: 20,
                child: Column(
                  children: [
                    StreamBuilder<Duration>(
                      stream: _player.stream.position,
                      builder: (context, snapshot) {
                        final pos = snapshot.data ?? Duration.zero;
                        final dur = _player.state.duration;
                        return Row(
                          children: [
                            Text(pos.toString().split('.')[0], style: const TextStyle(color: Colors.white)),
                            Expanded(
                              child: Slider(
                                activeColor: Colors.blue,
                                min: 0,
                                max: dur.inMilliseconds.toDouble() > 0 ? dur.inMilliseconds.toDouble() : 1,
                                value: pos.inMilliseconds.toDouble().clamp(0, dur.inMilliseconds.toDouble() > 0 ? dur.inMilliseconds.toDouble() : 1),
                                onChanged: (v) => _player.seek(Duration(milliseconds: v.toInt())),
                              ),
                            ),
                            Text(dur.toString().split('.')[0], style: const TextStyle(color: Colors.white)),
                          ],
                        );
                      }
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(icon: const Icon(Icons.fast_rewind, color: Colors.white, size: 36), onPressed: () {
                          _player.seek(_player.state.position - const Duration(seconds: 10));
                        }),
                        StreamBuilder<bool>(
                          stream: _player.stream.playing,
                          builder: (context, snapshot) {
                            final isPlaying = snapshot.data ?? true;
                            return IconButton(
                              icon: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, color: Colors.white, size: 54),
                              onPressed: () => _player.playOrPause(),
                            );
                          }
                        ),
                        IconButton(icon: const Icon(Icons.fast_forward, color: Colors.white, size: 36), onPressed: () {
                          _player.seek(_player.state.position + const Duration(seconds: 10));
                        }),
                      ],
                    )
                  ],
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
