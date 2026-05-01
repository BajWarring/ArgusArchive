import 'package:flutter/material.dart';
import 'viewer_registry.dart';

class FileOpenerService {
  static void open(BuildContext context, String path) {
    final plugin = ViewerRegistry.getPlugin(path);
    if (plugin != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => plugin.build(path)),
      );
    } else {
      _showUnsupported(context, path);
    }
  }

  static void _showUnsupported(BuildContext context, String path) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Unsupported file'),
        content: Text('Cannot open:\n$path'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
