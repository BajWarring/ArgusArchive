import 'package:path/package:path.dart' as p;

/// Cross-platform path normalizer and sanitizer.
class PathUtils {
  /// Joins multiple path segments safely.
  static String join(String part1, [String? part2, String? part3]) {
    return p.normalize(p.join(part1, part2 ?? '', part3 ?? ''));
  }

  /// Extracts the file extension (without the dot).
  static String getExtension(String path) {
    final ext = p.extension(path);
    return ext.isNotEmpty ? ext.substring(1).toLowerCase() : '';
  }

  /// Extracts the file name from a path.
  static String getName(String path) {
    return p.basename(path);
  }

  /// Sanitizes a file name to remove illegal characters.
  static String sanitizeFileName(String name) {
    // Basic sanitization for cross-platform safety
    return name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
  }
}
