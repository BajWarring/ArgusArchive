import 'dart:io';
import 'package:flutter/material.dart';
import '../services/thumbnail_service.dart';

class ThumbnailWidget extends StatefulWidget {
  final String path;
  final bool isDirectory;
  final int index;

  const ThumbnailWidget({
    super.key,
    required this.path,
    required this.isDirectory,
    required this.index,
  });

  @override
  State<ThumbnailWidget> createState() => _ThumbnailWidgetState();
}

class _ThumbnailWidgetState extends State<ThumbnailWidget> {
  String? _thumbPath;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.isDirectory) return;
    final result = await ThumbnailService.getThumbnail(
      widget.path,
      widget.index,
    );
    if (result != null && mounted) {
      setState(() => _thumbPath = result);
    }
  }

  @override
  void dispose() {
    // Cancel pending task when widget leaves the tree
    ThumbnailService.cancel(widget.path);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isDirectory) {
      return const Icon(Icons.folder, color: Colors.amber);
    }
    if (_thumbPath != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.file(
          File(_thumbPath!),
          fit: BoxFit.cover,
          width: 50,
          height: 50,
        ),
      );
    }
    return const Icon(Icons.insert_drive_file, color: Colors.blueGrey);
  }
}
