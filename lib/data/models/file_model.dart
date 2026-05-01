import 'dart:io';

class FileModel {
  final String path;
  final String name;
  final bool isDirectory;
  final int size;
  final DateTime modified;

  FileModel({
    required this.path,
    required this.name,
    required this.isDirectory,
    required this.size,
    required this.modified,
  });

  factory FileModel.fromEntity(FileSystemEntity entity) {
    final stat = entity.statSync();
    return FileModel(
      path: entity.path,
      name: entity.uri.pathSegments.last,
      isDirectory: entity is Directory,
      size: stat.size,
      modified: stat.modified,
    );
  }
}
