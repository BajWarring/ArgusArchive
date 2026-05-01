import 'dart:io';

class FileUtils {
  static String getExtension(String path) {
    final parts = path.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }

  static String getFileName(String path) {
    return path.split('/').last;
  }

  static String getParentPath(String path) {
    final parts = path.split('/');
    parts.removeLast();
    return parts.join('/');
  }

  static bool isImage(String path) {
    return ['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp']
        .contains(getExtension(path));
  }

  static bool isVideo(String path) {
    return ['mp4', 'mkv', 'avi', 'mov', 'webm'].contains(getExtension(path));
  }

  static bool isText(String path) {
    return ['txt', 'json', 'dart', 'js', 'py', 'md', 'yaml', 'xml', 'html']
        .contains(getExtension(path));
  }

  static bool isPdf(String path) => getExtension(path) == 'pdf';

  static String generateConflictName(String path) {
    final file = File(path);
    if (!file.existsSync()) return path;
    final ext = getExtension(path);
    final base = path.substring(0, path.length - ext.length - 1);
    int counter = 1;
    String newPath;
    do {
      newPath = '$base ($counter).$ext';
      counter++;
    } while (File(newPath).existsSync());
    return newPath;
  }
}
