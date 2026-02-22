import 'package:path/path.dart' as p;

class PathUtils {
  static String join(String part1, [String? part2, String? part3]) {
    return p.normalize(p.join(part1, part2 ?? '', part3 ?? ''));
  }

  static String getExtension(String path) {
    final ext = p.extension(path);
    return ext.isNotEmpty ? ext.substring(1).toLowerCase() : '';
  }

  static String getName(String path) {
    return p.basename(path);
  }

  static String sanitizeFileName(String name) {
    return name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
  }
}
