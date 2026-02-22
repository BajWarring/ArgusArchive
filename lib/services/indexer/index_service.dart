import 'dart:async';
import '../../core/interfaces/storage_adapter.dart';
import '../../core/models/file_entry.dart';
import '../../data/db/index_db.dart';

class IndexService {
  final StorageAdapter adapter;
  final IndexDb indexDb;
  
  StreamSubscription<StorageEvent>? _watchSubscription;
  bool _isIndexing = false;

  IndexService({required this.adapter, required this.indexDb});

  /// Starts the service, forcing a full background rebuild if requested.
  Future<void> start({required String rootPath, bool rebuild = false}) async {
    await indexDb.init();

    if (rebuild) {
      await indexDb.clearIndex();
      _buildIndexBackground(rootPath);
    }

    _listenToChanges(rootPath);
  }

  /// Recursively scans the storage adapter and batches inserts into the DB.
  /// Designed to not block the main thread.
  Future<void> _buildIndexBackground(String rootPath) async {
    if (_isIndexing) return;
    _isIndexing = true;

    try {
      final List<String> dirsToScan = [rootPath];

      while (dirsToScan.isNotEmpty) {
        final currentDir = dirsToScan.removeAt(0);
        
        try {
          // Read directory contents
          final entries = await adapter.list(currentDir);
          
          for (final entry in entries) {
            // Add file to SQLite FTS index
            await indexDb.insert(entry);

            // Queue directories for further scanning
            if (entry.isDirectory) {
              dirsToScan.add(entry.path);
            }
          }
        } catch (e) {
          // Ignore permission/access errors for specific folders and continue
          continue; 
        }

        // Yield to the event loop so the UI doesn't stutter during large scans
        await Future.delayed(const Duration(milliseconds: 10));
      }
    } finally {
      _isIndexing = false;
    }
  }

  /// Listens to live file changes to incrementally update the DB without full rescans.
  void _listenToChanges(String rootPath) {
    _watchSubscription?.cancel();
    
    _watchSubscription = adapter.watch(rootPath).listen((event) async {
      try {
        if (event.eventType == 'deleted') {
          await indexDb.delete(event.path);
        } else if (event.eventType == 'created' || event.eventType == 'modified') {
          // Stat the new/modified file to get its metadata, then insert it
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
        // Silently ignore stat errors on deleted or locked files
      }
    });
  }

  /// Stops listening to changes and cleans up.
  void dispose() {
    _watchSubscription?.cancel();
  }

  // Basic fallback type deduction for incremental updates
  FileType _guessTypeFromPath(String path) {
    final lowerPath = path.toLowerCase();
    if (lowerPath.endsWith('.jpg') || lowerPath.endsWith('.png')) return FileType.image;
    if (lowerPath.endsWith('.mp4')) return FileType.video;
    if (lowerPath.endsWith('.pdf')) return FileType.document;
    if (lowerPath.endsWith('.zip')) return FileType.archive;
    return FileType.unknown; // The adapter's actual list() would be more precise
  }
}
