import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class TrashItem {
  final String originalPath;
  final String trashPath;
  final DateTime deletedAt;
  final int size;
  final bool isDirectory;

  TrashItem({required this.originalPath, required this.trashPath, required this.deletedAt, required this.size, required this.isDirectory});

  Map<String, dynamic> toJson() => {'originalPath': originalPath, 'trashPath': trashPath, 'deletedAt': deletedAt.millisecondsSinceEpoch, 'size': size, 'isDirectory': isDirectory};
  factory TrashItem.fromJson(Map<String, dynamic> j) => TrashItem(
    originalPath: j['originalPath'], trashPath: j['trashPath'],
    deletedAt: DateTime.fromMillisecondsSinceEpoch(j['deletedAt']),
    size: j['size'], isDirectory: j['isDirectory'],
  );
}

class TrashService {
  static Directory? _trashDir;
  static File? _metaFile;
  static List<TrashItem> _items = [];

  static Future<void> init() async {
    final docDir = await getApplicationDocumentsDirectory();
    _trashDir = Directory(p.join(docDir.path, '.argus_trash'));
    _metaFile = File(p.join(docDir.path, '.argus_trash_meta.json'));
    await _trashDir!.create(recursive: true);
    await _loadMeta();
  }

  static Future<void> _loadMeta() async {
    try {
      if (await _metaFile!.exists()) {
        final json = jsonDecode(await _metaFile!.readAsString()) as List;
        _items = json.map((e) => TrashItem.fromJson(e)).toList();
      }
    } catch (_) { _items = []; }
  }

  static Future<void> _saveMeta() async {
    await _metaFile!.writeAsString(jsonEncode(_items.map((e) => e.toJson()).toList()));
  }

  static Future<bool> moveToTrash(String sourcePath) async {
    try {
      await init();
      final isDir = await FileSystemEntity.isDirectory(sourcePath);
      final stat = await FileStat.stat(sourcePath);
      final trashName = '${DateTime.now().millisecondsSinceEpoch}_${p.basename(sourcePath)}';
      final trashPath = p.join(_trashDir!.path, trashName);

      if (isDir) {
        await Directory(sourcePath).rename(trashPath);
      } else {
        await File(sourcePath).rename(trashPath);
      }

      _items.add(TrashItem(
        originalPath: sourcePath, trashPath: trashPath,
        deletedAt: DateTime.now(), size: stat.size, isDirectory: isDir,
      ));
      await _saveMeta();
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<List<TrashItem>> getItems() async {
    await init();
    return List.unmodifiable(_items);
  }

  static Future<bool> restore(TrashItem item) async {
    try {
      final destDir = Directory(p.dirname(item.originalPath));
      if (!await destDir.exists()) await destDir.create(recursive: true);

      if (item.isDirectory) {
        await Directory(item.trashPath).rename(item.originalPath);
      } else {
        await File(item.trashPath).rename(item.originalPath);
      }
      _items.removeWhere((i) => i.trashPath == item.trashPath);
      await _saveMeta();
      return true;
    } catch (_) { return false; }
  }

  static Future<bool> deletePermanently(TrashItem item) async {
    try {
      if (item.isDirectory) {
        await Directory(item.trashPath).delete(recursive: true);
      } else {
        await File(item.trashPath).delete();
      }
      _items.removeWhere((i) => i.trashPath == item.trashPath);
      await _saveMeta();
      return true;
    } catch (_) { return false; }
  }

  static Future<void> emptyTrash() async {
    await init();
    for (final item in _items) {
      try {
        if (item.isDirectory) {
          await Directory(item.trashPath).delete(recursive: true);
        } else {
          await File(item.trashPath).delete();
        }
      } catch (_) {}
    }
    _items.clear();
    await _saveMeta();
  }

  static int get totalItems => _items.length;
}
