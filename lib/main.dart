import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'presentation/debug_ui/file_browser_debug.dart';

void main() {
  runApp(
    // Wrap the app in ProviderScope for Riverpod
    const ProviderScope(
      child: DecentralFileManagerApp(),
    ),
  );
}

class DecentralFileManagerApp extends StatelessWidget {
  const DecentralFileManagerApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Decentral File Manager',
      theme: ThemeData.dark(), // Fits the "debug" vibe perfectly
      home: const FileBrowserDebug(),
    );
  }
}
