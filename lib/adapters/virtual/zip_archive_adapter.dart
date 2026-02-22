import 'dart:async';
import 'package:archive/archive_io.dart'; 
import '../../core/interfaces/storage_adapter.dart';
import '../../core/models/file_entry.dart';
import '../../core/enums/file_type.dart';

class ZipArchiveAdapter implements StorageAdapter {
  final String zipFilePath;
  Archive? _archiveCache;

  ZipArchiveAdapter({required this.zipFilePath});

  Future<Archive> _getArchive() async {
    if (_archiveCache != null) return _archiveCache!;
    
    final inputStream = InputFileStream(zipFilePath);
    _archiveCache = ZipDecoder().decodeBuffer(inputStream, verify: false);
    return _archiveCache!;
  }

  @override
  Future<List<FileEntry>> list(String path, {ListOptions options = const ListOptions()}) async {
    final archive = await _getArchive();
    
    String targetDir = path == '/' || path.isEmpty ? '' : '$path/';
    if (targetDir.startsWith('/')) targetDir = targetDir.substring(1);

    final Set<String> seenNames = {};
    final List<FileEntry> results = [];

    for (final file in archive) {
      final fileName = file.name;
      
      if (fileName.startsWith(targetDir) && fileName != targetDir) {
        final relativePath = fileName.substring(targetDir.length);
        final segments = relativePath.split('/');
        
        final entryName = segments.first;

        if (!seenNames.contains(entryName) && entryName.isNotEmpty) {
          seenNames.add(entryName);
          
          final isDir = segments.length > 1 || file.isFile == false;
          results.add(FileEntry(
            id: '$zipFilePath!/$targetDir$entryName',
            path: '/$targetDir$entryName',
            type: isDir ? FileType.dir : FileType.archive, 
            size: isDir ? 0 : file.size,
            modifiedAt: DateTime.fromMillisecondsSinceEpoch(file.lastModTime * 1000),
          ));
        }
      }
    }

    return results;
  }

  @override
  Future<Stream<List<int>>> openRead(String path, {int? start, int? end}) async {
    final archive = await _getArchive();
    
    String searchPath = path.startsWith('/') ? path.substring(1) : path;
    
    final file = archive.findFile(searchPath);
    if (file == null) throw Exception("FileNotFound in archive: $path");

    final content = file.content as List<int>;
    List<int> chunk = content;
    
    if (start != null || end != null) {
      chunk = content.sublist(start ?? 0, end ?? content.length);
    }
    
    return Stream.fromIterable([chunk]);
  }

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
      modifiedAt: DateTime.fromMillisecondsSinceEpoch(file.lastModTime * 1000)
    );
  }

  @override
  Stream<StorageEvent> watch(String path) {
    return const Stream.empty(); 
  }
}
