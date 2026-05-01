import 'dart:io';

class FileOpsService {
  /// COPY FILE OR DIRECTORY
  Future<void> copy({
    required String sourcePath,
    required String destinationPath,
  }) async {
    final type = FileSystemEntity.typeSync(sourcePath);
    if (type == FileSystemEntityType.file) {
      await _copyFile(sourcePath, destinationPath);
    } else if (type == FileSystemEntityType.directory) {
      await _copyDirectory(sourcePath, destinationPath);
    } else {
      throw Exception('Unsupported file type');
    }
  }

  Future<void> _copyFile(String source, String dest) async {
    final file = File(source);
    if (!await file.exists()) throw Exception('Source file not found');
    final newFile = await file.copy(dest);
    if (!await newFile.exists()) throw Exception('Copy failed');
  }

  Future<void> _copyDirectory(String source, String dest) async {
    final dir = Directory(source);
    if (!await dir.exists()) throw Exception('Source directory not found');
    final newDir = Directory(dest);
    if (!await newDir.exists()) await newDir.create(recursive: true);

    for (var entity in dir.listSync(recursive: false)) {
      final newPath = '$dest/${entity.uri.pathSegments.last}';
      if (entity is File) {
        await entity.copy(newPath);
      } else if (entity is Directory) {
        await _copyDirectory(entity.path, newPath);
      }
    }
  }

  /// MOVE (copy → verify → delete)
  Future<void> move({
    required String sourcePath,
    required String destinationPath,
  }) async {
    await copy(sourcePath: sourcePath, destinationPath: destinationPath);
    final type = FileSystemEntity.typeSync(sourcePath);
    if (type == FileSystemEntityType.file) {
      await File(sourcePath).delete();
    } else if (type == FileSystemEntityType.directory) {
      await Directory(sourcePath).delete(recursive: true);
    }
  }

  /// DELETE
  Future<void> delete(String path) async {
    final type = FileSystemEntity.typeSync(path);
    if (type == FileSystemEntityType.file) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } else if (type == FileSystemEntityType.directory) {
      final dir = Directory(path);
      if (await dir.exists()) await dir.delete(recursive: true);
    } else {
      throw Exception('Unsupported delete type');
    }
  }

  /// RENAME
  Future<void> rename(String oldPath, String newPath) async {
    final type = FileSystemEntity.typeSync(oldPath);
    if (type == FileSystemEntityType.file) {
      await File(oldPath).rename(newPath);
    } else if (type == FileSystemEntityType.directory) {
      await Directory(oldPath).rename(newPath);
    }
  }

  /// CREATE FOLDER
  Future<void> createFolder(String path) async {
    await Directory(path).create(recursive: true);
  }
}
