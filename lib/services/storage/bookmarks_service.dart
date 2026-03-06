import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class BookmarkEntry {
  final String path;
  final String label;
  final DateTime addedAt;

  BookmarkEntry({required this.path, required this.label, required this.addedAt});
  Map<String, dynamic> toJson() => {'path': path, 'label': label, 'addedAt': addedAt.millisecondsSinceEpoch};
  factory BookmarkEntry.fromJson(Map<String, dynamic> j) => BookmarkEntry(path: j['path'], label: j['label'], addedAt: DateTime.fromMillisecondsSinceEpoch(j['addedAt']));
}

class BookmarksService {
  static File? _file;
  static List<BookmarkEntry> _bookmarks = [];

  static Future<void> init() async {
    if (_file != null) return;
    final docDir = await getApplicationDocumentsDirectory();
    _file = File(p.join(docDir.path, 'argus_bookmarks.json'));
    await _load();
  }

  static Future<void> _load() async {
    try {
      if (await _file!.exists()) {
        final json = jsonDecode(await _file!.readAsString()) as List;
        _bookmarks = json.map((e) => BookmarkEntry.fromJson(e)).toList();
      }
    } catch (_) { _bookmarks = []; }
  }

  static Future<void> _save() async {
    await _file!.writeAsString(jsonEncode(_bookmarks.map((e) => e.toJson()).toList()));
  }

  static Future<List<BookmarkEntry>> getAll() async {
    await init();
    return List.unmodifiable(_bookmarks);
  }

  static Future<bool> isBookmarked(String path) async {
    await init();
    return _bookmarks.any((b) => b.path == path);
  }

  static Future<void> add(String path, {String? label}) async {
    await init();
    if (_bookmarks.any((b) => b.path == path)) return;
    _bookmarks.add(BookmarkEntry(path: path, label: label ?? p.basename(path), addedAt: DateTime.now()));
    await _save();
  }

  static Future<void> remove(String path) async {
    await init();
    _bookmarks.removeWhere((b) => b.path == path);
    await _save();
  }

  static Future<void> rename(String path, String newLabel) async {
    await init();
    final idx = _bookmarks.indexWhere((b) => b.path == path);
    if (idx != -1) {
      _bookmarks[idx] = BookmarkEntry(path: path, label: newLabel, addedAt: _bookmarks[idx].addedAt);
      await _save();
    }
  }
}
