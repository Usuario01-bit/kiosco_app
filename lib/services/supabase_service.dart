import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'date_utils.dart';
import 'local_cache_service.dart';

class SupabaseService {

  static final SupabaseService instance = SupabaseService._();
  SupabaseService._();

  SupabaseClient get _client => Supabase.instance.client;

  // =====================================================
  // NAME CACHE — resolves FK names in streams without JOIN
  // =====================================================

  Map<String, String> _studentNames = {};
  Map<String, Map<String, dynamic>> _productInfo = {};
  bool _cacheInitialized = false;

  void _ensureCache() {
    if (_cacheInitialized) return;
    _cacheInitialized = true;
    _client.from('students').stream(primaryKey: ['id']).listen((data) {
      _studentNames = {for (final s in data) s['id'].toString(): s['name'] as String? ?? ''};
    }, onError: (_) {});
    _client.from('products').stream(primaryKey: ['id']).listen((data) {
      _productInfo = {for (final p in data) p['id'].toString(): p};
    }, onError: (_) {});
  }

  // =====================================================
  // HELPERS
  // =====================================================

  Map<String, dynamic> _flattenStudent(Map<String, dynamic> row) {
    if (row['students'] is Map) {
      row['student'] = row['students']['name'];
      row.remove('students');
    } else if (row['student_id'] != null && _studentNames.containsKey(row['student_id'])) {
      row['student'] = _studentNames[row['student_id']];
    }
    if (row['products'] is Map) {
      final p = row['products'] as Map;
      row['product'] = p['name'] ?? '';
      row['icon'] = p['icon'] ?? row['icon'] ?? '';
      row.remove('products');
    } else if (row['product_id'] != null && _productInfo.containsKey(row['product_id'])) {
      row['product'] = _productInfo[row['product_id']]?['name'] ?? '';
      row['icon'] = _productInfo[row['product_id']]?['icon'] ?? '';
    }
    return row;
  }

  List<Map<String, dynamic>> _flattenStudents(List<Map<String, dynamic>> rows) {
    _ensureCache();
    for (final row in rows) {
      _flattenStudent(row);
    }
    return rows;
  }

  DateTime? _parseDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    if (raw.contains('-')) {
      return DateTime.tryParse(raw);
    }
    final parts = raw.split('/');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[2]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[0]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  // =====================================================
  // STUDENTS
  // =====================================================

  Future<void> insertStudent(Map<String, dynamic> row) async {
    final tempPw = row['tempPassword'] as String? ?? _generateTempPassword();
    await _client.from('students').insert({
      'name': row['name'],
      if (row.containsKey('code') && row['code'] != null && (row['code'] as String).trim().isNotEmpty)
        'code': row['code'].toString().trim(),
      if (row.containsKey('grado') && row['grado'] != null && (row['grado'] as String).trim().isNotEmpty)
        'grade': row['grado'].toString().trim(),
      'role': row['role'] ?? 'alumno',
      'temp_password': tempPw,
    });
  }

  Future<int> insertManyStudents(List<Map<String, dynamic>> students) async {
    final rows = students.map((row) {
      return {
        'name': row['name'],
        if (row.containsKey('code') && row['code'] != null && (row['code'] as String).trim().isNotEmpty)
          'code': row['code'].toString().trim(),
        if (row.containsKey('grado') && row['grado'] != null && (row['grado'] as String).trim().isNotEmpty)
          'grade': row['grado'].toString().trim(),
        'role': row['role'] ?? 'alumno',
        'temp_password': _generateTempPassword(),
      };
    }).toList();
    await _client.from('students').insert(rows);
    return students.length;
  }

  String _generateTempPassword() {
    final rng = Random.secure();
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789';
    return List.generate(8, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  Future<List<Map<String, dynamic>>> getStudents() async {
    final data = await _client.from('students').select().order('name');
    return data;
  }

  Future<int> deleteStudent(dynamic id) async {
    await _client.from('students').delete().eq('id', id.toString());
    return 1;
  }

  Future<int> deleteAllStudents() async {
    final data = await _client.from('students').select('id');
    final ids = data.map((r) => r['id'] as String).toList();
    if (ids.isEmpty) return 0;
    await _client.from('students').delete().inFilter('id', ids);
    return ids.length;
  }

  Stream<List<Map<String, dynamic>>> streamStudents() {
    return _client.from('students').stream(primaryKey: ['id']).order('name').map((data) {
      LocalCacheService.instance.cacheStudents(data);
      return data;
    });
  }

  Future<List<Map<String, dynamic>>> loadProducts() async {
    try {
      final data = await getProducts();
      await LocalCacheService.instance.cacheProducts(data);
      return data;
    } catch (_) {
      return LocalCacheService.instance.getCachedProducts();
    }
  }

  Future<List<Map<String, dynamic>>> loadStudents() async {
    try {
      final data = await getStudents();
      await LocalCacheService.instance.cacheStudents(data);
      return data;
    } catch (_) {
      return LocalCacheService.instance.getCachedStudents();
    }
  }

  Future<List<Map<String, dynamic>>> searchStudentsByName(String query) async {
    if (query.trim().isEmpty) return [];
    final data = await _client.from('students').select().ilike('name', '%${query.trim()}%').limit(10).order('name');
    return data;
  }

  Future<Map<String, dynamic>?> getStudentByCode(String code) async {
    final data = await _client.from('students').select().eq('code', code.trim()).limit(1);
    if (data.isEmpty) return null;
    return data.first;
  }

  Future<Map<String, dynamic>?> getStudentByQrToken(String token) async {
    final data = await _client.from('students').select().eq('qr_token', token.trim()).limit(1);
    if (data.isEmpty) return null;
    return data.first;
  }

  Future<Map<String, dynamic>?> verifyStudentLogin(String name, String password) async {
    try {
      final result = await _client.rpc('verify_student', params: {
        'p_name': name.trim(),
        'p_password': password.trim(),
      });
      if (result == null) return null;
      return result as Map<String, dynamic>;
    } catch (e) {
      debugPrint('verify_student RPC error: $e');
      return null;
    }
  }

  Future<void> setStudentTempPassword(dynamic studentId, String password) async {
    await _client.from('students').update({'temp_password': password.trim()}).eq('id', studentId.toString());
  }

  Future<void> setStudentQrToken(dynamic studentId, String token) async {
    await _client.from('students').update({'qr_token': token.trim()}).eq('id', studentId.toString());
  }

  Future<void> setStudentCode(dynamic studentId, String code) async {
    await _client.from('students').update({'code': code.trim()}).eq('id', studentId.toString());
  }

  // =====================================================
  // PRODUCTS
  // =====================================================

  Future<void> seedDefaultProducts() async {
    final defaultProducts = [
      {'name': 'Jamón / Salami', 'price': 1.50, 'stock': 999, 'icon': 'breakfast_dining', 'category': 'Emparedados'},
      {'name': 'Peperoni / Pollo', 'price': 1.75, 'stock': 999, 'icon': 'local_pizza', 'category': 'Emparedados'},
      {'name': 'Empanada Queso', 'price': 1.00, 'stock': 999, 'icon': 'set_meal', 'category': 'Empanadas'},
      {'name': 'Empanada Carne', 'price': 1.00, 'stock': 999, 'icon': 'set_meal', 'category': 'Empanadas'},
      {'name': 'Empanada Pollo', 'price': 1.00, 'stock': 999, 'icon': 'set_meal', 'category': 'Empanadas'},
      {'name': 'Derretido Queso Amarillo', 'price': 2.25, 'stock': 999, 'icon': 'bakery_dining', 'category': 'Especiales'},
      {'name': 'Hot Dog', 'price': 2.50, 'stock': 999, 'icon': 'fastfood', 'category': 'Especiales'},
      {'name': 'Hamburguesa', 'price': 2.75, 'stock': 999, 'icon': 'lunch_dining', 'category': 'Especiales'},
      {'name': 'Café Negro', 'price': 0.60, 'stock': 999, 'icon': 'coffee', 'category': 'Café'},
      {'name': 'Café con Leche', 'price': 0.75, 'stock': 999, 'icon': 'coffee', 'category': 'Café'},
      {'name': 'Té', 'price': 0.50, 'stock': 999, 'icon': 'emoji_food_beverage', 'category': 'Café'},
      {'name': 'Jugo Tetrapack', 'price': 0.60, 'stock': 999, 'icon': 'water_drop', 'category': 'Bebidas'},
      {'name': 'Jugo de Lata', 'price': 0.80, 'stock': 999, 'icon': 'local_drink', 'category': 'Bebidas'},
      {'name': 'Agua Saborizada', 'price': 1.00, 'stock': 999, 'icon': 'water_drop', 'category': 'Bebidas'},
      {'name': 'Jugo Natural', 'price': 1.00, 'stock': 999, 'icon': 'local_drink', 'category': 'Bebidas'},
      {'name': 'Té Frío', 'price': 1.00, 'stock': 999, 'icon': 'emoji_food_beverage', 'category': 'Bebidas'},
      {'name': 'Duro Fresa - Leche Condensada', 'price': 1.00, 'stock': 999, 'icon': 'icecream', 'category': 'Duros'},
      {'name': 'Duro Piña', 'price': 0.50, 'stock': 999, 'icon': 'apple', 'category': 'Duros'},
      {'name': 'Duro Mango', 'price': 0.50, 'stock': 999, 'icon': 'apple', 'category': 'Duros'},
      {'name': 'Duro Sandía', 'price': 0.50, 'stock': 999, 'icon': 'apple', 'category': 'Duros'},
      {'name': 'Duro Nance', 'price': 0.50, 'stock': 999, 'icon': 'apple', 'category': 'Duros'},
    ];

    final existing = await _client.from('products').select('name');
    final existingNames = existing.map((d) => d['name'] as String? ?? '').toSet();

    final toInsert = defaultProducts.where((p) => !existingNames.contains(p['name'])).toList();
    if (toInsert.isNotEmpty) {
      await _client.from('products').insert(toInsert);
    }
    debugPrint('Seeded ${toInsert.length} default products');
  }

  Future<void> insertProduct(Map<String, dynamic> data) async {
    await _client.from('products').insert({
      'name': data['name'],
      'price': (data['price'] as num).toDouble(),
      'stock': (data['stock'] as num).toInt(),
      'icon': data['icon'] ?? 'inventory_2',
      'category': data['category'] ?? 'General',
    });
  }

  Future<List<Map<String, dynamic>>> getProducts() async {
    return await _client.from('products').select().order('name');
  }

  Future<int> deleteProduct(dynamic id) async {
    await _client.from('products').delete().eq('id', id.toString());
    return 1;
  }

  Future<int> updateProduct(dynamic id, Map<String, dynamic> data) async {
    await _client.from('products').update({
      'name': data['name'],
      'price': (data['price'] as num).toDouble(),
      'stock': (data['stock'] as num).toInt(),
      if (data['icon'] != null) 'icon': data['icon'],
      if (data['category'] != null) 'category': data['category'],
    }).eq('id', id.toString());
    return 1;
  }

  Future<int> updateProductStock(dynamic id, int newStock) async {
    await _client.from('products').update({'stock': newStock}).eq('id', id.toString());
    return 1;
  }

  Future<void> insertSalesBatch(List<Map<String, dynamic>> sales) async {
    await _client.from('sales').insert(sales);
  }

  Future<Map<String, dynamic>?> getProductById(dynamic id) async {
    final data = await _client.from('products').select().eq('id', id.toString()).limit(1);
    if (data.isEmpty) return null;
    return data.first;
  }

  Stream<List<Map<String, dynamic>>> streamProducts() {
    return _client.from('products').stream(primaryKey: ['id']).order('category').order('name').map((data) {
      LocalCacheService.instance.cacheProducts(data);
      return data;
    });
  }

  // =====================================================
  // SALES
  // =====================================================

  Future<void> insertSale(Map<String, dynamic> sale) async {
    await _client.from('sales').insert({
      'student_id': sale['studentId'],
      'product_id': sale['productId'],
      'quantity': (sale['quantity'] as num).toInt(),
      'total': (sale['total'] as num).toDouble(),
      'payment_method': sale['paymentMethod'],
      'date': sale['date'],
      'time': sale['time'],
      'recreo': sale['recreo'] ?? '',
      'paid_at': sale['paidAt'],
      'prepared_at': sale['preparedAt'],
    });
  }

  Future<void> checkoutStudentOrder({
    required Map<String, dynamic> student,
    required List<Map<String, dynamic>> cartItems,
    required String recreo,
    required String paymentMethod,
    required String date,
    required String time,
  }) async {
    final studentId = student['id']?.toString();
    if (studentId == null || studentId.isEmpty) return;

    final items = cartItems.map((item) {
      final product = item['product'] as Map<String, dynamic>;
      return {
        'product_id': product['id']?.toString(),
        'quantity': item['quantity'],
      };
    }).toList();

    await _client.rpc('student_checkout', params: {
      'p_student_id': studentId,
      'p_cart_items': items,
      'p_recreo': recreo,
      'p_payment_method': paymentMethod,
      'p_date': date,
      'p_time': time,
    });
  }

  Future<void> markStudentRecreoAsPrepared(String studentName, String recreo) async {
    final now = DateTime.now();
    final today = toISODate(now);

    final studentData = await _client.from('students').select('id').eq('name', studentName).limit(1);
    if (studentData.isEmpty) return;
    final studentId = studentData.first['id'].toString();

    final snap = await _client.from('sales').select('total').eq('student_id', studentId).eq('date', today).eq('recreo', recreo).isFilter('prepared_at', null);

    double total = 0;
    for (final doc in snap) {
      total += (doc['total'] as num?)?.toDouble() ?? 0;
    }

    await _client.from('sales').update({
      'payment_method': 'Pendiente',
      'prepared_at': now.toIso8601String(),
    }).eq('student_id', studentId).eq('date', today).eq('recreo', recreo).isFilter('prepared_at', null).isFilter('paid_at', null);

    if (total > 0) {
      await insertPending({
        'student': studentName,
        'student_id': studentId,
        'amount': total,
        'created_at': now.toIso8601String(),
      });
    }
  }

  Future<void> markStudentRecreoAsPaid(String studentName, String recreo, String paymentMethod) async {
    final now = DateTime.now();
    final today = toISODate(now);

    final studentData = await _client.from('students').select('id').eq('name', studentName).limit(1);
    if (studentData.isEmpty) return;
    final studentId = studentData.first['id'].toString();

    await _client.from('sales').update({
      'payment_method': paymentMethod,
      'paid_at': now.toIso8601String(),
      'prepared_at': now.toIso8601String(),
    }).eq('student_id', studentId).eq('date', today).eq('recreo', recreo);
  }

  Stream<int> streamActiveOrdersCount() {
    final now = DateTime.now();
    final today = toISODate(now);
    return _client.from('sales').stream(primaryKey: ['id']).eq('date', today).map((snap) {
      return snap
          .where((s) => s['prepared_at'] == null)
          .map((s) => s['student_id'] as String)
          .toSet()
          .length;
    });
  }

  Stream<List<Map<String, dynamic>>> streamTodaySales() {
    final now = DateTime.now();
    final today = toISODate(now);
    return _client.from('sales').stream(primaryKey: ['id']).eq('date', today).order('time').map((data) {
      return _flattenStudents(data);
    });
  }

  List<Map<String, dynamic>> _sortSalesByDateTime(List<Map<String, dynamic>> sales) {
    sales.sort((a, b) {
      final aDate = _parseDate(a['date'] as String?);
      final bDate = _parseDate(b['date'] as String?);
      if (aDate != null && bDate != null) {
        final cmp = bDate.compareTo(aDate);
        if (cmp != 0) return cmp;
      } else if (aDate != null) {
        return -1;
      } else if (bDate != null) {
        return 1;
      }
      return (b['time'] as String? ?? '').compareTo(a['time'] as String? ?? '');
    });
    return sales;
  }

  Future<List<Map<String, dynamic>>> getSales() async {
    final data = await _client.from('sales').select('*, students!inner(name), products!inner(name)').order('date', ascending: false);
    return _sortSalesByDateTime(_flattenStudents(data));
  }

  Future<int> paySale(dynamic id) async {
    await _client.from('sales').update({
      'payment_method': 'Efectivo',
      'paid_at': DateTime.now().toIso8601String(),
    }).eq('id', id.toString());
    return 1;
  }

  Stream<List<Map<String, dynamic>>> streamSales() {
    return _client.from('sales').stream(primaryKey: ['id']).order('date', ascending: false).map((data) {
      return _sortSalesByDateTime(_flattenStudents(data));
    });
  }

  Future<void> payPendingSales(String studentName, dynamic pendingId) async {
    final studentData = await _client.from('students').select('id').eq('name', studentName).limit(1);
    if (studentData.isEmpty) return;
    final studentId = studentData.first['id'].toString();

    // Mark all unpaid pending sales as paid
    final now = DateTime.now().toIso8601String();
    await _client.from('sales').update({
      'payment_method': 'Efectivo',
      'paid_at': now,
    }).eq('student_id', studentId).isFilter('paid_at', null).ilike('payment_method', '%pendiente%');

    // Pay the full pending amount
    if (pendingId != null) {
      final pendingSnap = await _client.from('pending').select('amount').eq('id', pendingId.toString()).limit(1);
      if (pendingSnap.isNotEmpty) {
        final fullAmount = (pendingSnap.first['amount'] as num?)?.toDouble() ?? 0;
        await _client.from('pending').update({
          'paid': fullAmount,
          'paid_at': now,
        }).eq('id', pendingId.toString());
      }
    }
  }

  Future<List<Map<String, dynamic>>> getSalesByStudent(String studentName) async {
    final studentData = await _client.from('students').select('id').eq('name', studentName).limit(1);
    if (studentData.isEmpty) return [];
    final studentId = studentData.first['id'].toString();
    final data = await _client.from('sales').select('*, students!inner(name), products!inner(name)').eq('student_id', studentId);
    return _sortSalesByDateTime(_flattenStudents(data));
  }

  Future<List<Map<String, dynamic>>> getSalesByStudentId(String studentId) async {
    final data = await _client.from('sales').select('*, students!inner(name), products!inner(name)').eq('student_id', studentId);
    return _sortSalesByDateTime(_flattenStudents(data));
  }

  Future<List<Map<String, dynamic>>> getRecentSales(int limit) async {
    final data = await _client.from('sales').select('*, students!inner(name), products!inner(name)').order('date', ascending: false).limit(limit);
    return _flattenStudents(data);
  }

  Future<double> getTodaySales() async {
    final now = DateTime.now();
    final today = toISODate(now);
    final data = await _client.from('sales').select('total,payment_method').eq('date', today);
    double sum = 0;
    for (final doc in data) {
      final m = doc['payment_method'] as String? ?? '';
      if (m.toLowerCase().contains('pendiente')) continue;
      sum += (doc['total'] as num?)?.toDouble() ?? 0;
    }
    return sum;
  }

  Future<String?> getTopProduct() async {
    final monthAgo = DateTime.now().subtract(const Duration(days: 30)).toIso8601String().substring(0, 10);
    final data = await _client.from('sales').select('quantity, products!inner(name)').gte('date', monthAgo);
    final Map<String, int> counts = {};
    for (final doc in data) {
      final p = doc['products'] is Map ? (doc['products']['name'] as String? ?? '') : '';
      final q = (doc['quantity'] as num?)?.toInt() ?? 0;
      counts[p] = (counts[p] ?? 0) + q;
    }
    if (counts.isEmpty) return null;
    return counts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  Future<List<Map<String, dynamic>>> getWeeklySales() async {
    final weekAgo = DateTime.now().subtract(const Duration(days: 6)).toIso8601String().substring(0, 10);
    final data = await _client.from('sales').select('date,total,payment_method').gte('date', weekAgo);
    final Map<String, double> grouped = {};
    for (final doc in data) {
      final pm = doc['payment_method'] as String? ?? '';
      if (pm.toLowerCase().contains('pendiente')) continue;
      final date = doc['date'] as String? ?? '';
      final total = (doc['total'] as num?)?.toDouble() ?? 0;
      grouped[date] = (grouped[date] ?? 0) + total;
    }
    final sorted = grouped.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return sorted.map((e) => {'date': e.key, 'total': e.value}).toList();
  }

  Future<List<Map<String, dynamic>>> getTopProducts(int limit) async {
    final monthAgo = DateTime.now().subtract(const Duration(days: 30)).toIso8601String().substring(0, 10);
    final data = await _client.from('sales').select('total, products!inner(name)').gte('date', monthAgo);
    final Map<String, double> totals = {};
    for (final doc in data) {
      final product = doc['products'] is Map ? (doc['products']['name'] as String? ?? '') : '';
      final total = (doc['total'] as num?)?.toDouble() ?? 0;
      totals[product] = (totals[product] ?? 0) + total;
    }
    final sorted = totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).map((e) => {'product': e.key, 'total': e.value}).toList();
  }

  Future<double> getStudentDebt(String studentName) async {
    final studentData = await _client.from('students').select('id').eq('name', studentName).limit(1);
    if (studentData.isEmpty) return 0;
    final studentId = studentData.first['id'].toString();
    final pendingSnap = await _client.from('pending').select('amount,paid').eq('student_id', studentId).limit(1);
    if (pendingSnap.isNotEmpty) {
      final data = pendingSnap.first;
      final amount = (data['amount'] as num?)?.toDouble() ?? 0;
      final paid = (data['paid'] as num?)?.toDouble() ?? 0;
      return amount - paid;
    }
    return 0;
  }

  Future<List<Map<String, dynamic>>> getTodaySalesByStudent(String studentName) async {
    final now = DateTime.now();
    final today = toISODate(now);
    final studentData = await _client.from('students').select('id').eq('name', studentName).limit(1);
    if (studentData.isEmpty) return [];
    final studentId = studentData.first['id'].toString();
    return await _client.from('sales').select('*, products!inner(name)').eq('student_id', studentId).eq('date', today);
  }

  // =====================================================
  // PENDING
  // =====================================================

  Future<void> insertPending(Map<String, dynamic> pending) async {
    final sid = pending['student_id'] as String?;
    final studentName = pending['student'] as String?;
    if (sid == null && studentName == null) throw Exception('Falta student_id o student');

    String sidResolved = sid ?? '';
    if (sidResolved.isEmpty && studentName != null) {
      final s = await _client.from('students').select('id').eq('name', studentName).limit(1);
      if (s.isEmpty) throw Exception('Alumno no encontrado: $studentName');
      sidResolved = s.first['id'].toString();
    }

    final newAmount = (pending['amount'] as num).toDouble();

    try {
      await _client.from('pending').insert({
        'student_id': sidResolved,
        'amount': newAmount,
        'paid': 0.0,
        'paid_at': null,
        'created_at': pending['created_at'] ?? DateTime.now().toIso8601String(),
      });
    } on Exception catch (e) {
      if (e.toString().contains('23505')) {
        final cur = await _client.from('pending').select('amount,paid').eq('student_id', sidResolved).limit(1).maybeSingle();
        final curAmount = (cur?['amount'] as num?)?.toDouble() ?? 0;
        final curPaid = (cur?['paid'] as num?)?.toDouble() ?? 0;
        if (curPaid >= curAmount) {
          // Previous debt was settled — start fresh
          await _client.from('pending').update({
            'amount': newAmount,
            'paid': 0,
            'paid_at': null,
          }).eq('student_id', sidResolved);
        } else {
          // Previous debt still open — add to existing, keep paid
          await _client.from('pending').update({
            'amount': curAmount + newAmount,
            'paid_at': null,
          }).eq('student_id', sidResolved);
        }
      } else {
        rethrow;
      }
    }
  }

  Future<void> abonarPending(dynamic pendingId, double amount) async {
    final doc = await _client.from('pending').select('paid').eq('id', pendingId.toString()).limit(1).single();
    final curPaid = (doc['paid'] as num?)?.toDouble() ?? 0;
    await _client.from('pending').update({'paid': curPaid + amount}).eq('id', pendingId.toString());
  }

  Future<List<Map<String, dynamic>>> getPendings() async {
    return await _client.from('pending').select('*, students!inner(name)').order('student');
  }

  Stream<List<Map<String, dynamic>>> streamPendings() {
    _ensureCache();
    return _client.from('pending').stream(primaryKey: ['id']).order('created_at', ascending: true).map((data) {
      return data.where((d) {
        final amount = (d['amount'] as num?)?.toDouble() ?? 0;
        final paid = (d['paid'] as num?)?.toDouble() ?? 0;
        return amount > paid;
      }).map((d) {
        d['student'] = _studentNames[d['student_id']?.toString()] ?? 'Desconocido';
        return d;
      }).toList();
    });
  }

  Future<List<Map<String, dynamic>>> getAllPendingSales() async {
    final data = await _client.from('sales').select('*, students!inner(name), products!inner(name)').eq('payment_method', 'Pendiente');
    for (final row in data) {
      _flattenStudent(row);
      if (row['products'] is Map) {
        row['product'] = row['products']['name'];
        row.remove('products');
      }
    }
    data.sort((a, b) {
      final sa = (a['student'] as String? ?? '').toLowerCase();
      final sb = (b['student'] as String? ?? '').toLowerCase();
      final cmp = sa.compareTo(sb);
      if (cmp != 0) return cmp;
      final da = (a['date'] as String? ?? '');
      final db2 = (b['date'] as String? ?? '');
      return da.compareTo(db2);
    });
    return data;
  }

  Future<int> deletePending(dynamic id) async {
    await _client.from('pending').delete().eq('id', id.toString());
    return 1;
  }

  // =====================================================
  // AGGREGATES
  // =====================================================

  Future<double> getTotalSales() async {
    final yearStart = '${DateTime.now().year}-01-01';
    final data = await _client.from('sales').select('total').gte('date', yearStart);
    double sum = 0;
    for (final doc in data) {
      sum += (doc['total'] as num?)?.toDouble() ?? 0;
    }
    return sum;
  }

  Future<int> getTotalSalesCount() async {
    final yearStart = '${DateTime.now().year}-01-01';
    final data = await _client.from('sales').select('id').gte('date', yearStart);
    return data.length;
  }

  Future<List<Map<String, dynamic>>> getAllPending() async {
    return await _client.from('pending').select('*, students!inner(name)');
  }

  Future<double> getTotalPending() async {
    final data = await _client.from('pending').select('amount,paid').isFilter('paid_at', null);
    double sum = 0;
    for (final doc in data) {
      final amount = (doc['amount'] as num?)?.toDouble() ?? 0;
      final paid = (doc['paid'] as num?)?.toDouble() ?? 0;
      sum += amount - paid;
    }
    return sum;
  }

  Future<int> getProductsCount() async {
    final data = await _client.from('products').select('id');
    return data.length;
  }

  // =====================================================
  // AUTH
  // =====================================================

  Future<Map<String, dynamic>?> loginAdmin(String email, String password) async {
    try {
      final response = await _client.auth.signInWithPassword(email: email, password: password);
      final user = response.user;
      if (user == null) return null;
      final profileData = await _client.from('admin_profiles').select().eq('id', user.id).limit(1);
      if (profileData.isNotEmpty) {
        return {
          'username': profileData.first['username'],
          'role': 'admin',
        };
      }
      return {'username': user.email?.split('@').first ?? 'admin', 'role': 'admin'};
    } on AuthException {
      return null;
    }
  }

  Future<void> logoutAdmin() async {
    await _client.auth.signOut();
  }

  Future<bool> changePassword(String email, String oldPassword, String newPassword) async {
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null || currentUser.email != email) return false;
      final response = await _client.auth.signInWithPassword(email: email, password: oldPassword);
      if (response.user == null) return false;
      await _client.auth.updateUser(UserAttributes(password: newPassword));
      return true;
    } on AuthException {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getAdminUsers() async {
    final data = await _client.from('admin_profiles').select();
    return data;
  }

  Future<void> createAdminUser(String username, String password) async {
    if (password.length < 8) throw Exception('La contraseña debe tener al menos 8 caracteres');
    await _client.rpc('create_admin_user', params: {
      'p_username': username.trim(),
      'p_password': password,
    });
  }

  Future<void> deleteAdminUser(dynamic id) async {
    await _client.rpc('delete_admin_user', params: {
      'p_user_id': id.toString(),
    });
  }
}
