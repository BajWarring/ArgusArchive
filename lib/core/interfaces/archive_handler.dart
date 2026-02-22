import 'dart:async';
import 'storage_adapter.dart';

class ArchiveEntry {
  final String name;
  final int size;
  final bool isDirectory;
  const ArchiveEntry({required this.name, required this.size, required this.isDirectory});
}

abstract class ArchiveHandler {
  Future<bool> canHandle(Stream<List<int>> headerBytes);
  Stream<ArchiveEntry> listEntries(Stream<List<int>> archiveStream);
  Future<void> extractEntry(
    Stream<List<int>> archiveStream, 
    ArchiveEntry entry, 
    StorageAdapter destAdapter, 
    String destPath
  );
}
