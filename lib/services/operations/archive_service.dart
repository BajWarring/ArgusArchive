import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

class ArchiveService {
  static Future<bool> isArchiveFile(String path) async {
    try {
      final file = File(path);
      final raf = await file.open(mode: FileMode.read);
      final bytes = await raf.read(6);
      await raf.close();

      if (bytes.length < 4) return false;
      if (bytes[0] == 0x50 && bytes[1] == 0x4B && bytes[2] == 0x03 && bytes[3] == 0x04) return true;
      if (bytes[0] == 0x1F && bytes[1] == 0x8B) return true;
      if (bytes[0] == 0x42 && bytes[1] == 0x5A && bytes[2] == 0x68) return true;
      if (bytes[0] == 0x37 && bytes[1] == 0x7A && bytes[2] == 0xBC && bytes[3] == 0xAF) return true;
      if (bytes[0] == 0x52 && bytes[1] == 0x61 && bytes[2] == 0x72 && bytes[3] == 0x21) return true;
      
      final ext = p.extension(path).toLowerCase();
      if (['.tar', '.tgz', '.tar.gz'].contains(ext)) return true;

      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> extractZip(String zipPath, String destDirPath) async {
    try {
      await compute(_extractIsolate, {'zipPath': zipPath, 'destDir': destDirPath});
      return true;
    } catch (e) {
      debugPrint("Extract error: $e");
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

  // ==========================================
  // MULTI-FILE COMPRESSION
  // ==========================================
  static Future<bool> compressEntities(List<String> sourcePaths, String zipDestPath) async {
    try {
      await compute(_compressIsolateMulti, {'sources': sourcePaths, 'dest': zipDestPath});
      return true;
    } catch (e) {
      debugPrint("Compress error: $e");
      return false;
    }
  }

  static void _compressIsolateMulti(Map<String, dynamic> args) {
    var encoder = ZipFileEncoder();
    encoder.create(args['dest'] as String);
    
    final sources = args['sources'] as List<String>;
    for (final source in sources) {
      if (FileSystemEntity.isDirectorySync(source)) {
        encoder.addDirectory(Directory(source));
      } else {
        encoder.addFile(File(source));
      }
    }
    encoder.close();
  }
}
