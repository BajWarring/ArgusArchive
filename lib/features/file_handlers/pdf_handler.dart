import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../core/models/file_entry.dart';
import '../../core/interfaces/storage_adapter.dart';
import '../../core/utils/path_utils.dart';
import 'file_handler.dart';

class PdfHandler implements FileHandler {
  @override
  bool canHandle(FileEntry entry) {
    return PathUtils.getExtension(entry.path) == 'pdf';
  }

  @override
  Widget buildPreview(FileEntry entry, StorageAdapter adapter) {
    return const Icon(Icons.picture_as_pdf, color: Colors.redAccent);
  }

  @override
  Future<void> open(BuildContext context, FileEntry entry, StorageAdapter adapter) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final stream = await adapter.openRead(entry.path);
      final bytesBuilder = BytesBuilder();
      await for (final chunk in stream) {
        bytesBuilder.add(chunk);
      }
      final bytes = bytesBuilder.takeBytes();

      if (context.mounted) Navigator.of(context).pop();

      if (context.mounted) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: Text(PathUtils.getName(entry.path), style: const TextStyle(fontSize: 16)),
            ),
            body: SfPdfViewer.memory(bytes),
          ),
        ));
      }
    } catch (e) {
      if (context.mounted) Navigator.of(context).pop();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to open PDF: $e')));
      }
    }
  }
}
