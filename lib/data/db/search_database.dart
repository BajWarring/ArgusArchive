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
    final String path = p.join(docDir.path, 'argus_fts5_search.db');

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // High-performance FTS5 table with unicode61 for diacritics/case-insensitivity
        await db.execute('''
          CREATE VIRTUAL TABLE file_index USING fts5(
            id UNINDEXED, 
            path, 
            name, 
            type UNINDEXED, 
            size UNINDEXED, 
            modifiedAt UNINDEXED,
            tokenize="unicode61 remove_diacritics 1"
          );
        ''');
      },
    );
  }

  Future<void> insertBatch(List<FileEntry> entries) async {
    final db = _db;
    if (db == null) throw Exception('Database not initialized');

    // Batch updates for massive performance gains
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

    final cleanQuery = query.trim().replaceAll(RegExp(r'[^\w\s]'), '');
    if (cleanQuery.isEmpty) return [];

    // Append '*' for prefix matching (e.g., 'and' matches 'android')
    final ftsQuery = cleanQuery.split(' ').map((word) => '$word*').join(' AND ');

    // BM25 Ranking: Weight 'name' column (index 2) much heavier than 'path' (index 1)
    String sql = '''
      SELECT *, bm25(file_index, 0, 1.0, 10.0, 0, 0, 0) as rank 
      FROM file_index 
      WHERE file_index MATCH ?
    ''';
    
    List<dynamic> args = [ftsQuery];

    if (filterType != null) {
      sql += ' AND type = ?';
      args.add(filterType.index);
    }
    if (minSize != null) {
      sql += ' AND size >= ?';
      args.add(minSize);
    }

    sql += ' ORDER BY rank LIMIT 100';

    final List<Map<String, dynamic>> maps = await db.rawQuery(sql, args);

    return maps.map((map) {
      return FileEntry(
        id: map['id'] as String,
        path: map['path'] as String,
        type: FileType.values[map['type'] as int],
        size: map['size'] as int,
        modifiedAt: DateTime.fromMillisecondsSinceEpoch(map['modifiedAt'] as int),
      );
    }).toList();
  }

  Future<void> clearIndex() async {
    if (_db != null) await _db!.delete('file_index');
  }
}
