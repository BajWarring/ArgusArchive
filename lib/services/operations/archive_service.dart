import 'dart:io';
import 'dart:isolate';
import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class ArchiveEntryInfo {
  final String name; final String fullPath; final int size; final bool isDirectory;
  ArchiveEntryInfo({required this.name, required this.fullPath, required this.size, required this.isDirectory});
}

class ArchiveInfo {
  final String format; final int fileCount; final int dirCount; final int totalUncompressedSize; final int compressedSize;
  ArchiveInfo({required this.format, required this.fileCount, required this.dirCount, required this.totalUncompressedSize, required this.compressedSize});
}

class ArchiveService {
  
  static Future<bool> isArchiveFile(String path) async {
    return ['.zip', '.rar', '.7z', '.tar', '.gz'].contains(p.extension(path).toLowerCase());
  }

  static String _getRelativePath(List<String> roots, String fullPath) {
    for (String root in roots) {
      if (fullPath.startsWith(root)) return fullPath.substring(p.dirname(root).length + 1);
    }
    return p.basename(fullPath);
  }

  // ===========================================================================
  // ISOLATE-BASED BATCH COMPRESSION (Prevents UI Freeze and ANR Crashes)
  // ===========================================================================
  static Future<bool> compressEntities(List<String> paths, String dest, {required String format, required Function(double, String) onProgress, required ValueNotifier<bool> cancelToken}) async {
    final receivePort = ReceivePort();
    final isolate = await Isolate.spawn(_compressIsolate, {'paths': paths, 'dest': dest, 'sendPort': receivePort.sendPort});

    bool success = false;

    void cancelListener() {
      if (cancelToken.value) {
        isolate.kill(priority: Isolate.immediate);
        if (File(dest).existsSync()) File(dest).deleteSync();
        receivePort.close();
      }
    }
    cancelToken.addListener(cancelListener);

    await for (final message in receivePort) {
      if (message is Map) {
        if (message['type'] == 'progress') {
          onProgress(message['progress'], message['file']);
        } else if (message['type'] == 'done') {
          success = message['success'];
          receivePort.close();
        }
      }
    }
    cancelToken.removeListener(cancelListener);
    return success;
  }

  static void _compressIsolate(Map<String, dynamic> args) {
    final paths = args['paths'] as List<String>;
    final dest = args['dest'] as String;
    final sendPort = args['sendPort'] as SendPort;

    try {
      int totalBytes = 0;
      List<File> filesToZip = [];
      sendPort.send({'type': 'progress', 'progress': 0.0, 'file': 'Scanning files...'});

      for (String path in paths) {
        final dir = Directory(path);
        if (dir.existsSync()) {
          for (var entity in dir.listSync(recursive: true, followLinks: false)) {
            if (entity is File) {
              filesToZip.add(entity);
              totalBytes += entity.lengthSync();
            }
          }
        } else {
          final file = File(path);
          if (file.existsSync()) {
            filesToZip.add(file);
            totalBytes += file.lengthSync();
          }
        }
      }

      if (totalBytes == 0) totalBytes = 1;
      int processedBytes = 0;
      
      final encoder = ZipFileEncoder();
      encoder.create(dest);

      for (var file in filesToZip) {
        final relativePath = _getRelativePath(paths, file.path);
        sendPort.send({'type': 'progress', 'progress': processedBytes / totalBytes, 'file': p.basename(file.path)});
        encoder.addFile(file, relativePath);
        processedBytes += file.lengthSync();
      }
      
      encoder.close();
      sendPort.send({'type': 'done', 'success': true});
    } catch (e) {
      sendPort.send({'type': 'done', 'success': false});
    }
  }

  // ===========================================================================
  // ISOLATE-BASED FULL EXTRACTION (Uses Streams to Prevent RAM OOM Crashes)
  // ===========================================================================
  static Future<bool> extractZip(String zipPath, String destDir, {required Function(double, String) onProgress, required ValueNotifier<bool> cancelToken}) async {
    final receivePort = ReceivePort();
    final isolate = await Isolate.spawn(_extractIsolate, {'zipPath': zipPath, 'destDir': destDir, 'sendPort': receivePort.sendPort});

    bool success = false;

    void cancelListener() {
      if (cancelToken.value) {
        isolate.kill(priority: Isolate.immediate);
        receivePort.close();
      }
    }
    cancelToken.addListener(cancelListener);

    await for (final message in receivePort) {
      if (message is Map) {
        if (message['type'] == 'progress') {
          onProgress(message['progress'], message['file']);
        } else if (message['type'] == 'done') {
          success = message['success'];
          receivePort.close();
        }
      }
    }
    cancelToken.removeListener(cancelListener);
    return success;
  }

  static void _extractIsolate(Map<String, dynamic> args) {
    final zipPath = args['zipPath'] as String;
    final destDir = args['destDir'] as String;
    final sendPort = args['sendPort'] as SendPort;

    try {
      // Decode Buffer using Stream prevents loading massive Zips into memory
      final inputStream = InputFileStream(zipPath);
      final archive = ZipDecoder().decodeBuffer(inputStream);
      
      int totalFiles = archive.length;
      int processed = 0;

      for (final archiveFile in archive) {
        final filename = archiveFile.name;
        if (archiveFile.isFile) {
          final outFile = File(p.join(destDir, filename));
          outFile.createSync(recursive: true);
          final outStream = OutputFileStream(outFile.path);
          archiveFile.writeContent(outStream);
          outStream.close();
        } else {
          Directory(p.join(destDir, filename)).createSync(recursive: true);
        }
        processed++;
        sendPort.send({'type': 'progress', 'progress': processed / totalFiles, 'file': filename});
      }
      
      inputStream.close();
      sendPort.send({'type': 'done', 'success': true});
    } catch (e) {
      sendPort.send({'type': 'done', 'success': false});
    }
  }

  // --- Keep other methods like listArchiveEntries identical... ---
  static Future<bool> extractSingleEntry(String archivePath, String entryPath, String destDir) async {
    try {
      final bytes = await File(archivePath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      for (final file in archive) {
        if (file.name == entryPath || file.name == '$entryPath/') {
          final filename = p.basename(file.name);
          if (file.isFile) {
            final data = file.content as List<int>;
            final outFile = File(p.join(destDir, filename));
            await outFile.create(recursive: true);
            await outFile.writeAsBytes(data);
          } else {
            await Directory(p.join(destDir, filename)).create(recursive: true);
          }
          return true;
        }
      }
      return false;
    } catch (e) { return false; }
  }

  static Future<List<int>?> readArchiveEntry(String archivePath, String entryPath) async {
    try {
      final bytes = await File(archivePath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      for (final file in archive) {
        if (file.name == entryPath && file.isFile) return file.content as List<int>;
      }
      return null;
    } catch (e) { return null; }
  }

  static Future<List<ArchiveEntryInfo>> listArchiveEntries(String archivePath, {String prefix = ''}) async {
    try {
      final bytes = await File(archivePath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      List<ArchiveEntryInfo> results = [];
      Set<String> addedDirs = {};
      for (var file in archive) {
        if (file.name.startsWith(prefix)) {
          String relative = file.name.substring(prefix.length);
          if (relative.isEmpty) continue;
          int slashIndex = relative.indexOf('/');
          if (slashIndex == -1 || (slashIndex == relative.length - 1)) {
            results.add(ArchiveEntryInfo(name: relative.replaceAll('/', ''), fullPath: file.name.endsWith('/') ? file.name.substring(0, file.name.length - 1) : file.name, size: file.size, isDirectory: !file.isFile || file.name.endsWith('/')));
          } else {
            String dirName = relative.substring(0, slashIndex);
            if (!addedDirs.contains(dirName)) { addedDirs.add(dirName); results.add(ArchiveEntryInfo(name: dirName, fullPath: '$prefix$dirName', size: 0, isDirectory: true)); }
          }
        }
      }
      results.sort((a, b) { if (a.isDirectory && !b.isDirectory) return -1; if (!a.isDirectory && b.isDirectory) return 1; return a.name.toLowerCase().compareTo(b.name.toLowerCase()); });
      return results;
    } catch (e) { return []; }
  }

  static Future<bool> testArchiveIntegrity(String archivePath) async {
    try {
      final bytes = await File(archivePath).readAsBytes();
      ZipDecoder().decodeBytes(bytes, verify: true);
      return true;
    } catch (e) { return false; }
  }

  static Future<ArchiveInfo> getArchiveInfo(String archivePath) async {
    try {
      final file = File(archivePath);
      final compressedSize = await file.length();
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      int fileCount = 0; int dirCount = 0; int totalUncompressedSize = 0;
      for (var f in archive) {
        if (f.isFile && !f.name.endsWith('/')) { fileCount++; totalUncompressedSize += f.size; } else { dirCount++; }
      }
      return ArchiveInfo(format: p.extension(archivePath).toUpperCase().replaceAll('.', ''), fileCount: fileCount, dirCount: dirCount, totalUncompressedSize: totalUncompressedSize, compressedSize: compressedSize);
    } catch (e) { return ArchiveInfo(format: 'UNKNOWN', fileCount: 0, dirCount: 0, totalUncompressedSize: 0, compressedSize: 0); }
  }
}
