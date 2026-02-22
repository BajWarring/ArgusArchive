import 'dart:async';
import 'storage_adapter.dart';
import '../models/file_entry.dart';

/// Represents a generic archive entry before it is extracted or mapped.
class ArchiveEntry {
  final String name;
  final int size;
  final bool isDirectory;
  const ArchiveEntry({required this.name, required this.size, required this.isDirectory});
}

/// Pluggable archive handler for detection and extraction.
abstract class ArchiveHandler {
  /// Checks magic bytes/headers to see if this handler supports the file format.
  Future<bool> canHandle(Stream<List<int>> headerBytes);
  
  /// Lists contents without extracting the whole archive.
  Stream<ArchiveEntry> listEntries(Stream<List<int>> archiveStream);
  
  /// Extracts a specific entry to a destination adapter.
  Future<void> extractEntry(
    Stream<List<int>> archiveStream, 
    ArchiveEntry entry, 
    StorageAdapter destAdapter, 
    String destPath
  );
}
