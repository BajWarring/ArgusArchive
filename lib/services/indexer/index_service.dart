import 'dart:async';
import '../../core/interfaces/storage_adapter.dart';
import '../../core/models/file_entry.dart';
import '../../core/enums/file_type.dart';
import '../../data/db/search_database.dart';

class IndexService {
  final StorageAdapter adapter;
  final SearchDatabase searchDb; 
  
  final List<StreamSubscription<StorageEvent>> _watchSubscriptions = [];
  bool _isIndexing = false;

  IndexService({required this.adapter, required this.searchDb});

  Future<void> start({required List<String> rootPaths, bool rebuild = false}) async {
    await searchDb.init();
    if (rebuild) {
      await searchDb.clearIndex();
      _buildIndexBackground(rootPaths);
    }

    for (var path in rootPaths) {
      _listenToChanges(path);
    }
  }

  Future<void> autoStart(List<String> rootPaths) async {
    await searchDb.init();
    
    final empty = await searchDb.isEmpty();
    if (empty) {
      _buildIndexBackground(rootPaths);
    }
    
    for (var path in rootPaths) {
      _listenToChanges(path);
    }
  }

  Future<void> _buildIndexBackground(List<String> rootPaths) async {
    if (_isIndexing) return;
    _isIndexing = true;
    try {
      final List<String> dirsToScan = List.from(rootPaths);
      while (dirsToScan.isNotEmpty) {
        final currentDir = dirsToScan.removeAt(0);
        try {
          final entries = await adapter.list(currentDir);
          
          await searchDb.insertBatch(entries); 
          
          for (final entry in entries) {
            if (entry.isDirectory) {
              dirsToScan.add(entry.path);
            }
          }
        } catch (e) {
          continue;
        }

        await Future.delayed(const Duration(milliseconds: 10));
      }
    } finally {
      _isIndexing = false;
    }
  }

  void _listenToChanges(String rootPath) {
    final sub = adapter.watch(rootPath).listen((event) async {
      try {
        if (event.eventType == 'deleted') {
          await searchDb.delete(event.path);
        } else if (event.eventType == 'created' || event.eventType == 'modified') {
          final meta = await adapter.stat(event.path);
          
          final entry = FileEntry(
            id: event.path,
            path: event.path,
            type: _guessTypeFromPath(event.path),
            size: meta.size,
            modifiedAt: meta.modifiedAt,
          );
          
          await searchDb.insertBatch([entry]);
        }
      } catch (_) {}
    });
    _watchSubscriptions.add(sub);
  }

  void dispose() {
    for (var sub in _watchSubscriptions) {
      sub.cancel();
    }
  }

  FileType _guessTypeFromPath(String path) {
    final lowerPath = path.toLowerCase();
    if (lowerPath.endsWith('.jpg') || lowerPath.endsWith('.jpeg') || lowerPath.endsWith('.png') || lowerPath.endsWith('.gif') || lowerPath.endsWith('.webp') || lowerPath.endsWith('.bmp') || lowerPath.endsWith('.svg')) return FileType.image;
    if (lowerPath.endsWith('.mp4') || lowerPath.endsWith('.mkv') || lowerPath.endsWith('.webm') || lowerPath.endsWith('.avi') || lowerPath.endsWith('.mov') || lowerPath.endsWith('.ts')) return FileType.video;
    if (lowerPath.endsWith('.pdf')) return FileType.document;
    if (lowerPath.endsWith('.zip')) return FileType.archive;
    return FileType.unknown;
  }
}
