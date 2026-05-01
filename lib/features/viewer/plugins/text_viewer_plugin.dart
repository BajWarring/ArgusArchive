import 'package:flutter/material.dart';
import '../core/viewer_plugin.dart';
import '../viewers/text_viewer.dart';

class TextViewerPlugin extends ViewerPlugin {
  @override
  String get id => 'text_viewer';

  @override
  List<String> get supportedExtensions => [
        'txt', 'json', 'dart', 'js', 'py',
        'ts', 'md', 'yaml', 'yml', 'xml', 'html', 'css',
      ];

  @override
  int get priority => 5;

  @override
  Widget build(String path) => TextViewer(path: path);
}
