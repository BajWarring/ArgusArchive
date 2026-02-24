import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/models/file_entry.dart';
import '../../core/interfaces/storage_adapter.dart';
import '../../core/utils/path_utils.dart';
import '../../services/video/video_player_controller.dart';
import 'file_handler.dart';

class VideoHandler implements FileHandler {
  final List<String> _supportedExtensions = ['mp4', 'mkv', 'webm', 'avi', 'mov', 'flv'];

  @override
  bool canHandle(FileEntry entry) {
    return _supportedExtensions.contains(PathUtils.getExtension(entry.path));
  }

  @override
  Widget buildPreview(FileEntry entry, StorageAdapter adapter) {
    return const Icon(Icons.movie, color: Colors.indigo);
  }

  @override
  Future<void> open(BuildContext context, FileEntry entry, StorageAdapter adapter) async {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _VideoPlayerScreen(entry: entry),
      ),
    );
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

  void _onPlatformViewCreated(int id) {
    setState(() {
      _controller = VideoPlayerController(id);
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: Stack(
          children: [
            // 1. The Native ExoPlayer Surface
            AndroidView(
              viewType: 'com.app.argusarchive/video_player',
              creationParams: {'path': widget.entry.path},
              creationParamsCodec: const StandardMessageCodec(),
              onPlatformViewCreated: _onPlatformViewCreated,
            ),
            
            // 2. Custom Flutter API Controls Interface (Clean architecture, highly customizable)
            if (_showControls && _controller != null)
              _buildCustomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomControls() {
    return Container(
      color: Colors.black54,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(PathUtils.getName(widget.entry.path), style: const TextStyle(fontSize: 16)),
          ),
          
          StreamBuilder<VideoPlaybackState>(
            stream: _controller!.stateStream,
            builder: (context, snapshot) {
              final state = snapshot.data ?? VideoPlaybackState();
              
              return Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          iconSize: 48,
                          icon: const Icon(Icons.replay_10, color: Colors.white),
                          onPressed: () => _controller!.seekTo(state.position - const Duration(seconds: 10)),
                        ),
                        IconButton(
                          iconSize: 64,
                          icon: Icon(state.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, color: Colors.white),
                          onPressed: () => state.isPlaying ? _controller!.pause() : _controller!.play(),
                        ),
                        IconButton(
                          iconSize: 48,
                          icon: const Icon(Icons.forward_10, color: Colors.white),
                          onPressed: () => _controller!.seekTo(state.position + const Duration(seconds: 10)),
                        ),
                      ],
                    ),
                    Slider(
                      activeColor: Colors.tealAccent,
                      inactiveColor: Colors.white24,
                      min: 0,
                      max: state.duration.inMilliseconds.toDouble() > 0 ? state.duration.inMilliseconds.toDouble() : 1,
                      value: state.position.inMilliseconds.toDouble().clamp(0, state.duration.inMilliseconds.toDouble()),
                      onChanged: (val) {
                        _controller!.seekTo(Duration(milliseconds: val.toInt()));
                      },
                    ),
                  ],
                ),
              );
            }
          )
        ],
      ),
    );
  }
}
