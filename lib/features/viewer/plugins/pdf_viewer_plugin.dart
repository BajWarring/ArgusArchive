import 'package:flutter/material.dart';
import '../core/viewer_plugin.dart';
import '../viewers/pdf_viewer.dart';

class PdfViewerPlugin extends ViewerPlugin {
  @override
  String get id => 'pdf_viewer';

  @override
  List<String> get supportedExtensions => ['pdf'];

  @override
  int get priority => 10;

  @override
  Widget build(String path) => PdfViewerScreen(path: path);
}
