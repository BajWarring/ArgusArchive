import 'dart:async';
import '../../core/interfaces/storage_adapter.dart';
import '../../core/models/file_entry.dart';
import '../../core/enums/file_type.dart';
import '../../data/db/search_database.dart'; // Updated Import

class IndexService {
  final StorageAdapter adapter;
  final SearchDatabase searchDb; // Updated class
  
  StreamSubscription<StorageEvent>? _watchSubscription;
  bool _isIndexing = false;

  IndexService({required this.adapter, required this.searchDb});

  Future<void> start({required String rootPath, bool rebuild = false}) async {
    await searchDb.init();
    if (rebuild) {
      await searchDb.clearIndex();
      _buildIndexBackground(rootPath);
    }

    _listenToChanges(rootPath);
  }

  Future<void> autoStart(String rootPath) async {
    await searchDb.init();
    
    // 1. If it's the first time running (DB is empty), build the index silently.
    final empty = await searchDb.isEmpty();
    if (empty) {
      _buildIndexBackground(rootPath);
    }
    
    // 2. Always start listening to live file changes (copy, move, delete)
    _listenToChanges(rootPath);
  }


  Future<void> _buildIndexBackground(String rootPath) async {
    if (_isIndexing) return;
    _isIndexing = true;
    try {
      final List<String> dirsToScan = [rootPath];
      while (dirsToScan.isNotEmpty) {
        final currentDir = dirsToScan.removeAt(0);
        try {
          final entries = await adapter.list(currentDir);
          
          // Use the high-performance batch insert
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
    _watchSubscription?.cancel();
    _watchSubscription = adapter.watch(rootPath).listen((event) async {
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
          
          // Use batch insert for single files too for consistency
          await searchDb.insertBatch([entry]);
        }
      } catch (_) {
      }
    });
  }

  void dispose() {
    _watchSubscription?.cancel();
  }

  FileType _guessTypeFromPath(String path) {
    final lowerPath = path.toLowerCase();
    // Upgraded guesser mapping to match our new thumbnails!
    if (lowerPath.endsWith('.jpg') || lowerPath.endsWith('.jpeg') || lowerPath.endsWith('.png') || lowerPath.endsWith('.gif') || lowerPath.endsWith('.webp') || lowerPath.endsWith('.bmp') || lowerPath.endsWith('.svg')) return FileType.image;
    if (lowerPath.endsWith('.mp4')) return FileType.video;
    if (lowerPath.endsWith('.pdf')) return FileType.document;
    if (lowerPath.endsWith('.zip')) return FileType.archive;
    return FileType.unknown;
  }
}
