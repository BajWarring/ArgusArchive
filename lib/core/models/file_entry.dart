import '../enums/file_type.dart';

/// Immutable model representing a single file or directory across any storage adapter.
class FileEntry {
  final String id;
  final String path;
  final FileType type;
  final int size;
  final String? mime;
  final DateTime modifiedAt;
  final String? hash;

  const FileEntry({
    required this.id,
    required this.path,
    required this.type,
    required this.size,
    required this.modifiedAt,
    this.mime,
    this.hash,
  });

  bool get isDirectory => type == FileType.dir;

  FileEntry copyWith({
    String? id,
    String? path,
    FileType? type,
    int? size,
    String? mime,
    DateTime? modifiedAt,
    String? hash,
  }) {
    return FileEntry(
      id: id ?? this.id,
      path: path ?? this.path,
      type: type ?? this.type,
      size: size ?? this.size,
      mime: mime ?? this.mime,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      hash: hash ?? this.hash,
    );
  }
}
