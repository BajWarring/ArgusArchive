import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

/// Info about an archive file before extraction
class ArchiveInfo {
  final int fileCount;
  final int dirCount;
  final int totalUncompressedSize;
  final int compressedSize;
  final String format;
  final bool isPasswordProtected;
  ArchiveInfo({required this.fileCount, required this.dirCount, required this.totalUncompressedSize, required this.compressedSize, required this.format, this.isPasswordProtected = false});
}

/// A single entry inside an archive, for browsing
class ArchiveEntryInfo {
  final String name;
  final String fullPath;
  final int size;
  final bool isDirectory;
  final DateTime? modified;
  ArchiveEntryInfo({required this.name, required this.fullPath, required this.size, required this.isDirectory, this.modified});
}

class ArchiveService {

  // ─── FORMAT DETECTION ────────────────────────────────────────────────────────
  static Future<bool> isArchiveFile(String path) async {
    try {
      final file = File(path);
      final raf = await file.open(mode: FileMode.read);
      final bytes = await raf.read(8);
      await raf.close();
      if (bytes.length < 4) return false;
      if (bytes[0]==0x50&&bytes[1]==0x4B&&bytes[2]==0x03&&bytes[3]==0x04) return true; // ZIP/APK
      if (bytes[0]==0x50&&bytes[1]==0x4B&&bytes[2]==0x05&&bytes[3]==0x06) return true; // empty ZIP
      if (bytes[0]==0x1F&&bytes[1]==0x8B) return true; // GZ
      if (bytes[0]==0x42&&bytes[1]==0x5A&&bytes[2]==0x68) return true; // BZ2
      if (bytes[0]==0x37&&bytes[1]==0x7A&&bytes[2]==0xBC&&bytes[3]==0xAF) return true; // 7z
      if (bytes[0]==0x52&&bytes[1]==0x61&&bytes[2]==0x72&&bytes[3]==0x21) return true; // RAR
      if (bytes.length>=5&&bytes[0]==0x75&&bytes[1]==0x73&&bytes[2]==0x74&&bytes[3]==0x61&&bytes[4]==0x72) return true; // TAR
      final ext = p.extension(path).toLowerCase();
      return ['.tar','.tgz','.tar.gz','.tar.bz2','.tbz2','.xz'].contains(ext);
    } catch (_) { return false; }
  }

  static String _detectFormat(String path, List<int> magic) {
    if (magic[0]==0x50&&magic[1]==0x4B) return 'ZIP';
    if (magic[0]==0x1F&&magic[1]==0x8B) return 'GZ/TAR.GZ';
    if (magic[0]==0x42&&magic[1]==0x5A) return 'BZ2';
    if (magic[0]==0x37&&magic[1]==0x7A) return '7Z';
    if (magic[0]==0x52&&magic[1]==0x61) return 'RAR';
    final ext = p.extension(path).toLowerCase();
    if (ext=='.tar') return 'TAR';
    return 'UNKNOWN';
  }

  // ─── ARCHIVE INFO ─────────────────────────────────────────────────────────
  static Future<ArchiveInfo> getArchiveInfo(String path) async {
    try {
      final file = File(path);
      final raf = await file.open(mode: FileMode.read);
      final magic = await raf.read(8);
      await raf.close();
      final format = _detectFormat(path, magic);
      final compressedSize = await file.length();

      return await compute(_archiveInfoIsolate, {'path': path, 'format': format, 'compressedSize': compressedSize});
    } catch (e) {
      return ArchiveInfo(fileCount: 0, dirCount: 0, totalUncompressedSize: 0, compressedSize: 0, format: 'UNKNOWN');
    }
  }

  static ArchiveInfo _archiveInfoIsolate(Map<String, dynamic> args) {
    try {
      final bytes = File(args['path']).readAsBytesSync();
      Archive archive;
      final fmt = args['format'] as String;
      if (fmt.contains('GZ') || fmt == 'GZ/TAR.GZ') {
        final ungzipped = GZipDecoder().decodeBytes(bytes);
        archive = TarDecoder().decodeBytes(ungzipped);
      } else if (fmt == 'BZ2') {
        final unbz2 = BZip2Decoder().decodeBytes(bytes);
        archive = TarDecoder().decodeBytes(unbz2);
      } else if (fmt == 'TAR') {
        archive = TarDecoder().decodeBytes(bytes);
      } else {
        archive = ZipDecoder().decodeBytes(bytes);
      }
      int files = 0, dirs = 0, total = 0;
      for (final f in archive) {
        if (f.isFile) { files++; total += f.size; } else { dirs++; }
      }
      return ArchiveInfo(fileCount: files, dirCount: dirs, totalUncompressedSize: total, compressedSize: args['compressedSize'], format: fmt);
    } catch (_) {
      return ArchiveInfo(fileCount: 0, dirCount: 0, totalUncompressedSize: 0, compressedSize: args['compressedSize'], format: args['format']);
    }
  }

  // ─── INTEGRITY TEST ───────────────────────────────────────────────────────
  static Future<bool> testArchiveIntegrity(String path) async {
    try {
      return await compute(_integrityIsolate, path);
    } catch (_) { return false; }
  }

  static bool _integrityIsolate(String path) {
    try {
      final bytes = File(path).readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(bytes, verify: true);
      for (final f in archive) { if (f.isFile) { f.content; } } // force decompress
      return true;
    } catch (_) { return false; }
  }

  // ─── LIST ENTRIES (for in-archive browser) ────────────────────────────────
  static Future<List<ArchiveEntryInfo>> listArchiveEntries(String path, {String prefix = ''}) async {
    try {
      return await compute(_listEntriesIsolate, {'path': path, 'prefix': prefix});
    } catch (_) { return []; }
  }

  static List<ArchiveEntryInfo> _listEntriesIsolate(Map<String, dynamic> args) {
    try {
      final bytes = File(args['path']).readAsBytesSync();
      final Archive archive = ZipDecoder().decodeBytes(bytes);
      final String prefix = args['prefix'] as String;
      final Set<String> seen = {};
      final List<ArchiveEntryInfo> results = [];

      for (final file in archive) {
        String name = file.name;
        if (name.endsWith('/')) name = name.substring(0, name.length - 1);

        if (!name.startsWith(prefix)) continue;
        final relative = name.substring(prefix.length);
        if (relative.isEmpty) continue;

        final segments = relative.split('/');
        final entry = segments.first;
        if (seen.contains(entry)) continue;
        seen.add(entry);

        final isDir = segments.length > 1 || !file.isFile;
        results.add(ArchiveEntryInfo(
          name: entry,
          fullPath: '$prefix$entry',
          size: isDir ? 0 : file.size,
          isDirectory: isDir,
          modified: file.lastModTime > 0 ? DateTime.fromMillisecondsSinceEpoch(file.lastModTime * 1000) : null,
        ));
      }
      results.sort((a, b) {
        if (a.isDirectory && !b.isDirectory) return -1;
        if (!a.isDirectory && b.isDirectory) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      return results;
    } catch (_) { return []; }
  }

  // ─── SINGLE FILE EXTRACT ──────────────────────────────────────────────────
  static Future<bool> extractSingleEntry(String zipPath, String entryPath, String destDir) async {
    try {
      return await compute(_singleExtractIsolate, {'zip': zipPath, 'entry': entryPath, 'dest': destDir});
    } catch (_) { return false; }
  }

  static bool _singleExtractIsolate(Map<String, String> args) {
    try {
      final bytes = File(args['zip']!).readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(bytes);
      final entryPath = args['entry']!;
      final destDir = args['dest']!;
      for (final file in archive) {
        String name = file.name;
        if (name.endsWith('/')) name = name.substring(0, name.length - 1);
        if (name == entryPath || name.startsWith('$entryPath/')) {
          if (file.isFile) {
            final relative = name.substring(entryPath.contains('/') ? entryPath.lastIndexOf('/') + 1 : 0);
            final outFile = File(p.join(destDir, relative.isEmpty ? p.basename(name) : relative));
            outFile.createSync(recursive: true);
            outFile.writeAsBytesSync(file.content as List<int>);
          }
        }
      }
      return true;
    } catch (_) { return false; }
  }

  // ─── READ SINGLE ENTRY BYTES (for preview inside archive) ─────────────────
  static Future<List<int>?> readArchiveEntry(String zipPath, String entryPath) async {
    try {
      return await compute(_readEntryIsolate, {'zip': zipPath, 'entry': entryPath});
    } catch (_) { return null; }
  }

  static List<int>? _readEntryIsolate(Map<String, String> args) {
    try {
      final bytes = File(args['zip']!).readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(bytes);
      for (final file in archive) {
        if (file.isFile && file.name == args['entry']) {
          return file.content as List<int>;
        }
      }
      return null;
    } catch (_) { return null; }
  }

  // ─── FULL EXTRACT WITH PROGRESS ──────────────────────────────────────────
  static Future<bool> extractZip(String zipPath, String destDirPath, {void Function(double progress, String currentFile)? onProgress}) async {
    try {
      if (onProgress != null) {
        return await _extractWithProgress(zipPath, destDirPath, onProgress);
      }
      await compute(_extractIsolate, {'zipPath': zipPath, 'destDir': destDirPath});
      return true;
    } catch (e) {
      debugPrint("Extract error: $e");
      return false;
    }
  }

  static Future<bool> _extractWithProgress(String zipPath, String destDir, void Function(double, String) onProgress) async {
    try {
      final bytes = await File(zipPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final total = archive.length;
      int done = 0;
      for (final file in archive) {
        if (file.isFile) {
          final outPath = p.join(destDir, file.name);
          File(outPath)..createSync(recursive: true)..writeAsBytesSync(file.content as List<int>);
        } else {
          Directory(p.join(destDir, file.name)).createSync(recursive: true);
        }
        done++;
        onProgress(done / total, file.name);
        await Future.delayed(Duration.zero);
      }
      return true;
    } catch (_) { return false; }
  }

  static void _extractIsolate(Map<String, String> args) {
    final bytes = File(args['zipPath']!).readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(bytes);
    for (final file in archive) {
      if (file.isFile) {
        File(p.join(args['destDir']!, file.name))..createSync(recursive: true)..writeAsBytesSync(file.content as List<int>);
      } else {
        Directory(p.join(args['destDir']!, file.name)).createSync(recursive: true);
      }
    }
  }

  // ─── MULTI-FORMAT COMPRESSION ─────────────────────────────────────────────
  /// format: 'zip' | 'tar.gz' | 'tar.bz2' | 'tar'
  static Future<bool> compressEntities(List<String> sourcePaths, String zipDestPath, {String format = 'zip', void Function(double, String)? onProgress}) async {
    try {
      await compute(_compressIsolateMulti, {'sources': sourcePaths, 'dest': zipDestPath, 'format': format});
      return true;
    } catch (e) {
      debugPrint("Compress error: $e");
      return false;
    }
  }

  static void _compressIsolateMulti(Map<String, dynamic> args) {
    final sources = args['sources'] as List<String>;
    final dest = args['dest'] as String;
    final format = args['format'] as String? ?? 'zip';

    if (format == 'zip') {
      var encoder = ZipFileEncoder();
      encoder.create(dest);
      for (final source in sources) {
        if (FileSystemEntity.isDirectorySync(source)) {
          encoder.addDirectory(Directory(source));
        } else {
          encoder.addFile(File(source));
        }
      }
      encoder.close();
    } else {
      // Build TAR archive
      final archive = Archive();
      for (final source in sources) {
        _addToTarArchive(archive, source, p.basename(source));
      }
      List<int> bytes = TarEncoder().encode(archive);
      if (format == 'tar.gz') {
        bytes = GZipEncoder().encode(bytes)!;
      } else if (format == 'tar.bz2') {
        bytes = BZip2Encoder().encode(bytes);
      }
      File(dest)..createSync(recursive: true)..writeAsBytesSync(bytes);
    }
  }

  static void _addToTarArchive(Archive archive, String source, String archiveName) {
    if (FileSystemEntity.isDirectorySync(source)) {
      for (final entity in Directory(source).listSync(recursive: true)) {
        if (entity is File) {
          final relative = p.join(archiveName, p.relative(entity.path, from: source));
          final bytes = entity.readAsBytesSync();
          archive.addFile(ArchiveFile(relative, bytes.length, bytes));
        }
      }
    } else {
      final bytes = File(source).readAsBytesSync();
      archive.addFile(ArchiveFile(archiveName, bytes.length, bytes));
    }
  }

  // ─── ADD FILES TO EXISTING ARCHIVE ───────────────────────────────────────
  static Future<bool> addFilesToArchive(String zipPath, List<String> filePaths) async {
    try {
      return await compute(_addFilesIsolate, {'zip': zipPath, 'files': filePaths});
    } catch (_) { return false; }
  }

  static bool _addFilesIsolate(Map<String, dynamic> args) {
    try {
      final zipPath = args['zip'] as String;
      final filePaths = args['files'] as List<String>;
      final bytes = File(zipPath).readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(bytes);
      for (final filePath in filePaths) {
        if (FileSystemEntity.isFileSync(filePath)) {
          final content = File(filePath).readAsBytesSync();
          archive.addFile(ArchiveFile(p.basename(filePath), content.length, content));
        }
      }
      final encoded = ZipEncoder().encode(archive);
      if (encoded != null) File(zipPath).writeAsBytesSync(encoded);
      return true;
    } catch (_) { return false; }
  }
}
