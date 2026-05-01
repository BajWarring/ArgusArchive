import 'package:flutter/material.dart';
import '../core/viewer_plugin.dart';
import '../viewers/image_viewer.dart';

class ImageViewerPlugin extends ViewerPlugin {
  @override
  String get id => 'image_viewer';

  @override
  List<String> get supportedExtensions => ['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp'];

  @override
  int get priority => 10;

  @override
  Widget build(String path) => ImageViewer(path: path);
}
