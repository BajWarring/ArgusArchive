import 'dart:async';
import 'dart:typed_data';
import 'package:shared_storage/shared_storage.dart' as saf;
import '../../core/interfaces/storage_adapter.dart';
import '../../core/models/file_entry.dart';
import '../../core/enums/file_type.dart';
import '../../core/utils/path_utils.dart';

/// Android Storage Access Framework adapter using DocumentFile APIs.
/// This translates SAF's opaque URIs into our standard path-based architecture.
class SafStorageAdapter implements StorageAdapter {
  final Uri rootUri;

  SafStorageAdapter({required this.rootUri});

  @override
  Future<List<FileEntry>> list(String path, {ListOptions options = const ListOptions()}) async {
    // If path is root '/', use the rootUri. Otherwise, parse the saved URI.
    final targetUri = path == '/' || path.isEmpty ? rootUri : Uri.parse(path);
    final List<FileEntry> entries = [];
    
    final stream = saf.listFiles(targetUri);
    await for (final file in stream) {
      if (file != null) {
        entries.add(_mapToEntry(file));
      }
    }
    
    return entries;
  }

  @override
  Future<Stream<List<int>>> openRead(String path, {int? start, int? end}) async {
    final uri = Uri.parse(path);
    final bytes = await saf.getDocumentContent(uri);
    
    if (bytes == null) throw Exception("Could not read document bytes.");
    
    List<int> chunk = bytes.toList();
    if (start != null || end != null) {
      chunk = chunk.sublist(start ?? 0, end ?? chunk.length);
    }
    
    return Stream.value(chunk);
  }

  @override
  Future<StreamSink<List<int>>> openWrite(String path, {bool append = false}) async {
    Uri targetUri;
    
    // Intercept our custom virtual creation paths from the TransferWorker
    if (path.startsWith('saf_create|')) {
       final parts = path.substring(11).split('|');
       final parentUri = Uri.parse(parts[0]);
       final fileName = parts[1];
       
       final newDoc = await saf.createFileAsBytes(parentUri, mimeType: '*/*', displayName: fileName, bytes: Uint8List(0));
       if (newDoc == null) throw Exception('Failed to create SAF file');
       targetUri = newDoc.uri;
    } else {
       targetUri = Uri.parse(path);
    }

    final controller = StreamController<List<int>>();
    final builder = BytesBuilder();
    
    controller.stream.listen((chunk) {
      builder.add(chunk);
    }, onDone: () async {
      final bytes = builder.takeBytes();
      await saf.writeToFileAsBytes(
        targetUri, 
        bytes: bytes, 
        mode: append ? saf.FileMode.append : saf.FileMode.write
      );
    });
    
    return controller.sink;
  }

  @override
  Future<void> delete(String path) async {
    final uri = Uri.parse(path);
    final success = await saf.delete(uri);
    if (success != true) throw Exception("Failed to delete SAF document.");
  }

  @override
  Future<void> move(String src, String dst) async {
    Uri? actualSrcUri;
    
    // Resolve the actual URI if it was a virtual path created by openWrite
    if (src.startsWith('saf_create|')) {
       final parts = src.substring(11).split('|');
       final parentUri = Uri.parse(parts[0]);
       final fileName = parts[1];
       
       // Traverse to find the exact URI of the newly created file
       final parentDoc = await saf.DocumentFile(parentUri).findFile(fileName);
       actualSrcUri = parentDoc?.uri;
    } else {
       actualSrcUri = Uri.parse(src);
    }
    
    if (actualSrcUri == null) throw Exception("Source file not found for move operation.");

    String newName;
    if (dst.startsWith('saf_create|')) {
       newName = dst.split('|').last;
    } else {
       newName = PathUtils.getName(dst);
    }

    await saf.renameTo(actualSrcUri, newName);
  }

  @override
  Future<void> copy(String src, String dst) async {
    throw UnimplementedError("For SAF to SAF copies, TransferWorker handles byte-streaming natively.");
  }

  @override
  Future<Metadata> stat(String path) async {
    final uri = Uri.parse(path);
    final doc = saf.DocumentFile(uri);
    
    final size = await doc.length ?? 0;
    final lastModified = await doc.lastModified ?? DateTime.now();
    
    return Metadata(size: size, modifiedAt: lastModified);
  }

  @override
  Stream<StorageEvent> watch(String path) {
    return const Stream.empty(); // SAF does not support live directory watching natively
  }

  FileEntry _mapToEntry(saf.DocumentFile file) {
    FileType type = file.isDirectory == true ? FileType.dir : FileType.unknown;
    
    if (type != FileType.dir) {
      final mime = file.type?.toLowerCase() ?? '';
      if (mime.startsWith('image/')) type = FileType.image;
      else if (mime.startsWith('video/')) type = FileType.video;
      else if (mime.startsWith('audio/')) type = FileType.audio;
      else if (mime.contains('pdf') || mime.contains('text/')) type = FileType.document;
      else if (mime.contains('zip') || mime.contains('archive')) type = FileType.archive;
    }

    return FileEntry(
      id: file.uri.toString(),
      path: file.uri.toString(), // The path is simply the Android URI
      type: type,
      size: file.size ?? 0,
      modifiedAt: file.lastModified ?? DateTime.now(),
      mime: file.type,
    );
  }
}
