import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../storage/trash_service.dart';

class FileOperationsService {

  // ─── RENAME ──────────────────────────────────────────────────────────────
  static Future<bool> renameEntity(String oldPath, String newPath) async {
    try {
      final isDir = await FileSystemEntity.isDirectory(oldPath);
      if (isDir) {
        await Directory(oldPath).rename(newPath);
      } else {
        await File(oldPath).rename(newPath);
      }
      return true;
    } catch (e) {
      debugPrint("Rename error: $e");
      return false;
    }
  }

  // ─── TRASH (soft delete) ─────────────────────────────────────────────────
  static Future<bool> moveToTrash(String path) async {
    return TrashService.moveToTrash(path);
  }

  // ─── UNIQUE PATH GENERATORS ──────────────────────────────────────────────
  static String getRenameUniquePath(String destDir, String originalName) {
    String name = p.basenameWithoutExtension(originalName);
    String ext = p.extension(originalName);
    String newPath = p.join(destDir, originalName);
    int counter = 1;
    while (File(newPath).existsSync() || Directory(newPath).existsSync()) {
      newPath = p.join(destDir, '${name}_$counter$ext');
      counter++;
    }
    return newPath;
  }

  static String getCopyUniquePath(String destDir, String originalName) {
    String name = p.basenameWithoutExtension(originalName);
    String ext = p.extension(originalName);
    final regex = RegExp(r' \(copy(?: (\d+))?\)$');
    String baseName = name;
    int counter = 0;
    final match = regex.firstMatch(name);
    if (match != null) {
      baseName = name.substring(0, match.start);
      if (match.group(1) != null) {
        counter = int.parse(match.group(1)!);
      }
    }
    String newPath = p.join(destDir, originalName);
    if (!File(newPath).existsSync() && !Directory(newPath).existsSync()) return newPath;
    int testCounter = counter == 0 && match == null ? 0 : (counter == 0 ? 1 : counter + 1);
    while (true) {
      String suffix = testCounter == 0 ? " (copy)" : " (copy $testCounter)";
      newPath = p.join(destDir, '$baseName$suffix$ext');
      if (!File(newPath).existsSync() && !Directory(newPath).existsSync()) break;
      testCounter++;
    }
    return newPath;
  }

  // ─── DELETE (permanent) ──────────────────────────────────────────────────
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

  // ─── COPY ─────────────────────────────────────────────────────────────────
  static Future<bool> copyEntity(String sourcePath, String destDirPath, {bool autoRename = true}) async {
    try {
      final originalName = p.basename(sourcePath);
      String targetPath = p.join(destDirPath, originalName);
      if (File(targetPath).existsSync() || Directory(targetPath).existsSync()) {
        if (autoRename) {
          targetPath = getCopyUniquePath(destDirPath, originalName);
        } else {
          return false;
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

  // ─── MOVE ─────────────────────────────────────────────────────────────────
  static Future<bool> moveEntity(String sourcePath, String destDirPath, {bool autoRename = false}) async {
    try {
      final originalName = p.basename(sourcePath);
      String targetPath = p.join(destDirPath, originalName);
      if (File(targetPath).existsSync() || Directory(targetPath).existsSync()) {
        if (autoRename) {
          targetPath = getRenameUniquePath(destDirPath, originalName);
        } else {
          return false;
        }
      }
      try {
        final isDir = await FileSystemEntity.isDirectory(sourcePath);
        if (isDir) {
          await Directory(sourcePath).rename(targetPath);
        } else {
          await File(sourcePath).rename(targetPath);
        }
      } catch (_) {
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
        final newDir = Directory(p.join(destination.absolute.path, p.basename(entity.path)));
        await newDir.create();
        await _copyDirectory(entity.absolute, newDir);
      } else if (entity is File) {
        await entity.copy(p.join(destination.path, p.basename(entity.path)));
      }
    }
  }

  // ─── FOLDER SIZE ─────────────────────────────────────────────────────────
  static Future<int> getFolderSize(String dirPath) async {
    int total = 0;
    try {
      await for (final entity in Directory(dirPath).list(recursive: true, followLinks: false)) {
        if (entity is File) {
          final stat = await entity.stat();
          total += stat.size;
        }
      }
    } catch (_) {}
    return total;
  }
}
