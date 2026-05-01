import 'package:flutter/material.dart';

abstract class ViewerPlugin {
  /// Unique plugin ID
  String get id;

  /// Supported file extensions (lowercase, no dot)
  List<String> get supportedExtensions;

  /// Priority — higher wins when multiple plugins match the same extension
  int get priority => 0;

  /// Returns true if this plugin can open the file at [path]
  bool canHandle(String path) {
    final ext = path.split('.').last.toLowerCase();
    return supportedExtensions.contains(ext);
  }

  /// Build the viewer widget for [path]
  Widget build(String path);
}
