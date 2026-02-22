import 'dart:async';
import '../../core/interfaces/storage_adapter.dart';
import '../../core/models/file_entry.dart';
import '../../core/enums/file_type.dart';
import '../../data/db/index_db.dart';

class IndexService {
  final StorageAdapter adapter;
  final IndexDb indexDb;
  
  StreamSubscription<StorageEvent>? _watchSubscription;
  bool _isIndexing = false;

  IndexService({required this.adapter, required this.indexDb});

  Future<void> start({required String rootPath, bool rebuild = false}) async {
    await indexDb.init();

    if (rebuild) {
      await indexDb.clearIndex();
      _buildIndexBackground(rootPath);
    }

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
          
          for (final entry in entries) {
            await indexDb.insert(entry);
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
          await indexDb.delete(event.path);
        } else if (event.eventType == 'created' || event.eventType == 'modified') {
          final meta = await adapter.stat(event.path);
          
          final entry = FileEntry(
            id: event.path,
            path: event.path,
            type: _guessTypeFromPath(event.path),
            size: meta.size,
            modifiedAt: meta.modifiedAt,
          );
          
          await indexDb.insert(entry);
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
    if (lowerPath.endsWith('.jpg') || lowerPath.endsWith('.png')) return FileType.image;
    if (lowerPath.endsWith('.mp4')) return FileType.video;
    if (lowerPath.endsWith('.pdf')) return FileType.document;
    if (lowerPath.endsWith('.zip')) return FileType.archive;
    return FileType.unknown; 
  }
}
