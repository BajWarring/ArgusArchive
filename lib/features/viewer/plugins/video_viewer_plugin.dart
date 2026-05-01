import 'package:flutter/material.dart';
import '../core/viewer_plugin.dart';
import '../viewers/video_viewer.dart';

class VideoViewerPlugin extends ViewerPlugin {
  @override
  String get id => 'video_viewer';

  @override
  List<String> get supportedExtensions => ['mp4', 'mkv', 'avi', 'mov', 'webm'];

  @override
  int get priority => 10;

  @override
  Widget build(String path) => VideoViewer(path: path);
}
