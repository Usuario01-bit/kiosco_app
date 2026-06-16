import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class LocalCacheService {
  LocalCacheService._();
  static final instance = LocalCacheService._();

  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, 'kiosco_cache.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE products_cache (
            id TEXT PRIMARY KEY,
            data TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE students_cache (
            id TEXT PRIMARY KEY,
            data TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
      },
    );
  }

  Future<void> cacheProducts(List<Map<String, dynamic>> products) async {
    final now = DateTime.now().toIso8601String();
    final database = await db;
    final batch = database.batch();
    batch.delete('products_cache');
    for (final p in products) {
      batch.insert('products_cache', {
        'id': p['id'].toString(),
        'data': jsonEncode(p),
        'updated_at': now,
      });
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getCachedProducts() async {
    final database = await db;
    final rows = await database.query('products_cache', orderBy: 'updated_at DESC');
    return rows.map((r) {
      final data = jsonDecode(r['data'] as String) as Map<String, dynamic>;
      return data;
    }).toList();
  }

  Future<void> cacheStudents(List<Map<String, dynamic>> students) async {
    final now = DateTime.now().toIso8601String();
    final database = await db;
    final batch = database.batch();
    batch.delete('students_cache');
    for (final s in students) {
      batch.insert('students_cache', {
        'id': s['id'].toString(),
        'data': jsonEncode(s),
        'updated_at': now,
      });
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getCachedStudents() async {
    final database = await db;
    final rows = await database.query('students_cache', orderBy: 'updated_at DESC');
    return rows.map((r) {
      return jsonDecode(r['data'] as String) as Map<String, dynamic>;
    }).toList();
  }

  Future<Map<String, dynamic>?> getLastSync(String table) async {
    final database = await db;
    final rows = await database.query(
      '${table}_cache',
      columns: ['updated_at'],
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return {'updated_at': rows.first['updated_at']};
  }
}
