import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class ArchiveEntryInfo {
  final String name;
  final String fullPath;
  final int size;
  final bool isDirectory;

  ArchiveEntryInfo({
    required this.name,
    required this.fullPath,
    required this.size,
    required this.isDirectory,
  });
}

class ArchiveInfo {
  final String format;
  final int fileCount;
  final int dirCount;
  final int totalUncompressedSize;
  final int compressedSize;

  ArchiveInfo({
    required this.format,
    required this.fileCount,
    required this.dirCount,
    required this.totalUncompressedSize,
    required this.compressedSize,
  });
}

class ArchiveService {
  
  // ===========================================================================
  // HELPERS
  // ===========================================================================
  static bool isArchiveFile(String path) {
    final ext = p.extension(path).toLowerCase();
    return ['.zip', '.rar', '.7z', '.tar', '.gz'].contains(ext);
  }

  static String _getRelativePath(List<String> roots, String fullPath) {
    for (String root in roots) {
      if (fullPath.startsWith(root)) {
        final rootDir = p.dirname(root);
        return fullPath.substring(rootDir.length + 1);
      }
    }
    return p.basename(fullPath);
  }

  // ===========================================================================
  // BATCH COMPRESSION (With Yields & Cancellation)
  // ===========================================================================
  static Future<bool> compressEntities(
    List<String> paths, 
    String dest, 
    {required String format, required Function(double, String) onProgress, required ValueNotifier<bool> cancelToken}
  ) async {
    try {
      int totalBytes = 0;
      List<File> filesToZip = [];
      
      onProgress(0.0, "Calculating size...");
      await Future.delayed(const Duration(milliseconds: 100)); // Yield thread

      // 1. Calculate totals to fix the 0% bug
      for (String path in paths) {
        if (cancelToken.value) return false;
        if (await FileSystemEntity.isDirectory(path)) {
          await for (var entity in Directory(path).list(recursive: true, followLinks: false)) {
            if (entity is File) {
              filesToZip.add(entity);
              totalBytes += await entity.length();
            }
          }
        } else {
          final file = File(path);
          filesToZip.add(file);
          totalBytes += await file.length();
        }
      }

      if (totalBytes == 0) totalBytes = 1; 
      
      int processedBytes = 0;
      final encoder = ZipFileEncoder();
      encoder.create(dest);

      // 2. Compress with UI yields and Cancellation checks
      for (var file in filesToZip) {
        if (cancelToken.value) {
          encoder.close();
          if (File(dest).existsSync()) await File(dest).delete();
          return false;
        }
        
        final relativePath = _getRelativePath(paths, file.path);
        onProgress(processedBytes / totalBytes, p.basename(file.path));
        
        // YIELD TO UI TO UPDATE PROGRESS BAR
        await Future.delayed(Duration.zero); 
        
        encoder.addFile(file, relativePath);
        processedBytes += await file.length();
      }
      
      encoder.close();
      return true;
    } catch (e) {
      return false;
    }
  }

  // ===========================================================================
  // FULL EXTRACTION (With Yields & Cancellation)
  // ===========================================================================
  static Future<bool> extractZip(
    String zipPath, 
    String destDir, 
    {required Function(double, String) onProgress, required ValueNotifier<bool> cancelToken}
  ) async {
    try {
      final file = File(zipPath);
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      
      int totalFiles = archive.length;
      int processed = 0;

      for (final archiveFile in archive) {
        if (cancelToken.value) return false;
        
        final filename = archiveFile.name;
        if (archiveFile.isFile) {
          final data = archiveFile.content as List<int>;
          final outFile = File(p.join(destDir, filename));
          await outFile.create(recursive: true);
          await outFile.writeAsBytes(data);
        } else {
          await Directory(p.join(destDir, filename)).create(recursive: true);
        }
        
        processed++;
        onProgress(processed / totalFiles, filename);
        
        // YIELD TO UI to keep animation smooth
        if (processed % 5 == 0) await Future.delayed(Duration.zero); 
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  // ===========================================================================
  // SINGLE ENTRY EXTRACTION (For Archive Browser)
  // ===========================================================================
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
    } catch (e) {
      return false;
    }
  }

  // ===========================================================================
  // READ ENTRY INTO MEMORY (For Image/Text Previews)
  // ===========================================================================
  static Future<List<int>?> readArchiveEntry(String archivePath, String entryPath) async {
    try {
      final bytes = await File(archivePath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      
      for (final file in archive) {
        if (file.name == entryPath && file.isFile) {
          return file.content as List<int>;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ===========================================================================
  // LIST ENTRIES (For Archive Browser Navigation)
  // ===========================================================================
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
            results.add(ArchiveEntryInfo(
              name: relative.replaceAll('/', ''),
              fullPath: file.name.endsWith('/') ? file.name.substring(0, file.name.length - 1) : file.name,
              size: file.size,
              isDirectory: !file.isFile || file.name.endsWith('/'),
            ));
          } else {
            String dirName = relative.substring(0, slashIndex);
            if (!addedDirs.contains(dirName)) {
              addedDirs.add(dirName);
              results.add(ArchiveEntryInfo(
                name: dirName, fullPath: '$prefix$dirName', size: 0, isDirectory: true,
              ));
            }
          }
        }
      }
      
      results.sort((a, b) {
        if (a.isDirectory && !b.isDirectory) return -1;
        if (!a.isDirectory && b.isDirectory) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      
      return results;
    } catch (e) {
      return [];
    }
  }

  // ===========================================================================
  // METADATA & INTEGRITY CHECKS
  // ===========================================================================
  static Future<bool> testArchiveIntegrity(String archivePath) async {
    try {
      final bytes = await File(archivePath).readAsBytes();
      ZipDecoder().decodeBytes(bytes, verify: true);
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<ArchiveInfo> getArchiveInfo(String archivePath) async {
    try {
      final file = File(archivePath);
      final compressedSize = await file.length();
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      
      int fileCount = 0;
      int dirCount = 0;
      int totalUncompressedSize = 0;

      for (var f in archive) {
        if (f.isFile && !f.name.endsWith('/')) {
          fileCount++;
          totalUncompressedSize += f.size;
        } else {
          dirCount++;
        }
      }

      return ArchiveInfo(
        format: p.extension(archivePath).toUpperCase().replaceAll('.', ''),
        fileCount: fileCount, dirCount: dirCount, totalUncompressedSize: totalUncompressedSize, compressedSize: compressedSize,
      );
    } catch (e) {
      return ArchiveInfo(format: 'UNKNOWN', fileCount: 0, dirCount: 0, totalUncompressedSize: 0, compressedSize: 0);
    }
  }
}
