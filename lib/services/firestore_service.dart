import 'package:cloud_firestore/cloud_firestore.dart';

import 'database_helper.dart';

class FirestoreService {

  static final FirestoreService instance = FirestoreService._();

  FirestoreService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  // Auth — se mantiene en SQLite local
  Future<Map<String, dynamic>?> login(
    String username,
    String password,
  ) =>
      DatabaseHelper.instance.login(username, password);

  Future<bool> changePassword(
    String username,
    String oldPassword,
    String newPassword,
  ) =>
      DatabaseHelper.instance.changePassword(
        username,
        oldPassword,
        newPassword,
      );

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
    await _db.collection('students').add({'name': row['name']});
    return 0;
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

  // =====================================================
  // SALES
  // =====================================================

  Future<int> insertSale(Map<String, dynamic> sale) async {
    await _db.collection('sales').add({
      'student': sale['student'],
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

  Future<List<Map<String, dynamic>>> getSales() async {
    final snap = await _db
        .collection('sales')
        .orderBy('date', descending: true)
        .orderBy('time', descending: true)
        .get();
    return snap.docs.map(_docToMap).toList();
  }

  Future<int> paySale(dynamic id) async {
    await _db.collection('sales').doc(id.toString()).update({
      'paymentMethod': 'Efectivo',
      'paidAt': DateTime.now().toIso8601String(),
    });
    return 1;
  }

  Future<void> payPendingSales(String student) async {
    final batch = _db.batch();
    final salesSnap = await _db
        .collection('sales')
        .where('student', isEqualTo: student)
        .where('paymentMethod', isEqualTo: 'Pendiente')
        .get();
    for (final doc in salesSnap.docs) {
      batch.update(doc.reference, {
        'paymentMethod': 'Efectivo',
        'paidAt': DateTime.now().toIso8601String(),
      });
    }
    final pendingSnap = await _db
        .collection('pending')
        .where('student', isEqualTo: student)
        .get();
    for (final doc in pendingSnap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<List<Map<String, dynamic>>> getSalesByStudent(
    String student,
  ) async {
    final snap = await _db
        .collection('sales')
        .where('student', isEqualTo: student)
        .orderBy('date', descending: true)
        .orderBy('time', descending: true)
        .get();
    return snap.docs.map(_docToMap).toList();
  }

  Future<List<Map<String, dynamic>>> getRecentSales(int limit) async {
    final snap = await _db
        .collection('sales')
        .orderBy('date', descending: true)
        .orderBy('time', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(_docToMap).toList();
  }

  Future<double> getTodaySales() async {
    final today =
        DateTime.now().toIso8601String().substring(0, 10);
    final snap = await _db
        .collection('sales')
        .where('date', isEqualTo: today)
        .where('paymentMethod', isNotEqualTo: 'Pendiente')
        .get();
    double sum = 0;
    for (final doc in snap.docs) {
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
        .where('paymentMethod', isNotEqualTo: 'Pendiente')
        .get();
    final Map<String, double> grouped = {};
    for (final doc in snap.docs) {
      final d = doc.data();
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
        .where('paymentMethod', isEqualTo: 'Pendiente')
        .get();
    double sum = 0;
    for (final doc in snap.docs) {
      sum += (doc.data()['total'] as num?)?.toDouble() ?? 0;
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
    });
    return 0;
  }

  Future<List<Map<String, dynamic>>> getPendings() async {
    final snap = await _db
        .collection('pending')
        .orderBy('student')
        .get();
    return snap.docs.map(_docToMap).toList();
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

  Future<double> getTotalPending() async {
    final snap = await _db.collection('pending').get();
    double sum = 0;
    for (final doc in snap.docs) {
      sum += (doc.data()['amount'] as num?)?.toDouble() ?? 0;
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
          'date': s['date'],
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
          'date': p['date'],
          'time': p['time'],
          'recreo': p['recreo'] ?? '',
          'paidAt': p['paid_at'],
        });
      }
    }
  }
}
