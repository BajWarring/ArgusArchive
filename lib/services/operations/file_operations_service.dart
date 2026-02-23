import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class FileOperationsService {
  
  /// Generates a smart name if a file already exists (e.g., image.png -> image_copy.png -> image_copy1.png)
  static String getUniquePath(String destDir, String originalName) {
    String name = p.basenameWithoutExtension(originalName);
    String ext = p.extension(originalName);
    String newPath = p.join(destDir, originalName);
    
    int counter = 1;
    while (File(newPath).existsSync() || Directory(newPath).existsSync()) {
      String suffix = counter == 1 ? "_copy" : "_copy$counter";
      newPath = p.join(destDir, '$name$suffix$ext');
      counter++;
    }
    return newPath;
  }

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
      debugPrint("Delete error: $e");
      return false;
    }
  }

  /// Copies a file or folder to a new destination.
  static Future<bool> copyEntity(String sourcePath, String destDirPath, {bool autoRename = true}) async {
    try {
      final originalName = p.basename(sourcePath);
      String targetPath = p.join(destDirPath, originalName);

      if (File(targetPath).existsSync() || Directory(targetPath).existsSync()) {
        if (autoRename) {
          targetPath = getUniquePath(destDirPath, originalName);
        } else {
          return false; // Triggers UI collision dialog
        }
      }

      final isDir = await FileSystemEntity.isDirectory(sourcePath);
      if (isDir) {
        await _copyDirectory(Directory(sourcePath), Directory(targetPath));
      } else {
        await File(sourcePath).copy(targetPath);
      }
      return true;
    } catch (e) {
      debugPrint("Copy error: $e");
      return false;
    }
  }

  /// Moves (Cuts) an entity. Handles cross-drive moves safely.
  static Future<bool> moveEntity(String sourcePath, String destDirPath, {bool autoRename = false}) async {
    try {
      final originalName = p.basename(sourcePath);
      String targetPath = p.join(destDirPath, originalName);

      if (File(targetPath).existsSync() || Directory(targetPath).existsSync()) {
        if (autoRename) {
          targetPath = getUniquePath(destDirPath, originalName);
        } else {
          return false; // Triggers UI collision dialog
        }
      }
      
      try {
        final isDir = await FileSystemEntity.isDirectory(sourcePath);
        if (isDir) {
          await Directory(sourcePath).rename(targetPath);
        } else {
          await File(sourcePath).rename(targetPath);
        }
      } catch (e) {
        // Fallback for Cross-Device links (Internal -> SD Card)
        final copied = await copyEntity(sourcePath, destDirPath, autoRename: autoRename);
        if (copied) {
          await deleteEntity(sourcePath);
        } else {
          return false;
        }
      }
      return true;
    } catch (e) {
      debugPrint("Move error: $e");
      return false;
    }
  }

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
