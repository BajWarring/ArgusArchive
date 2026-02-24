import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../core/models/file_entry.dart';
import '../../core/enums/file_type.dart';

class SearchDatabase {
  Database? _db;

  Future<void> init() async {
    if (_db != null) return;

    final Directory docDir = await getApplicationDocumentsDirectory();
    final String path = p.join(docDir.path, 'argus_fts4_search_v2.db'); 

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Bulletproof FTS4: Stripped of advanced modifiers for maximum device compatibility
        await db.execute('''
          CREATE VIRTUAL TABLE file_index USING fts4(
            id, 
            path, 
            name, 
            type, 
            size, 
            modifiedAt,
            tokenize=unicode61
          );
        ''');
      },
    );
  }

  Future<void> insertBatch(List<FileEntry> entries) async {
    final db = _db;
    if (db == null) throw Exception('Database not initialized');

    final batch = db.batch();
    for (var entry in entries) {
      final name = p.basename(entry.path);
      batch.delete('file_index', where: 'id = ?', whereArgs: [entry.id]);
      batch.insert('file_index', {
        'id': entry.id,
        'path': entry.path,
        'name': name,
        'type': entry.type.index,
        'size': entry.size,
        'modifiedAt': entry.modifiedAt.millisecondsSinceEpoch,
      });
    }
    await batch.commit(noResult: true);
  }

  Future<void> delete(String id) async {
    final db = _db;
    if (db == null) throw Exception('Database not initialized');
    await db.rawDelete('DELETE FROM file_index WHERE id = ? OR path LIKE ?', [id, '$id/%']);
  }

  Future<List<FileEntry>> search({
    required String query, 
    FileType? filterType,
    int? minSize,
    int? maxSize,
  }) async {
    final db = _db;
    if (db == null) throw Exception('Database not initialized');

    // Make the query strictly alphanumeric to prevent SQLite syntax crashes
    final cleanQuery = query.trim().replaceAll(RegExp(r'[^\w\s]'), '');

    // FIX: If the search bar is empty, but we requested a specific file type (like Videos),
    // return them sorted by newest! This powers the sub-app libraries.
    if (cleanQuery.isEmpty) {
      if (filterType == null) return []; 
      
      String sql = 'SELECT * FROM file_index WHERE type = ? ORDER BY modifiedAt DESC LIMIT 200';
      final List<Map<String, dynamic>> maps = await db.rawQuery(sql, [filterType.index]);
      
      return maps.map((map) {
        return FileEntry(
          id: map['id'] as String,
          path: map['path'] as String,
          type: FileType.values[int.parse(map['type'].toString())],
          size: int.parse(map['size'].toString()),
          modifiedAt: DateTime.fromMillisecondsSinceEpoch(int.parse(map['modifiedAt'].toString())),
        );
      }).toList();
    }

    // Format for FTS4 wildcard matching (e.g. searching "Aadh" matches "Aadhaar")
    final ftsQuery = cleanQuery.split(' ').map((word) => '$word*').join(' ');

    String sql = '''
      SELECT * FROM file_index 
      WHERE file_index MATCH ?
    ''';
    
    List<dynamic> args = [ftsQuery];

    if (filterType != null) {
      sql += ' AND type = ?';
      args.add(filterType.index);
    }

    sql += ' LIMIT 150';

    final List<Map<String, dynamic>> maps = await db.rawQuery(sql, args);

    return maps.map((map) {
      return FileEntry(
        id: map['id'] as String,
        path: map['path'] as String,
        type: FileType.values[int.parse(map['type'].toString())],
        size: int.parse(map['size'].toString()),
        modifiedAt: DateTime.fromMillisecondsSinceEpoch(int.parse(map['modifiedAt'].toString())),
      );
    }).toList();
  }

  Future<void> clearIndex() async {
    if (_db != null) await _db!.delete('file_index');
  }

  Future<bool> isEmpty() async {
    final db = _db;
    if (db == null) return true;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM file_index');
    final count = Sqflite.firstIntValue(result);
    return count == null || count == 0;
  }
}
