import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

class ArchiveService {
  /// Smartly detects if a file is an archive by reading its raw byte signature (Magic Numbers).
  /// This completely ignores the file extension, making it incredibly robust.
  static Future<bool> isArchiveFile(String path) async {
    try {
      final file = File(path);
      // Open the file and just read the first 4 bytes to save memory
      final raf = await file.open(mode: FileMode.read);
      final bytes = await raf.read(6);
      await raf.close();

      if (bytes.length < 4) return false;

      // ZIP / APK / JAR (Starts with PK\x03\x04)
      if (bytes[0] == 0x50 && bytes[1] == 0x4B && bytes[2] == 0x03 && bytes[3] == 0x04) {
        return true;
      }
      // GZIP (Starts with \x1F\x8B)
      if (bytes[0] == 0x1F && bytes[1] == 0x8B) {
        return true;
      }
      // BZIP2 (Starts with BZh)
      if (bytes[0] == 0x42 && bytes[1] == 0x5A && bytes[2] == 0x68) {
        return true;
      }
      // 7z (Starts with 7z\xBC\xAF)
      if (bytes[0] == 0x37 && bytes[1] == 0x7A && bytes[2] == 0xBC && bytes[3] == 0xAF) {
        return true;
      }
      // RAR (Starts with Rar!)
      if (bytes[0] == 0x52 && bytes[1] == 0x61 && bytes[2] == 0x72 && bytes[3] == 0x21) {
        return true;
      }
      
      // Fallback: Check extension for formats like TAR that lack strong byte signatures
      final ext = p.extension(path).toLowerCase();
      if (['.tar', '.tgz', '.tar.gz'].contains(ext)) return true;

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Extracts a ZIP file to the given destination directory.
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

  /// Compresses a file or folder into a ZIP archive.
  static Future<bool> compressEntity(String sourcePath, String zipDestPath) async {
    try {
      await compute(_compressIsolate, {'source': sourcePath, 'dest': zipDestPath});
      return true;
    } catch (e) {
      debugPrint("Compress error: $e");
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
