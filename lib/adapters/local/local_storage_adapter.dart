import 'dart:async';
import 'dart:io';
import '../../core/interfaces/storage_adapter.dart';
import '../../core/models/file_entry.dart';
import '../../core/enums/file_type.dart';
import '../../core/utils/path_utils.dart';

/// Direct filesystem adapter for permissive platforms (Android standard directories, iOS sandbox, Desktop).
class LocalStorageAdapter implements StorageAdapter {
  
  @override
  Future<List<FileEntry>> list(String path, {ListOptions options = const ListOptions()}) async {
    final dir = Directory(path);
    if (!await dir.exists()) {
      throw const FileSystemException("Directory not found", "");
    }

    final List<FileEntry> entries = [];
    final stream = dir.list(recursive: options.recursive, followLinks: false);

    await for (final entity in stream) {
      final stat = await entity.stat();
      entries.add(_mapToEntry(entity, stat));
    }
    
    return entries;
  }

  @override
  Future<Stream<List<int>>> openRead(String path, {int? start, int? end}) async {
    final file = File(path);
    return file.openRead(start, end);
  }

  @override
  Future<StreamSink<List<int>>> openWrite(String path, {bool append = false}) async {
    final file = File(path);
    final ioSink = file.openWrite(mode: append ? FileMode.append : FileMode.write);
    return ioSink;
  }

  @override
  Future<void> delete(String path) async {
    final type = await FileSystemEntity.type(path);
    if (type == FileSystemEntityType.directory) {
      await Directory(path).delete(recursive: true);
    } else if (type == FileSystemEntityType.file) {
      await File(path).delete();
    }
  }

  @override
  Future<void> move(String src, String dst) async {
    final type = await FileSystemEntity.type(src);
    if (type == FileSystemEntityType.directory) {
      await Directory(src).rename(dst);
    } else {
      await File(src).rename(dst);
    }
  }

  @override
  Future<void> copy(String src, String dst) async {
    // Note: dart:io File.copy doesn't support directories natively.
    // For directories, the TransferWorker will handle recursive traversal.
    await File(src).copy(dst);
  }

  @override
  Future<Metadata> stat(String path) async {
    final stat = await FileStat.stat(path);
    return Metadata(size: stat.size, modifiedAt: stat.modified);
  }

  @override
  Stream<StorageEvent> watch(String path) {
    final dir = Directory(path);
    return dir.watch().map((event) {
      String type = 'modified';
      if (event is FileSystemCreateEvent) type = 'created';
      if (event is FileSystemDeleteEvent) type = 'deleted';
      if (event is FileSystemMoveEvent) type = 'moved';
      
      return StorageEvent(path: event.path, eventType: type);
    });
  }

  /// Helper to convert dart:io entities to domain models
  FileEntry _mapToEntry(FileSystemEntity entity, FileStat stat) {
    final isDir = stat.type == FileSystemEntityType.directory;
    final name = PathUtils.getName(entity.path);
    
    // Simplistic type detection; in reality, we'd use a mime resolver
    FileType type = isDir ? FileType.dir : FileType.unknown;
    if (!isDir) {
      final ext = PathUtils.getExtension(entity.path);
      if (['jpg', 'png', 'gif'].contains(ext)) type = FileType.image;
      if (['mp4', 'mkv'].contains(ext)) type = FileType.video;
      if (['mp3', 'wav'].contains(ext)) type = FileType.audio;
      if (['zip', 'rar', '7z'].contains(ext)) type = FileType.archive;
      if (['pdf', 'txt', 'doc'].contains(ext)) type = FileType.document;
    }

    return FileEntry(
      id: entity.path, // Local files use path as a unique ID
      path: entity.path,
      type: type,
      size: stat.size,
      modifiedAt: stat.modified,
    );
  }
}
