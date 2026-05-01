import 'dart:io';
import 'package:archive/archive.dart';

class ArchiveService {
  /// Extract a ZIP file to [destinationDir]
  static Future<void> extractZip(String zipPath, String destinationDir) async {
    final bytes = File(zipPath).readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(bytes);
    for (final file in archive) {
      final filePath = '$destinationDir/${file.name}';
      if (file.isFile) {
        final outFile = File(filePath);
        await outFile.create(recursive: true);
        await outFile.writeAsBytes(file.content as List<int>);
      } else {
        await Directory(filePath).create(recursive: true);
      }
    }
  }

  /// Create a ZIP from a list of file paths
  static Future<void> createZip(
      List<String> filePaths, String outputPath) async {
    final archive = Archive();
    for (final path in filePaths) {
      final file = File(path);
      if (!file.existsSync()) continue;
      final bytes = file.readAsBytesSync();
      archive.addFile(ArchiveFile(path.split('/').last, bytes.length, bytes));
    }
    final encoded = ZipEncoder().encode(archive);
    if (encoded != null) {
      await File(outputPath).writeAsBytes(encoded);
    }
  }
}
