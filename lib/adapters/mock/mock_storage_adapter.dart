import 'dart:async';
import '../../core/interfaces/storage_adapter.dart';
import '../../core/models/file_entry.dart';
import '../../core/enums/file_type.dart';

/// In-memory storage adapter for unit tests and CI.
class MockStorageAdapter implements StorageAdapter {
  // Simulates a file system where Key is path, Value is byte content
  final Map<String, List<int>> _fileSystem = {};

  /// Seeds the mock file system with test data
  void seedFile(String path, List<int> bytes) {
    _fileSystem[path] = bytes;
  }

  /// Checks if a file exists in the mock file system
  bool exists(String path) => _fileSystem.containsKey(path);

  /// Retrieves the bytes of a file for assertion in tests
  List<int>? getBytes(String path) => _fileSystem[path];

  @override
  Future<List<FileEntry>> list(String path, {ListOptions options = const ListOptions()}) async {
    return _fileSystem.keys
        .where((k) => k.startsWith(path) && k != path)
        .map((k) => FileEntry(
              id: k,
              path: k,
              type: FileType.unknown, // Simplified for mock
              size: _fileSystem[k]!.length,
              modifiedAt: DateTime.now(),
            ))
        .toList();
  }

  @override
  Future<Stream<List<int>>> openRead(String path, {int? start, int? end}) async {
    if (!_fileSystem.containsKey(path)) {
      throw Exception("FileNotFound: $path");
    }
    
    List<int> data = _fileSystem[path]!;
    if (start != null || end != null) {
      data = data.sublist(start ?? 0, end ?? data.length);
    }

    // Simulate chunked streaming (e.g., 1024 bytes per chunk)
    return Stream.fromIterable([data]); 
  }

  @override
  Future<StreamSink<List<int>>> openWrite(String path, {bool append = false}) async {
    final controller = StreamController<List<int>>();
    
    if (!append || !_fileSystem.containsKey(path)) {
      _fileSystem[path] = [];
    }

    controller.stream.listen((chunk) {
      _fileSystem[path]!.addAll(chunk);
    });

    return controller.sink;
  }

  @override
  Future<void> delete(String path) async {
    _fileSystem.remove(path);
  }

  @override
  Future<void> move(String src, String dst) async {
    if (!_fileSystem.containsKey(src)) throw Exception("FileNotFound: $src");
    _fileSystem[dst] = _fileSystem.remove(src)!;
  }

  @override
  Future<void> copy(String src, String dst) async {
    if (!_fileSystem.containsKey(src)) throw Exception("FileNotFound: $src");
    _fileSystem[dst] = List.from(_fileSystem[src]!);
  }

  @override
  Future<Metadata> stat(String path) async {
    if (!_fileSystem.containsKey(path)) throw Exception("FileNotFound: $path");
    return Metadata(size: _fileSystem[path]!.length, modifiedAt: DateTime.now());
  }

  @override
  Stream<StorageEvent> watch(String path) {
    // Stubbed for mock: In a complex mock, we'd use a broadcast stream to emit events
    return const Stream.empty();
  }
}
