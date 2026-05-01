import 'dart:io';
import '../models/file_model.dart';

class FileRepository {
  List<FileModel> getFiles(String path) {
    final dir = Directory(path);
    if (!dir.existsSync()) return [];
    try {
      return dir
          .listSync()
          .map((e) => FileModel.fromEntity(e))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
