import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../core/models/file_entry.dart';
import '../../core/enums/file_type.dart';

class IndexDb {
  Database? _db;

  Future<void> init() async {
    if (_db != null) return;

    final Directory docDir = await getApplicationDocumentsDirectory();
    final String path = p.join(docDir.path, 'file_manager_index.db');

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE VIRTUAL TABLE file_index USING fts5(
            id UNINDEXED, 
            path, 
            name, 
            type UNINDEXED, 
            size UNINDEXED, 
            modifiedAt UNINDEXED
          );
        ''');
      },
    );
  }

  Future<void> insert(FileEntry entry) async {
    final db = _db;
    if (db == null) throw Exception('Database not initialized');

    final name = p.basename(entry.path);

    await db.delete('file_index', where: 'id = ?', whereArgs: [entry.id]);

    await db.insert('file_index', {
      'id': entry.id,
      'path': entry.path,
      'name': name,
      'type': entry.type.index,
      'size': entry.size,
      'modifiedAt': entry.modifiedAt.millisecondsSinceEpoch,
    });
  }

  Future<void> delete(String id) async {
    final db = _db;
    if (db == null) throw Exception('Database not initialized');
    await db.rawDelete('DELETE FROM file_index WHERE id = ? OR path LIKE ?', [id, '$id/%']);
  }

  Future<List<FileEntry>> search(String query) async {
    final db = _db;
    if (db == null) throw Exception('Database not initialized');

    if (query.trim().isEmpty) return [];

    final sanitizedQuery = '${query.replaceAll(RegExp(r'[^\w\s]'), '')}*';

    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT * FROM file_index 
      WHERE file_index MATCH ? 
      ORDER BY rank
      LIMIT 100
    ''', [sanitizedQuery]);

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
    final db = _db;
    if (db != null) {
      await db.delete('file_index');
    }
  }
}
