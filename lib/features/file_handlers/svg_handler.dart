import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/models/file_entry.dart';
import '../../core/interfaces/storage_adapter.dart';
import '../../core/utils/path_utils.dart';
import 'file_handler.dart';

class SvgHandler implements FileHandler {
  @override
  bool canHandle(FileEntry entry) {
    return PathUtils.getExtension(entry.path) == 'svg';
  }

  @override
  Widget buildPreview(FileEntry entry, StorageAdapter adapter) {
    return const Icon(Icons.brush, color: Colors.purple);
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
          builder: (context) => _SvgViewerScreen(
            bytes: bytes,
            fileName: PathUtils.getName(entry.path),
          ),
        ));
      }
    } catch (e) {
      if (context.mounted) Navigator.of(context).pop();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to open SVG: $e')));
      }
    }
  }
}

class _SvgViewerScreen extends StatefulWidget {
  final Uint8List bytes;
  final String fileName;

  const _SvgViewerScreen({required this.bytes, required this.fileName});

  @override
  State<_SvgViewerScreen> createState() => _SvgViewerScreenState();
}

class _SvgViewerScreenState extends State<_SvgViewerScreen> {
  bool _showCode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _showCode ? Theme.of(context).scaffoldBackgroundColor : Colors.black87,
      appBar: AppBar(
        title: Text(widget.fileName, style: const TextStyle(fontSize: 16)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _showCode ? _buildCodeView() : _buildVisualView(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => setState(() => _showCode = !_showCode),
        icon: Icon(_showCode ? Icons.image : Icons.code),
        label: Text(_showCode ? 'View Visual' : 'View Code'),
      ),
    );
  }

  Widget _buildVisualView() {
    return Center(
      child: InteractiveViewer(
        maxScale: 5.0,
        child: SvgPicture.memory(
          widget.bytes,
          fit: BoxFit.contain,
          placeholderBuilder: (context) => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }

  Widget _buildCodeView() {
    final textContent = utf8.decode(widget.bytes, allowMalformed: true);
    final lines = textContent.split('\n');

    return ListView.builder(
      itemCount: lines.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                alignment: Alignment.topRight,
                padding: const EdgeInsets.only(right: 8.0),
                child: Text('${index + 1}', style: const TextStyle(color: Colors.grey, fontSize: 13, fontFamily: 'monospace')),
              ),
              Expanded(
                child: Text(lines[index], style: const TextStyle(fontSize: 14, fontFamily: 'monospace')),
              ),
            ],
          ),
        );
      },
    );
  }
}
