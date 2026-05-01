import 'dart:io';

class ThumbnailCache {
  static final _memoryCache = <String, File>{};
  static const int maxMemoryItems = 100;
  static const int maxDiskSizeMB = 100;
  static String cacheDir = '/storage/emulated/0/.alle_cache';

  /// GET — memory first, then disk, promotes to memory on disk hit
  static Future<File?> get(String key) async {
    if (_memoryCache.containsKey(key)) {
      final value = _memoryCache.remove(key)!;
      _memoryCache[key] = value; // move to end (LRU)
      return value;
    }
    final file = File('$cacheDir/$key.jpg');
    if (await file.exists()) {
      _memoryCache[key] = file;
      _enforceMemoryLimit();
      return file;
    }
    return null;
  }

  /// SAVE — write to disk + memory
  static Future<void> save(String key, List<int> bytes) async {
    final dir = Directory(cacheDir);
    if (!await dir.exists()) await dir.create(recursive: true);
    final file = File('$cacheDir/$key.jpg');
    await file.writeAsBytes(bytes);
    _memoryCache[key] = file;
    _enforceMemoryLimit();
    await _enforceDiskLimit();
  }

  /// Evict oldest memory entries
  static void _enforceMemoryLimit() {
    while (_memoryCache.length > maxMemoryItems) {
      _memoryCache.remove(_memoryCache.keys.first);
    }
  }

  /// Evict oldest disk entries (by last-accessed time)
  static Future<void> _enforceDiskLimit() async {
    final dir = Directory(cacheDir);
    if (!await dir.exists()) return;
    final files = dir.listSync().whereType<File>().toList();
    int totalSize = files.fold(0, (sum, f) => sum + f.lengthSync());
    const maxBytes = maxDiskSizeMB * 1024 * 1024;
    if (totalSize <= maxBytes) return;
    files.sort((a, b) => a.lastAccessedSync().compareTo(b.lastAccessedSync()));
    for (final file in files) {
      if (totalSize <= maxBytes) break;
      final size = file.lengthSync();
      await file.delete();
      totalSize -= size;
    }
  }

  /// Generate a stable cache key. Pass [modified] to invalidate stale files.
  static String generateKey(String path, [DateTime? modified]) {
    if (modified != null) {
      return '${path.hashCode}_${modified.millisecondsSinceEpoch}';
    }
    return path.hashCode.toString();
  }
}
