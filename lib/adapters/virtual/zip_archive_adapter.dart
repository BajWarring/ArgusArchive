import 'dart:async';
import 'package:archive/archive_io.dart'; 
import '../../core/interfaces/storage_adapter.dart';
import '../../core/models/file_entry.dart';
import '../../core/enums/file_type.dart';
import '../../core/utils/path_utils.dart';

/// Adapter that exposes archive entries as a virtual folder (read-only).
class ZipArchiveAdapter implements StorageAdapter {
  final String zipFilePath;
  Archive? _archiveCache;

  ZipArchiveAdapter({required this.zipFilePath});

  /// Lazily loads the zip directory structure (does not load full file bytes into memory)
  Future<Archive> _getArchive() async {
    if (_archiveCache != null) return _archiveCache!;
    
    // Using InputFileStream prevents loading massive zips entirely into RAM
    final inputStream = InputFileStream(zipFilePath);
    _archiveCache = ZipDecoder().decodeBuffer(inputStream, verify: false);
    return _archiveCache!;
  }

  @override
  Future<List<FileEntry>> list(String path, {ListOptions options = const ListOptions()}) async {
    final archive = await _getArchive();
    
    // Normalize requested path to match zip internal paths
    String targetDir = path == '/' || path.isEmpty ? '' : '$path/';
    if (targetDir.startsWith('/')) targetDir = targetDir.substring(1);

    final Set<String> seenNames = {};
    final List<FileEntry> results = [];

    for (final file in archive) {
      final fileName = file.name;
      
      // Check if the file sits inside the requested target directory
      if (fileName.startsWith(targetDir) && fileName != targetDir) {
        final relativePath = fileName.substring(targetDir.length);
        final segments = relativePath.split('/');
        
        // Is it a direct child file, or a nested directory?
        final isDirectChild = segments.length == 1 || (segments.length == 2 && segments[1].isEmpty);
        final entryName = segments.first;

        if (!seenNames.contains(entryName) && entryName.isNotEmpty) {
          seenNames.add(entryName);
          
          final isDir = segments.length > 1 || file.isFile == false;
          results.add(FileEntry(
            id: '$zipFilePath!/${targetDir}$entryName',
            path: '/${targetDir}$entryName',
            type: isDir ? FileType.dir : FileType.archive, // Simplification for type
            size: isDir ? 0 : file.size,
            modifiedAt: DateTime.fromMillisecondsSinceEpoch((file.lastModTime ?? 0) * 1000),
          ));
        }
      }
    }

    return results;
  }

  @override
  Future<Stream<List<int>>> openRead(String path, {int? start, int? end}) async {
    final archive = await _getArchive();
    
    // Normalize path to find the exact file in the zip
    String searchPath = path.startsWith('/') ? path.substring(1) : path;
    
    final file = archive.findFile(searchPath);
    if (file == null) throw Exception("FileNotFound in archive: $path");

    // Extract the specific file's bytes. 
    // In a pure streaming implementation, we would yield chunks of file.content.
    final content = file.content as List<int>;
    List<int> chunk = content;
    
    if (start != null || end != null) {
      chunk = content.sublist(start ?? 0, end ?? content.length);
    }
    
    return Stream.fromIterable([chunk]);
  }

  // --- Read-Only Constraints ---

  @override
  Future<StreamSink<List<int>>> openWrite(String path, {bool append = false}) {
    throw UnsupportedError("ZipArchiveAdapter is read-only.");
  }

  @override
  Future<void> delete(String path) {
    throw UnsupportedError("ZipArchiveAdapter is read-only.");
  }

  @override
  Future<void> move(String src, String dst) {
    throw UnsupportedError("ZipArchiveAdapter is read-only.");
  }

  @override
  Future<void> copy(String src, String dst) {
    throw UnsupportedError("ZipArchiveAdapter is read-only.");
  }

  @override
  Future<Metadata> stat(String path) async {
    final archive = await _getArchive();
    String searchPath = path.startsWith('/') ? path.substring(1) : path;
    final file = archive.findFile(searchPath);
    
    if (file == null) throw Exception("FileNotFound in archive: $path");
    return Metadata(
      size: file.size, 
      modifiedAt: DateTime.fromMillisecondsSinceEpoch((file.lastModTime ?? 0) * 1000)
    );
  }

  @override
  Stream<StorageEvent> watch(String path) {
    return const Stream.empty(); // Read-only archives don't change
  }
}
