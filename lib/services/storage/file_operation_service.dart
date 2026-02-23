import 'dart:io';
import 'package:path/path.dart' as p;

class FileOperationsService {
  /// Deletes a file or directory safely.
  static Future<bool> deleteEntity(String path) async {
    try {
      final isDir = await FileSystemEntity.isDirectory(path);
      if (isDir) {
        await Directory(path).delete(recursive: true);
      } else {
        await File(path).delete();
      }
      return true;
    } catch (e) {
      print("Delete error: $e");
      return false;
    }
  }

  /// Copies a file or folder to a new destination.
  static Future<bool> copyEntity(String sourcePath, String destDirPath) async {
    try {
      final name = p.basename(sourcePath);
      final newPath = p.join(destDirPath, name);
      final isDir = await FileSystemEntity.isDirectory(sourcePath);

      if (isDir) {
        await _copyDirectory(Directory(sourcePath), Directory(newPath));
      } else {
        await File(sourcePath).copy(newPath);
      }
      return true;
    } catch (e) {
      print("Copy error: $e");
      return false;
    }
  }

  /// Moves (Cuts) an entity. Handles cross-drive moves safely.
  static Future<bool> moveEntity(String sourcePath, String destDirPath) async {
    try {
      final name = p.basename(sourcePath);
      final newPath = p.join(destDirPath, name);
      
      try {
        // Try the fast rename first (works if on the same drive)
        final isDir = await FileSystemEntity.isDirectory(sourcePath);
        if (isDir) {
          await Directory(sourcePath).rename(newPath);
        } else {
          await File(sourcePath).rename(newPath);
        }
      } catch (e) {
        // Fallback for Cross-Device links (Internal -> SD Card)
        final copied = await copyEntity(sourcePath, destDirPath);
        if (copied) {
          await deleteEntity(sourcePath);
        } else {
          return false;
        }
      }
      return true;
    } catch (e) {
      print("Move error: $e");
      return false;
    }
  }

  /// Helper to recursively copy directories
  static Future<void> _copyDirectory(Directory source, Directory destination) async {
    await destination.create(recursive: true);
    await for (var entity in source.list(recursive: false)) {
      if (entity is Directory) {
        var newDirectory = Directory(p.join(destination.absolute.path, p.basename(entity.path)));
        await newDirectory.create();
        await _copyDirectory(entity.absolute, newDirectory);
      } else if (entity is File) {
        await entity.copy(p.join(destination.path, p.basename(entity.path)));
      }
    }
  }
}
