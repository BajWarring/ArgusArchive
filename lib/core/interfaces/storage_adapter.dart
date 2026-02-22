import 'dart:async';
import '../models/file_entry.dart';

/// Configuration options for listing directories.
class ListOptions {
  final bool recursive;
  const ListOptions({this.recursive = false});
}

/// Basic metadata wrapper for a file or directory.
class Metadata {
  final int size;
  final DateTime modifiedAt;
  const Metadata({required this.size, required this.modifiedAt});
}

/// Represents a filesystem event (e.g., created, modified, deleted).
class StorageEvent {
  final String path;
  final String eventType;
  const StorageEvent({required this.path, required this.eventType});
}

/// Abstract adapter for all storage backends. 
/// Minimal async API ensuring callers never block the main thread.
abstract class StorageAdapter {
  Future<List<FileEntry>> list(String path, {ListOptions options = const ListOptions()});
  
  Future<Stream<List<int>>> openRead(String path, {int? start, int? end});
  
  Future<StreamSink<List<int>>> openWrite(String path, {bool append = false});
  
  Future<void> delete(String path);
  
  Future<void> move(String src, String dst);
  
  Future<void> copy(String src, String dst);
  
  Future<Metadata> stat(String path);
  
  Stream<StorageEvent> watch(String path);
}
