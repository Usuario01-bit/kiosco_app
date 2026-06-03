import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {

  // =====================================================
  // SINGLETON
  // =====================================================
  static final DatabaseHelper instance =
  DatabaseHelper._init();

  static Database? _database;

  DatabaseHelper._init();

  // =====================================================
  // CACHE
  // =====================================================
  static final Map<String, List<Map<String, dynamic>>?>
      _listCache = {};

  static void _invalidateCache(String table) {
    _listCache.remove(table);
  }

  Future<List<Map<String, dynamic>>>
  _cachedQuery(String table, {String? orderBy}) async {
    if (_listCache.containsKey(table)) {
      return _listCache[table]!;
    }
    final db = await database;
    final result = await db.query(table, orderBy: orderBy);
    _listCache[table] = result;
    return result;
  }

  // =====================================================
  // DATABASE
  // =====================================================

  Future<Database> get database async {

    if (_database != null) {
      return _database!;
    }

    _database =
    await _initDB('kiosco.db');

    return _database!;
      }
  Future<List<Map<String, dynamic>>> getStudents() async {
    return _cachedQuery('students');
  }

  // =====================================================
  // INIT DB
  // =====================================================

  Future<Database> _initDB(
      String filePath,
      ) async {

    final dbPath =
    await getDatabasesPath();

    final path = join(
      dbPath,
      filePath,
    );

    return await openDatabase(

      path,

      version: 5,

      onCreate: _createDB,

      onUpgrade: _onUpgrade,
    );
  }

  // =====================================================
  // CREATE TABLES
  // =====================================================

  Future<void> _createDB(

      Database db,

      int version,
      ) async {

    // PRODUCTS

    await db.execute('''

      CREATE TABLE products (

        id INTEGER PRIMARY KEY AUTOINCREMENT,

        name TEXT,

        price REAL,

        stock INTEGER,

        icon TEXT DEFAULT 'inventory_2'
      )

    ''');

    // STUDENTS

    await db.execute('''

  CREATE TABLE students (

    id INTEGER PRIMARY KEY AUTOINCREMENT,

    name TEXT
  )

''');

    // SALES

    await db.execute('''

  CREATE TABLE sales (

  id INTEGER PRIMARY KEY AUTOINCREMENT,

  student TEXT,

  product TEXT,

  quantity INTEGER,

  total REAL,

  paymentMethod TEXT,

  date TEXT,

  time TEXT,

  recreo TEXT
)

    ''');

    // PENDING

    await db.execute('''

      CREATE TABLE pending(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  student TEXT,
  amount REAL,
  date TEXT,
  time TEXT,
  recreo TEXT,
  paid_at TEXT
)
    ''');


    // USERS

    await db.execute('''

      CREATE TABLE users(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  username TEXT UNIQUE,
  password_hash TEXT,
  salt TEXT
)
''');

    await _seedDefaultAdmin(db);
  }

  Future<void> _onUpgrade(
      Database db,
      int oldVersion,
      int newVersion,
      ) async {

    if (oldVersion < 3) {

      await db.execute('''

        CREATE TABLE IF NOT EXISTS users(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  username TEXT UNIQUE,
  password_hash TEXT,
  salt TEXT
)
''');

      await _seedDefaultAdmin(db);
    }

    if (oldVersion < 4) {

      try {

        await db.execute(
          'ALTER TABLE sales ADD COLUMN paid_at TEXT',
        );
      } catch (_) {

        // columna ya existe — ignorar
      }
    }

    if (oldVersion < 5) {

      try {

        await db.execute(
          "ALTER TABLE products ADD COLUMN icon TEXT DEFAULT 'inventory_2'",
        );
      } catch (_) {

        // columna ya existe — ignorar
      }
    }
  }

  Future<void> _seedDefaultAdmin(Database db) async {

    final existing = await db.query('users', where: 'username = ?', whereArgs: ['admin']);

    if (existing.isEmpty) {

      final salt = _generateSalt();

      final hash = _hashPassword('admin123', salt);

      await db.insert('users', {
        'username': 'admin',
        'password_hash': hash,
        'salt': salt,
      });
    }
  }

  String _generateSalt() {

    final random = List<int>.generate(16, (_) => DateTime.now().microsecondsSinceEpoch % 256);

    return base64Encode(random);
  }

  String _hashPassword(String password, String salt) {

    final bytes = utf8.encode(password + salt);

    return sha256.convert(bytes).toString();
  }

  // =====================================================
  // PRODUCTS
  // =====================================================


  Future<int> insertProduct(
      Map<String, dynamic> product,
      ) async {

    final db = await database;

    final columns =
    await db.rawQuery(
        "PRAGMA table_info('products')");

    final hasIcon = columns
        .any((c) => c['name'] == 'icon');

    if (!hasIcon) {

      product.remove('icon');
    }

    final id = await db.insert(
      'products',
      product,
    );
    _invalidateCache('products');
    return id;
  }

  Future<List<Map<String, dynamic>>>
  getProducts() async {
    return _cachedQuery('products', orderBy: 'id DESC');
  }

  Future<int> deleteProduct(
      int id,
      ) async {

    final db = await database;

    final rows = await db.delete(

      'products',

      where: 'id = ?',

      whereArgs: [id],
    );
    _invalidateCache('products');
    return rows;
  }

  Future<int> updateProduct(
      int id,
      Map<String, dynamic> data,
      ) async {

    final db = await database;

    final columns =
    await db.rawQuery(
        "PRAGMA table_info('products')");

    final hasIcon = columns
        .any((c) => c['name'] == 'icon');

    if (!hasIcon) {

      data.remove('icon');
    }

    final rows = await db.update(

      'products',
      data,

      where: 'id = ?',

      whereArgs: [id],
    );
    _invalidateCache('products');
    return rows;
  }

  Future<int> updateProductStock(
      int id,
      int newStock,
      ) async {

    final db = await database;

    final rows = await db.update(

      'products',

      {
        'stock': newStock,
      },

      where: 'id = ?',

      whereArgs: [id],
    );
    _invalidateCache('products');
    return rows;
  }

  // =====================================================
  // SALES
  // =====================================================

  Future<int> insertSale(
      Map<String, dynamic> sale,
      ) async {

    final db = await database;

    final id = await db.insert(
      'sales',
      sale,
    );
    _invalidateCache('sales');
    return id;
  }

  Future<List<Map<String, dynamic>>>
  getSales() async {
    return _cachedQuery('sales', orderBy: 'id DESC');
  }
  Future<int> paySale(int id) async {

    final db = await database;

    final now = DateTime.now().toIso8601String();

    final columns =
    await db.rawQuery("PRAGMA table_info('sales')");

    final hasPaidAt =
    columns.any((c) => c['name'] == 'paid_at');

    final rows = await db.update(

      'sales',

      hasPaidAt
          ? {
        'paymentMethod': 'Efectivo',
        'paid_at': now,
      }
          : {
        'paymentMethod': 'Efectivo',
      },

      where: 'id = ?',

      whereArgs: [id],
    );
    _invalidateCache('sales');
    return rows;
  }

  Future<void> payPendingSales(String student) async {

    final db = await database;

    final now = DateTime.now().toIso8601String();

    final columns =
    await db.rawQuery("PRAGMA table_info('sales')");

    final hasPaidAt =
    columns.any((c) => c['name'] == 'paid_at');

    if (hasPaidAt) {

      await db.update(

        'sales',

        {
          'paymentMethod': 'Efectivo',
          'paid_at': now,
        },

        where: 'student = ? AND paymentMethod = ?',

        whereArgs: [student, 'Pendiente'],
      );
    } else {

      await db.update(

        'sales',

        {
          'paymentMethod': 'Efectivo',
        },

        where: 'student = ? AND paymentMethod = ?',

        whereArgs: [student, 'Pendiente'],
      );
    }

    await db.delete(

      'pending',

      where: 'student = ?',

      whereArgs: [student],
    );
    _invalidateCache('sales');
    _invalidateCache('pending');
  }
  // =====================================================
  // PENDING
  // =====================================================

  Future<int> insertPending(
      Map<String, dynamic> pending,
      ) async {

    final db = await database;

    // BUSCAR SI YA EXISTE

    final existing = await db.query(

      'pending',

      where: 'student = ?',

      whereArgs: [
        pending['student'],
      ],
    );

    // SI EXISTE → SUMAR

    if (existing.isNotEmpty) {

      final currentAmount =
      (existing.first['amount']
      as num)
          .toDouble();

      final newAmount =
          currentAmount +
              (pending['amount']
              as num)
                  .toDouble();

      return await db.update(

        'pending',

        {
          'amount': newAmount,
        },

        where: 'student = ?',

        whereArgs: [
          pending['student'],
        ],
      );
    }

    // SI NO EXISTE → INSERTAR

    final id = await db.insert(
      'pending',
      pending,
    );
    _invalidateCache('pending');
    return id;
  }

  Future<List<Map<String, dynamic>>>
  getPendings() async {
    return _cachedQuery('pending', orderBy: 'id DESC');
  }

  Future<int> deletePending(
      int id,
      ) async {

    final db = await database;

    final rows = await db.delete(

      'pending',

      where: 'id = ?',

      whereArgs: [id],
    );
    _invalidateCache('pending');
    return rows;
  }
// =====================================================
// INSERT STUDENT
// =====================================================

  Future<int> insertStudent(
      Map<String, dynamic> row,
      ) async {

    final db = await database;

    final id = await db.insert(
      'students',
      row,
    );
    _invalidateCache('students');
    return id;
  }

// =====================================================
// DELETE STUDENT
// =====================================================

  Future<int> deleteStudent(
      int id,
      ) async {

    final db = await database;

    final rows = await db.delete(

      'students',

      where: 'id = ?',

      whereArgs: [id],
    );
    _invalidateCache('students');
    return rows;
  }
  // =====================================================
// SALES BY STUDENT
// =====================================================

  Future<List<Map<String, dynamic>>>
  getSalesByStudent(
      String student,
      ) async {

    final db = await database;

    return await db.query(

      'sales',

      where: 'student = ?',

      whereArgs: [student],

      orderBy: 'id DESC',
    );
  }
  // =====================================================
  // AUTH
  // =====================================================

  Future<Map<String, dynamic>?> login(
      String username,
      String password,
      ) async {

    final db = await database;

    final result = await db.query(

      'users',

      where: 'username = ?',

      whereArgs: [username.toLowerCase().trim()],
    );

    if (result.isEmpty) return null;

    final user = result.first;

    final hash = _hashPassword(
      password,
      user['salt'] as String,
    );

    if (hash != user['password_hash'] as String) return null;

    return user;
  }

  Future<bool> changePassword(
      String username,
      String oldPassword,
      String newPassword,
      ) async {

    final db = await database;

    final result = await db.query(

      'users',

      where: 'username = ?',

      whereArgs: [username.toLowerCase().trim()],
    );

    if (result.isEmpty) return false;

    final user = result.first;

    final oldHash = _hashPassword(oldPassword, user['salt'] as String);

    if (oldHash != user['password_hash'] as String) return false;

    final newSalt = _generateSalt();

    final newHash = _hashPassword(newPassword, newSalt);

    await db.update(

      'users',

      {
        'password_hash': newHash,
        'salt': newSalt,
      },

      where: 'id = ?',

      whereArgs: [user['id']],
    );

    return true;
  }

  // =====================================================
  // CLOSE
  // =====================================================

  Future close() async {

    final db = await database;

    db.close();
  }

Future<double> getStudentDebt(
  String student,
) async {

  final db = await database;

  final result =
  await db.rawQuery(
    '''
    SELECT SUM(total) as debt
    FROM sales
    WHERE student = ?
    AND paymentMethod = 'Pendiente'
    ''',

    [student],
  );

  return
  (result.first['debt']
  as num?)
      ?.toDouble() ??
  0.0;
}

Future<List<Map<String, dynamic>>>
getRecentSales(
  int limit,
) async {

  final db = await database;

  return await db.query(
    'sales',
    orderBy: 'id DESC',
    limit: limit,
  );
}

Future<double> getTotalSales() async {
  final db = await database;
  final result = await db.rawQuery(
    'SELECT COALESCE(SUM(total), 0) as total FROM sales',
  );
  return (result.first['total'] as num?)?.toDouble() ?? 0.0;
}

Future<int> getTotalSalesCount() async {
  final db = await database;
  final result = await db.rawQuery('SELECT COUNT(*) as count FROM sales');
  return (result.first['count'] as int?) ?? 0;
}

Future<double> getTotalPending() async {
  final db = await database;
  final result = await db.rawQuery(
    'SELECT COALESCE(SUM(amount), 0) as total FROM pending',
  );
  return (result.first['total'] as num?)?.toDouble() ?? 0.0;
}

Future<int> getProductsCount() async {
  final db = await database;
  final result = await db.rawQuery('SELECT COUNT(*) as count FROM products');
  return (result.first['count'] as int?) ?? 0;
}

  Future<double> getTodaySales() async {

    final db = await database;

    final now = DateTime.now();
    final today =
    '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final result =
    await db.rawQuery(
      '''
    SELECT SUM(total) as total
    FROM sales
    WHERE date = ?
    AND paymentMethod != 'Pendiente'
    ''',

      [today],
    );

    return
    (result.first['total']
    as num?)
        ?.toDouble() ??
    0.0;
  }

Future<String?> getTopProduct() async {

  final db = await database;

  final result =
  await db.rawQuery(
    '''
    SELECT product, SUM(quantity) as qty
    FROM sales
    GROUP BY product
    ORDER BY qty DESC
    LIMIT 1
    ''',
  );

  if (result.isEmpty) return null;

  return result.first['product'] as String?;
}

Future<List<Map<String, dynamic>>>
getWeeklySales() async {

  final db = await database;

  final weekAgo = DateTime.now()
      .subtract(const Duration(days: 6))
      .toIso8601String()
      .substring(0, 10);

  final result =
  await db.rawQuery(
    '''
    SELECT date, SUM(total) as total
    FROM sales
    WHERE date >= ? AND paymentMethod != 'Pendiente'
    GROUP BY date
    ORDER BY date ASC
    ''',

    [weekAgo],
  );

  return result;
}

Future<List<Map<String, dynamic>>>
getTopProducts(
  int limit,
) async {

  final db = await database;

  return await db.rawQuery(
    '''
    SELECT product, SUM(total) as total
    FROM sales
    GROUP BY product
    ORDER BY total DESC
    LIMIT ?
    ''',

    [limit],
  );
}
}