import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'presentation/debug_ui/file_browser_debug.dart';

void main() {
  runApp(
    const ProviderScope(
      child: DecentralFileManagerApp(),
    ),
  );
}

class DecentralFileManagerApp extends StatelessWidget {
  const DecentralFileManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Decentral File Manager',
      theme: ThemeData.dark(),
      home: const FileBrowserDebug(),
    );
  }
}
