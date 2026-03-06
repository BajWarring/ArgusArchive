import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../../services/operations/archive_service.dart';
import '../../features/file_handlers/image_handler.dart';
import '../../features/file_handlers/text_handler.dart';
import '../../features/file_handlers/pdf_handler.dart';
import '../../core/models/file_entry.dart';
import '../../core/enums/file_type.dart';

class ArchiveBrowserScreen extends StatefulWidget {
  final String archivePath;
  const ArchiveBrowserScreen({super.key, required this.archivePath});

  @override
  State<ArchiveBrowserScreen> createState() => _ArchiveBrowserScreenState();
}

class _ArchiveBrowserScreenState extends State<ArchiveBrowserScreen> {
  final List<String> _pathStack = [''];
  List<ArchiveEntryInfo> _entries = [];
  bool _loading = true;
  final Set<String> _selected = {};
  bool get _isSelecting => _selected.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  String get _currentPrefix => _pathStack.last;

  Future<void> _loadEntries() async {
    setState(() { _loading = true; });
    final entries = await ArchiveService.listArchiveEntries(widget.archivePath, prefix: _currentPrefix);
    if (mounted) setState(() { _entries = entries; _loading = false; });
  }

  void _navigateInto(ArchiveEntryInfo entry) {
    _pathStack.add('${entry.fullPath}/');
    _selected.clear();
    _loadEntries();
  }

  void _navigateBack() {
    if (_pathStack.length > 1) {
      _pathStack.removeLast();
      _selected.clear();
      _loadEntries();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _toggleSelect(ArchiveEntryInfo entry) {
    setState(() {
      if (_selected.contains(entry.fullPath)) {
        _selected.remove(entry.fullPath);
      } else {
        _selected.add(entry.fullPath);
      }
    });
  }

  Future<void> _extractSelected() async {
    final paths = _selected.toList();
    await _showExtractDialog(paths);
  }

  Future<void> _extractEntry(ArchiveEntryInfo entry) async {
    await _showExtractDialog([entry.fullPath]);
  }

  Future<void> _showExtractDialog(List<String> entryPaths) async {
    // Default extract to same dir as archive
    final defaultDest = p.dirname(widget.archivePath);
    final controller = TextEditingController(text: defaultDest);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Extract ${entryPaths.length} item(s)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Extract to folder:', style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 8),
            TextField(controller: controller, decoration: const InputDecoration(prefixIcon: Icon(Icons.folder), border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Extract')),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    double prog = 0;
    String curFile = '';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Extracting...'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(curFile, style: const TextStyle(fontSize: 12, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: prog, color: Colors.teal),
              const SizedBox(height: 8),
              Text('${(prog * 100).toStringAsFixed(0)}%'),
            ],
          ),
        ),
      ),
    );

    int done = 0;
    for (final entryPath in entryPaths) {
      await ArchiveService.extractSingleEntry(widget.archivePath, entryPath, controller.text);
      done++;
      prog = done / entryPaths.length;
    }

    if (mounted) {
      Navigator.of(context).pop(); // close progress
      setState(() => _selected.clear());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Extracted ${entryPaths.length} item(s) to ${controller.text}'), backgroundColor: Colors.teal),
      );
    }
  }

  Future<void> _previewEntry(ArchiveEntryInfo entry) async {
    if (entry.isDirectory) { _navigateInto(entry); return; }

    final ext = p.extension(entry.name).toLowerCase().replaceFirst('.', '');
    final isImage = ['jpg','jpeg','png','gif','webp','bmp'].contains(ext);
    final isText = ['txt','json','xml','csv','dart','md','html','log','ini','yaml'].contains(ext);
    final isPdf = ext == 'pdf';

    if (!isImage && !isText && !isPdf) {
      // Unsupported preview — offer extract
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(entry.name),
          content: Text('No previewer for .$ext files.\nSize: ${_formatSize(entry.size)}'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () { Navigator.pop(ctx); _extractEntry(entry); },
              child: const Text('Extract'),
            ),
          ],
        ),
      );
      return;
    }

    // Show loading
    showDialog(
      context: context, barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final bytes = await ArchiveService.readArchiveEntry(widget.archivePath, entry.fullPath);
    if (!mounted) return;
    Navigator.of(context).pop(); // close loading

    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to read file from archive')));
      return;
    }

    // Use a virtual FileEntry for handlers
    final fakeEntry = FileEntry(id: entry.fullPath, path: entry.name, type: isImage ? FileType.image : isPdf ? FileType.document : FileType.document, size: entry.size, modifiedAt: DateTime.now());

    if (isImage) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => _ImagePreview(bytes: Uint8List.fromList(bytes), name: entry.name)));
    } else if (isText) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => _TextPreview(bytes: Uint8List.fromList(bytes), name: entry.name)));
    }
  }

  IconData _iconFor(ArchiveEntryInfo e) {
    if (e.isDirectory) return Icons.folder;
    final ext = p.extension(e.name).toLowerCase();
    if (['.jpg','.jpeg','.png','.gif','.webp','.bmp'].contains(ext)) return Icons.image;
    if (['.mp4','.mkv','.avi','.mov'].contains(ext)) return Icons.movie;
    if (['.mp3','.wav','.flac'].contains(ext)) return Icons.audiotrack;
    if (ext == '.pdf') return Icons.picture_as_pdf;
    if (['.zip','.rar','.7z','.tar'].contains(ext)) return Icons.archive;
    return Icons.insert_drive_file;
  }

  Color _colorFor(ArchiveEntryInfo e) {
    if (e.isDirectory) return Colors.amber;
    final ext = p.extension(e.name).toLowerCase();
    if (['.jpg','.jpeg','.png','.gif'].contains(ext)) return Colors.blue;
    if (['.mp4','.mkv'].contains(ext)) return Colors.indigo;
    if (ext == '.pdf') return Colors.red;
    if (['.zip','.rar'].contains(ext)) return Colors.orange;
    return Colors.tealAccent;
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  String _buildBreadcrumb() {
    if (_currentPrefix.isEmpty) return p.basename(widget.archivePath);
    final parts = _currentPrefix.split('/').where((s) => s.isNotEmpty).toList();
    return '${p.basename(widget.archivePath)} / ${parts.join(' / ')}';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) _navigateBack(); },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _navigateBack),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Archive Browser', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text(_buildBreadcrumb(), style: const TextStyle(fontSize: 11, color: Colors.grey), overflow: TextOverflow.ellipsis),
            ],
          ),
          actions: [
            if (_isSelecting) ...[
              Text('${_selected.length} selected', style: const TextStyle(color: Colors.tealAccent)),
              IconButton(icon: const Icon(Icons.download), tooltip: 'Extract selected', onPressed: _extractSelected),
              IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _selected.clear())),
            ] else ...[
              IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: () => _showArchiveInfo(),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'extract_all') {
                    _showExtractDialog(_entries.map((e) => e.fullPath).toList());
                  } else if (v == 'test') {
                    _testIntegrity();
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'extract_all', child: Row(children: [Icon(Icons.unarchive), SizedBox(width: 8), Text('Extract All')])),
                  PopupMenuItem(value: 'test', child: Row(children: [Icon(Icons.verified), SizedBox(width: 8), Text('Test Integrity')])),
                ],
              ),
            ],
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _entries.isEmpty
                ? const Center(child: Text('Empty folder', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: _entries.length,
                    itemBuilder: (ctx, i) {
                      final entry = _entries[i];
                      final isSelected = _selected.contains(entry.fullPath);
                      return ListTile(
                        tileColor: isSelected ? Colors.teal.withValues(alpha: 0.2) : null,
                        leading: Stack(children: [
                          Icon(_iconFor(entry), color: _colorFor(entry), size: 36),
                          if (isSelected) const Positioned(right: 0, bottom: 0, child: Icon(Icons.check_circle, color: Colors.teal, size: 16)),
                        ]),
                        title: Text(entry.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(entry.isDirectory ? 'Folder' : _formatSize(entry.size), style: const TextStyle(fontSize: 11)),
                        trailing: entry.isDirectory
                            ? const Icon(Icons.chevron_right, color: Colors.grey)
                            : PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, size: 18),
                                onSelected: (v) {
                                  if (v == 'extract') _extractEntry(entry);
                                  if (v == 'select') _toggleSelect(entry);
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'extract', child: Row(children: [Icon(Icons.download, size: 18), SizedBox(width: 8), Text('Extract')])),
                                  PopupMenuItem(value: 'select', child: Row(children: [Icon(Icons.check_box, size: 18), SizedBox(width: 8), Text('Select')])),
                                ],
                              ),
                        onTap: () => _isSelecting ? _toggleSelect(entry) : _previewEntry(entry),
                        onLongPress: () => _toggleSelect(entry),
                      );
                    },
                  ),
      ),
    );
  }

  Future<void> _showArchiveInfo() async {
    showDialog(context: context, builder: (_) => const AlertDialog(content: Center(child: CircularProgressIndicator())));
    final info = await ArchiveService.getArchiveInfo(widget.archivePath);
    if (!mounted) return;
    Navigator.of(context).pop();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(p.basename(widget.archivePath)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _infoRow('Format', info.format),
            _infoRow('Files', '${info.fileCount}'),
            _infoRow('Folders', '${info.dirCount}'),
            _infoRow('Original Size', _formatSize(info.totalUncompressedSize)),
            _infoRow('Compressed', _formatSize(info.compressedSize)),
            if (info.totalUncompressedSize > 0)
              _infoRow('Ratio', '${((1 - info.compressedSize / info.totalUncompressedSize) * 100).toStringAsFixed(1)}% saved'),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    ),
  );

  Future<void> _testIntegrity() async {
    showDialog(
      context: context, barrierDismissible: false,
      builder: (_) => const AlertDialog(title: Text('Testing Archive...'), content: Center(child: CircularProgressIndicator())),
    );
    final ok = await ArchiveService.testArchiveIntegrity(widget.archivePath);
    if (!mounted) return;
    Navigator.of(context).pop();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(children: [Icon(ok ? Icons.verified : Icons.error, color: ok ? Colors.green : Colors.red), const SizedBox(width: 8), Text(ok ? 'Archive OK' : 'Corrupt Archive')]),
        content: Text(ok ? 'All files verified successfully.' : 'Archive may be corrupt or incomplete.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  final Uint8List bytes;
  final String name;
  const _ImagePreview({required this.bytes, required this.name});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(title: Text(name), backgroundColor: Colors.transparent),
    body: Center(child: InteractiveViewer(maxScale: 5, child: Image.memory(bytes, fit: BoxFit.contain))),
  );
}

class _TextPreview extends StatelessWidget {
  final Uint8List bytes;
  final String name;
  const _TextPreview({required this.bytes, required this.name});
  @override
  Widget build(BuildContext context) {
    final text = String.fromCharCodes(bytes);
    final lines = text.split('\n');
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: ListView.builder(
        itemCount: lines.length,
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 48, child: Text('${i+1}', textAlign: TextAlign.right, style: const TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'monospace'))),
            const SizedBox(width: 8),
            Expanded(child: Text(lines[i], style: const TextStyle(fontSize: 13, fontFamily: 'monospace'))),
          ]),
        ),
      ),
    );
  }
}
