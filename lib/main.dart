import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'features/viewer/core/viewer_registry.dart';
import 'features/viewer/plugins/image_viewer_plugin.dart';
import 'features/viewer/plugins/video_viewer_plugin.dart';
import 'features/viewer/plugins/text_viewer_plugin.dart';
import 'features/viewer/plugins/pdf_viewer_plugin.dart';
import 'features/viewer/thumbnail/isolate/isolate_pool.dart';
import 'features/viewer/thumbnail/adaptive/perf_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Register viewer plugins
  ViewerRegistry.register(ImageViewerPlugin());
  ViewerRegistry.register(VideoViewerPlugin());
  ViewerRegistry.register(TextViewerPlugin());
  ViewerRegistry.register(PdfViewerPlugin());

  // Init isolate pool — scale to device cores
  final cores = Platform.numberOfProcessors;
  final poolSize = (cores / 2).ceil().clamp(1, 4);
  await IsolatePool.init(size: poolSize);

  // Start adaptive performance controller
  PerfController.start();

  runApp(const ProviderScope(child: MyApp()));
}
