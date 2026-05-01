import 'dart:io';
import 'package:flutter/material.dart';

class TextViewer extends StatelessWidget {
  final String path;
  const TextViewer({super.key, required this.path});

  @override
  Widget build(BuildContext context) {
    final content = File(path).readAsStringSync();
    return Scaffold(
      appBar: AppBar(title: Text(path.split('/').last)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: SelectableText(
          content,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
        ),
      ),
    );
  }
}
