import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/models/file_entry.dart';
import '../../core/interfaces/storage_adapter.dart';
import '../../core/utils/path_utils.dart';
import 'file_handler.dart';

/// A handler specifically for viewing and previewing image files.
class ImageHandler implements FileHandler {
  final List<String> _supportedExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'];

  @override
  bool canHandle(FileEntry entry) {
    final ext = PathUtils.getExtension(entry.path);
    return _supportedExtensions.contains(ext);
  }

  @override
  Widget buildPreview(FileEntry entry, StorageAdapter adapter) {
    return const Icon(Icons.image, color: Colors.blue);
  }

  @override
  Future<void> open(BuildContext context, FileEntry entry, StorageAdapter adapter) async {
    // Show a loading dialog while we buffer the image stream
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Stream the image bytes from the adapter into memory
      final stream = await adapter.openRead(entry.path);
      final bytesBuilder = BytesBuilder();
      
      await for (final chunk in stream) {
        bytesBuilder.add(chunk);
      }
      
      final imageBytes = bytesBuilder.takeBytes();

      // Close the loading dialog
      if (context.mounted) Navigator.of(context).pop();

      // Open fullscreen viewer
      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(
                title: Text(PathUtils.getName(entry.path)),
                backgroundColor: Colors.transparent,
                elevation: 0,
              ),
              body: Center(
                child: InteractiveViewer(
                  panEnabled: true,
                  minScale: 1.0,
                  maxScale: 4.0,
                  child: Image.memory(
                    imageBytes,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Center(
                      child: Text('Failed to decode image', style: TextStyle(color: Colors.red)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    } catch (e) {
      // Close the loading dialog on error
      if (context.mounted) Navigator.of(context).pop();
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open image: $e')),
        );
      }
    }
  }
}
