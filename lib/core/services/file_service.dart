import 'dart:io';

class FileService {
  static Future<List<FileSystemEntity>> listDirectory(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) return [];
    return dir.listSync().toList();
  }

  static Future<bool> exists(String path) async {
    return File(path).existsSync() || Directory(path).existsSync();
  }

  static int getSize(FileSystemEntity entity) {
    try {
      return entity.statSync().size;
    } catch (_) {
      return 0;
    }
  }
}
