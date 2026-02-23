import 'dart:io';
import 'package:flutter/foundation.dart'; // Added for debugPrint
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

class ArchiveService {
  /// Extracts a ZIP file to the given destination directory.
  static Future<bool> extractZip(String zipPath, String destDirPath) async {
    try {
      // Run on a separate isolate to prevent UI freezing
      await compute(_extractIsolate, {'zipPath': zipPath, 'destDir': destDirPath});
      return true;
    } catch (e) {
      debugPrint("Extract error: $e"); // Changed to debugPrint
      return false;
    }
  }

  static void _extractIsolate(Map<String, String> args) {
    final bytes = File(args['zipPath']!).readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(bytes);
    
    for (final file in archive) {
      final filename = file.name;
      if (file.isFile) {
        final data = file.content as List<int>;
        File(p.join(args['destDir']!, filename))
          ..createSync(recursive: true)
          ..writeAsBytesSync(data);
      } else {
        Directory(p.join(args['destDir']!, filename)).createSync(recursive: true);
      }
    }
  }

  /// Compresses a file or folder into a ZIP archive.
  static Future<bool> compressEntity(String sourcePath, String zipDestPath) async {
    try {
      await compute(_compressIsolate, {'source': sourcePath, 'dest': zipDestPath});
      return true;
    } catch (e) {
      debugPrint("Compress error: $e"); // Changed to debugPrint
      return false;
    }
  }

  static void _compressIsolate(Map<String, String> args) {
    var encoder = ZipFileEncoder();
    encoder.create(args['dest']!);
    
    final source = args['source']!;
    if (FileSystemEntity.isDirectorySync(source)) {
      encoder.addDirectory(Directory(source));
    } else {
      encoder.addFile(File(source));
    }
    encoder.close();
  }
}
