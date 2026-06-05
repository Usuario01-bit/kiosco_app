import 'package:cloud_firestore/cloud_firestore.dart';

import 'database_helper.dart';

class FirestoreService {

  static final FirestoreService instance = FirestoreService._();

  FirestoreService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  // =====================================================
  // HELPERS
  // =====================================================

  Map<String, dynamic> _docToMap(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    data['id'] = doc.id;
    return data;
  }

  // =====================================================
  // STUDENTS
  // =====================================================

  Future<int> insertStudent(Map<String, dynamic> row) async {
    await _db.collection('students').add({
      'name': row['name'],
      if (row.containsKey('grado') && row['grado'] != null && (row['grado'] as String).trim().isNotEmpty)
        'grado': row['grado'].toString().trim(),
    });
    return 0;
  }

  Future<int> insertManyStudents(List<Map<String, dynamic>> students) async {
    final batch = _db.batch();
    for (final row in students) {
      final doc = _db.collection('students').doc();
      batch.set(doc, {
        'name': row['name'],
        if (row.containsKey('grado') && row['grado'] != null && (row['grado'] as String).trim().isNotEmpty)
          'grado': row['grado'].toString().trim(),
      });
    }
    await batch.commit();
    return students.length;
  }

  Future<List<Map<String, dynamic>>> getStudents() async {
    final snap = await _db
        .collection('students')
        .orderBy('name')
        .get();
    return snap.docs.map(_docToMap).toList();
  }

  Future<int> deleteStudent(dynamic id) async {
    await _db.collection('students').doc(id.toString()).delete();
    return 1;
  }

  Future<int> deleteAllStudents() async {
    final snap = await _db.collection('students').get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    return snap.docs.length;
  }

  Stream<List<Map<String, dynamic>>> streamStudents() {
    return _db
        .collection('students')
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs.map(_docToMap).toList());
  }

  // =====================================================
  // PRODUCTS
  // =====================================================

  Future<int> insertProduct(Map<String, dynamic> data) async {
    await _db.collection('products').add({
      'name': data['name'],
      'price': (data['price'] as num).toDouble(),
      'stock': (data['stock'] as num).toInt(),
      'icon': data['icon'] ?? 'inventory_2',
    });
    return 0;
  }

  Future<List<Map<String, dynamic>>> getProducts() async {
    final snap = await _db
        .collection('products')
        .orderBy('name')
        .get();
    return snap.docs.map(_docToMap).toList();
  }

  Future<int> deleteProduct(dynamic id) async {
    await _db.collection('products').doc(id.toString()).delete();
    return 1;
  }

  Future<int> updateProduct(
    dynamic id,
    Map<String, dynamic> data,
  ) async {
    await _db.collection('products').doc(id.toString()).update({
      'name': data['name'],
      'price': (data['price'] as num).toDouble(),
      'stock': (data['stock'] as num).toInt(),
      if (data['icon'] != null) 'icon': data['icon'],
    });
    return 1;
  }

  Future<int> updateProductStock(
    dynamic id,
    int newStock,
  ) async {
    await _db
        .collection('products')
        .doc(id.toString())
        .update({'stock': newStock});
    return 1;
  }

  Future<Map<String, dynamic>?> getProductById(dynamic id) async {
    final doc = await _db
        .collection('products')
        .doc(id.toString())
        .get();
    if (!doc.exists) return null;
    return _docToMap(doc);
  }

  Stream<List<Map<String, dynamic>>> streamProducts() {
    return _db
        .collection('products')
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs.map(_docToMap).toList());
  }

  // =====================================================
  // SALES
  // =====================================================

  Future<int> insertSale(Map<String, dynamic> sale) async {
    await _db.collection('sales').add({
      'student': sale['student'],
      'studentId': sale['studentId'] ?? '',
      'product': sale['product'],
      'productId': sale['productId'] ?? '',
      'quantity': (sale['quantity'] as num).toInt(),
      'total': (sale['total'] as num).toDouble(),
      'paymentMethod': sale['paymentMethod'],
      'date': sale['date'],
      'time': sale['time'],
      'recreo': sale['recreo'] ?? '',
      'paidAt': null,
    });
    return 0;
  }

  List<Map<String, dynamic>> _sortSalesByDateTime(List<Map<String, dynamic>> sales) {
    sales.sort((a, b) {
      final dateCmp = (b['date'] as String? ?? '').compareTo(a['date'] as String? ?? '');
      if (dateCmp != 0) return dateCmp;
      return (b['time'] as String? ?? '').compareTo(a['time'] as String? ?? '');
    });
    return sales;
  }

  Future<List<Map<String, dynamic>>> getSales() async {
    final snap = await _db
        .collection('sales')
        .orderBy('date', descending: true)
        .get();
    return _sortSalesByDateTime(snap.docs.map(_docToMap).toList());
  }

  Future<int> paySale(dynamic id) async {
    await _db.collection('sales').doc(id.toString()).update({
      'paymentMethod': 'Efectivo',
      'paidAt': DateTime.now().toIso8601String(),
    });
    return 1;
  }

  Stream<List<Map<String, dynamic>>> streamSales() {
    return _db
        .collection('sales')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => _sortSalesByDateTime(snap.docs.map(_docToMap).toList()));
  }

  Future<void> payPendingSales(String student, dynamic pendingId) async {
    final batch = _db.batch();
    double totalPaid = 0;

    final salesSnap = await _db
        .collection('sales')
        .where('student', isEqualTo: student)
        .get();
    for (final doc in salesSnap.docs) {
      final pm = doc.data()['paymentMethod'] as String? ?? '';
      if (!pm.toLowerCase().contains('pendiente')) continue;
      totalPaid += (doc.data()['total'] as num?)?.toDouble() ?? 0;
      batch.update(doc.reference, {
        'paymentMethod': 'Efectivo',
        'paidAt': DateTime.now().toIso8601String(),
      });
    }

    if (pendingId != null) {
      batch.update(_db.collection('pending').doc(pendingId.toString()), {
        'paid': totalPaid,
        'paidAt': DateTime.now().toIso8601String(),
      });
    } else {
      final pendingSnap = await _db
          .collection('pending')
          .where('student', isEqualTo: student)
          .get();
      for (final doc in pendingSnap.docs) {
        batch.update(doc.reference, {
          'paid': totalPaid,
          'paidAt': DateTime.now().toIso8601String(),
        });
      }
    }

    await batch.commit();
  }

  Future<List<Map<String, dynamic>>> getSalesByStudent(
    String student,
  ) async {
    final snap = await _db
        .collection('sales')
        .where('student', isEqualTo: student)
        .get();
    return _sortSalesByDateTime(snap.docs.map(_docToMap).toList());
  }

  Future<List<Map<String, dynamic>>> getSalesByStudentId(
    String studentId,
  ) async {
    final snap = await _db
        .collection('sales')
        .where('studentId', isEqualTo: studentId)
        .get();
    return _sortSalesByDateTime(snap.docs.map(_docToMap).toList());
  }

  Future<List<Map<String, dynamic>>> getRecentSales(int limit) async {
    final snap = await _db
        .collection('sales')
        .orderBy('date', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(_docToMap).toList();
  }

  Future<double> getTodaySales() async {
    final now = DateTime.now();
    final today =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final snap = await _db
        .collection('sales')
        .where('date', isEqualTo: today)
        .get();
    double sum = 0;
    for (final doc in snap.docs) {
      final m = doc.data()['paymentMethod'] as String? ?? '';
      if (m.toLowerCase().contains('pendiente')) continue;
      sum += (doc.data()['total'] as num?)?.toDouble() ?? 0;
    }
    return sum;
  }

  Future<String?> getTopProduct() async {
    final snap = await _db.collection('sales').get();
    final Map<String, int> counts = {};
    for (final doc in snap.docs) {
      final p = doc.data()['product'] as String? ?? '';
      final q = (doc.data()['quantity'] as num?)?.toInt() ?? 0;
      counts[p] = (counts[p] ?? 0) + q;
    }
    if (counts.isEmpty) return null;
    return counts.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  Future<List<Map<String, dynamic>>> getWeeklySales() async {
    final weekAgo = DateTime.now()
        .subtract(const Duration(days: 6))
        .toIso8601String()
        .substring(0, 10);
    final snap = await _db
        .collection('sales')
        .where('date', isGreaterThanOrEqualTo: weekAgo)
        .get();
    final Map<String, double> grouped = {};
    for (final doc in snap.docs) {
      final d = doc.data();
      final pm = d['paymentMethod'] as String? ?? '';
      if (pm.toLowerCase().contains('pendiente')) continue;
      final date = d['date'] as String? ?? '';
      final total = (d['total'] as num?)?.toDouble() ?? 0;
      grouped[date] = (grouped[date] ?? 0) + total;
    }
    final sorted = grouped.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return sorted
        .map((e) => {'date': e.key, 'total': e.value})
        .toList();
  }

  Future<List<Map<String, dynamic>>> getTopProducts(int limit) async {
    final snap = await _db.collection('sales').get();
    final Map<String, double> totals = {};
    for (final doc in snap.docs) {
      final d = doc.data();
      final product = d['product'] as String? ?? '';
      final total = (d['total'] as num?)?.toDouble() ?? 0;
      totals[product] = (totals[product] ?? 0) + total;
    }
    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted
        .take(limit)
        .map((e) => {'product': e.key, 'total': e.value})
        .toList();
  }

  Future<double> getStudentDebt(String student) async {
    final snap = await _db
        .collection('sales')
        .where('student', isEqualTo: student)
        .get();
    double sum = 0;
    for (final doc in snap.docs) {
      final pm = doc.data()['paymentMethod'] as String? ?? '';
      if (pm.toLowerCase().contains('pendiente')) {
        sum += (doc.data()['total'] as num?)?.toDouble() ?? 0;
      }
    }
    return sum;
  }

  // =====================================================
  // PENDING
  // =====================================================

  Future<int> insertPending(Map<String, dynamic> pending) async {
    final student = pending['student'] as String;
    final existing = await _db
        .collection('pending')
        .where('student', isEqualTo: student)
        .get();
    if (existing.docs.isNotEmpty) {
      final doc = existing.docs.first;
      final cur =
          (doc.data()['amount'] as num?)?.toDouble() ?? 0;
      await doc.reference.update({
        'amount': cur + (pending['amount'] as num).toDouble(),
      });
      return 1;
    }
    await _db.collection('pending').add({
      'student': student,
      'amount': (pending['amount'] as num).toDouble(),
      'date': pending['date'],
      'time': pending['time'],
      'recreo': pending['recreo'] ?? '',
      'paidAt': null,
      'paid': 0.0,
    });
    return 0;
  }

  Future<void> abonarPending(dynamic pendingId, double amount) async {
    await _db.collection('pending').doc(pendingId.toString()).update({
      'paid': FieldValue.increment(amount),
    });
  }

  Future<List<Map<String, dynamic>>> getPendings() async {
    final snap = await _db
        .collection('pending')
        .orderBy('student')
        .get();
    return snap.docs.map(_docToMap).toList();
  }

  Stream<List<Map<String, dynamic>>> streamPendings() {
    return _db
        .collection('pending')
        .orderBy('student')
        .snapshots()
        .map((snap) => snap.docs
            .map(_docToMap)
            .where((d) => d['paidAt'] == null)
            .toList());
  }

  Future<List<Map<String, dynamic>>> getAllPendingSales() async {
    final snap = await _db
        .collection('sales')
        .where('paymentMethod', isEqualTo: 'Pendiente')
        .get();
    final rows = snap.docs.map(_docToMap).toList();
    rows.sort((a, b) {
      final sa = (a['student'] as String? ?? '').toLowerCase();
      final sb = (b['student'] as String? ?? '').toLowerCase();
      final cmp = sa.compareTo(sb);
      if (cmp != 0) return cmp;
      final da = (a['date'] as String? ?? '');
      final db2 = (b['date'] as String? ?? '');
      return da.compareTo(db2);
    });
    return rows;
  }

  Future<int> deletePending(dynamic id) async {
    await _db.collection('pending').doc(id.toString()).delete();
    return 1;
  }

  // =====================================================
  // AGGREGATES
  // =====================================================

  Future<double> getTotalSales() async {
    final snap = await _db.collection('sales').get();
    double sum = 0;
    for (final doc in snap.docs) {
      sum += (doc.data()['total'] as num?)?.toDouble() ?? 0;
    }
    return sum;
  }

  Future<int> getTotalSalesCount() async {
    final snap = await _db.collection('sales').count().get();
    return snap.count ?? 0;
  }

  Future<List<Map<String, dynamic>>> getAllPending() async {
    final snap = await _db.collection('pending').get();
    return snap.docs.map((doc) {
      final data = _docToMap(doc);
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  Future<double> getTotalPending() async {
    final snap = await _db.collection('pending').get();
    double sum = 0;
    for (final doc in snap.docs) {
      final data = doc.data();
      final amount = (data['amount'] as num?)?.toDouble() ?? 0;
      final paid = (data['paid'] as num?)?.toDouble() ?? 0;
      sum += amount - paid;
    }
    return sum;
  }

  Future<int> getProductsCount() async {
    final snap = await _db.collection('products').count().get();
    return snap.count ?? 0;
  }

  // =====================================================
  // MIGRATION
  // =====================================================

  Future<void> seedFromLocal() async {
    final local = DatabaseHelper.instance;

    var existing = await _db.collection('students').count().get();
    if (existing.count == 0) {
      final students = await local.getStudents();
      for (final s in students) {
        await _db.collection('students').add({'name': s['name']});
      }
    }

    existing = await _db.collection('products').count().get();
    if (existing.count == 0) {
      final products = await local.getProducts();
      for (final p in products) {
        await _db.collection('products').add({
          'name': p['name'],
          'price': (p['price'] as num).toDouble(),
          'stock': (p['stock'] as num).toInt(),
          'icon': p['icon'] ?? 'inventory_2',
        });
      }
    }

    String normalizeDate(String? date) {
      if (date == null) return DateTime.now().toIso8601String().substring(0, 10);
      if (date.contains('-')) return date;
      final parts = date.split('/');
      if (parts.length != 3) return date;
      return '${parts[2].padLeft(4, '0')}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}';
    }

    existing = await _db.collection('sales').count().get();
    if (existing.count == 0) {
      final sales = await local.getSales();
      for (final s in sales) {
        await _db.collection('sales').add({
          'student': s['student'],
          'product': s['product'],
          'productId': '',
          'quantity': (s['quantity'] as num).toInt(),
          'total': (s['total'] as num).toDouble(),
          'paymentMethod': s['paymentMethod'],
          'date': normalizeDate(s['date'] as String?),
          'time': s['time'],
          'recreo': s['recreo'] ?? '',
          'paidAt': s['paid_at'],
        });
      }
    }

    existing = await _db.collection('pending').count().get();
    if (existing.count == 0) {
      final pendings = await local.getPendings();
      for (final p in pendings) {
        await _db.collection('pending').add({
          'student': p['student'],
          'amount': (p['amount'] as num).toDouble(),
          'date': normalizeDate(p['date'] as String?),
          'time': p['time'],
          'recreo': p['recreo'] ?? '',
          'paidAt': p['paid_at'],
        });
      }
    }

    // Migrate existing dates from DD/MM/YYYY to yyyy-MM-dd
    await _migrateOldDates('sales');
    await _migrateOldDates('pending');
  }

  Future<void> _migrateOldDates(String collection) async {
    final sample = await _db.collection(collection).limit(1).get();
    if (sample.docs.isEmpty) return;
    final date = sample.docs.first.data()['date'] as String? ?? '';
    if (!date.contains('/')) return;

    final all = await _db.collection(collection).get();
    final batch = _db.batch();
    int count = 0;
    for (final doc in all.docs) {
      final raw = doc.data()['date'] as String? ?? '';
      if (!raw.contains('/')) continue;
      final parts = raw.split('/');
      if (parts.length != 3) continue;
      final newDate = '${parts[2].padLeft(4, '0')}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}';
      batch.update(doc.reference, {'date': newDate});
      count++;
    }
    if (count > 0) await batch.commit();
  }
}
