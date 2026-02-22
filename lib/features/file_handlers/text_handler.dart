import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/models/file_entry.dart';
import '../../core/interfaces/storage_adapter.dart';
import '../../core/utils/path_utils.dart';
import 'file_handler.dart';

class TextHandler implements FileHandler {
  final List<String> _supportedExtensions = ['txt', 'json', 'html', 'xml', 'csv', 'dart', 'md'];

  @override
  bool canHandle(FileEntry entry) {
    final ext = PathUtils.getExtension(entry.path);
    return _supportedExtensions.contains(ext);
  }

  @override
  Widget buildPreview(FileEntry entry, StorageAdapter adapter) {
    return const Icon(Icons.article, color: Colors.blueGrey);
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
      
      final textContent = utf8.decode(bytesBuilder.takeBytes(), allowMalformed: true);
      final lines = textContent.split('\n');

      if (context.mounted) Navigator.of(context).pop();

      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => Scaffold(
              appBar: AppBar(
                title: Text(PathUtils.getName(entry.path), style: const TextStyle(fontSize: 16)),
              ),
              body: ListView.builder(
                itemCount: lines.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Line numbering column
                        Container(
                          width: 50,
                          alignment: Alignment.topRight,
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(color: Colors.grey, fontSize: 13, fontFamily: 'monospace'),
                          ),
                        ),
                        // Text content
                        Expanded(
                          child: Text(
                            lines[index],
                            style: const TextStyle(fontSize: 14, fontFamily: 'monospace'),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) Navigator.of(context).pop();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to open text: $e')));
      }
    }
  }
}
