// REQUIRES in pubspec.yaml:
//   pdfrx: ^1.0.77          ← add this
//   # remove: syncfusion_flutter_pdfviewer

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import '../../adapters/local/local_storage_adapter.dart';
import '../../core/models/file_entry.dart';
import '../../core/interfaces/storage_adapter.dart';
import '../../core/utils/path_utils.dart';
import 'file_handler.dart';

class PdfHandler implements FileHandler {
  @override
  bool canHandle(FileEntry entry) =>
      PathUtils.getExtension(entry.path) == 'pdf';

  @override
  Widget buildPreview(FileEntry entry, StorageAdapter adapter) =>
      const Icon(Icons.picture_as_pdf, color: Colors.redAccent);

  @override
  Future<void> open(BuildContext context, FileEntry entry, StorageAdapter adapter) async {
    // For local files pdfrx uses native PDF engine directly — no pre-load needed.
    if (adapter is LocalStorageAdapter) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => _PdfScreen(title: PathUtils.getName(entry.path), path: entry.path),
      ));
      return;
    }

    // Non-local adapters: buffer bytes then hand to pdfrx.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final stream = await adapter.openRead(entry.path);
      final bb = BytesBuilder();
      await for (final chunk in stream) { bb.add(chunk); }
      final bytes = bb.takeBytes();
      if (context.mounted) Navigator.of(context).pop();
      if (context.mounted) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => _PdfScreen(
            title: PathUtils.getName(entry.path),
            bytes: bytes,
          ),
        ));
      }
    } catch (e) {
      if (context.mounted) Navigator.of(context).pop();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open PDF: $e')),
        );
      }
    }
  }
}

// ─── PDF viewer screen ────────────────────────────────────────────────────────
class _PdfScreen extends StatefulWidget {
  final String title;
  final String? path;
  final Uint8List? bytes;

  const _PdfScreen({required this.title, this.path, this.bytes})
      : assert(path != null || bytes != null);

  @override
  State<_PdfScreen> createState() => _PdfScreenState();
}

class _PdfScreenState extends State<_PdfScreen> {
  final PdfViewerController _ctrl = PdfViewerController();
  int _currentPage = 1;
  int _totalPages  = 0;


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF303030),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            if (_totalPages > 0)
              Text('Page $_currentPage of $_totalPages',
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        actions: [
          if (_totalPages > 1) ...[
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_up),
              tooltip: 'Previous page',
              onPressed: _currentPage > 1
                  ? () => _ctrl.goToPage(pageNumber: _currentPage - 1)
                  : null,
            ),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_down),
              tooltip: 'Next page',
              onPressed: _currentPage < _totalPages
                  ? () => _ctrl.goToPage(pageNumber: _currentPage + 1)
                  : null,
            ),
          ],
        ],
      ),
      body: widget.path != null
          ? PdfViewer.file(
              widget.path!,
              controller: _ctrl,
              params: _viewerParams(),
            )
          : PdfViewer.data(
              widget.bytes!,
              sourceName: widget.title,
              controller: _ctrl,
              params: _viewerParams(),
            ),
    );
  }

  PdfViewerParams _viewerParams() {
    return PdfViewerParams(
      backgroundColor: const Color(0xFF303030),
      onViewerReady: (document, controller) {
  setState(() {
    _totalPages  = document.pages.length;
    _currentPage = 1;
  });
},
      onPageChanged: (page) {
        setState(() => _currentPage = page ?? 1);
      },
    );
  }
}
