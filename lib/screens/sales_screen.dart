import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/date_utils.dart';
import '../services/product_icons.dart' show resolveProductIcon;
import '../services/local_cache_service.dart';
import '../services/responsive.dart';
import '../services/store_config.dart';

class SalesScreen extends StatefulWidget {

  const SalesScreen({
    super.key,
  });

  @override
  State<SalesScreen> createState() =>
      _SalesScreenState();
}

class _SalesScreenState
    extends State<SalesScreen> {

  // =====================================================
  // VARIABLES
  // =====================================================

  List<Map<String, dynamic>> students = [];

  List<Map<String, dynamic>> products = [];

  List<Map<String, dynamic>> cart = [];

  String? selectedStudent;
  String? selectedStudentId;

  String paymentMethod = 'Efectivo';

  double total = 0;

  String? selectedCategory;

  final studentSearchController = TextEditingController();

  IconData _productIcon(Map<String, dynamic> product) =>
      resolveProductIcon(product);

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.blue.shade100 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? Colors.blue.shade800 : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  StreamSubscription? _studentsSub;
  StreamSubscription? _productsSub;

  List<Map<String, dynamic>> get _filteredStudents {
    final query = studentSearchController.text.toLowerCase().trim();
    if (query.isEmpty) return [];
    return students.where((s) {
      final name = (s['name'] as String? ?? '').toLowerCase();
      return name.contains(query);
    }).toList();
  }

  // =====================================================
  // INIT
  // =====================================================

  @override
  void initState() {
    super.initState();
    _loadCachedThenStream();
  }

  Future<void> _loadCachedThenStream() async {
    final cachedProducts = await LocalCacheService.instance.getCachedProducts();
    final cachedStudents = await LocalCacheService.instance.getCachedStudents();
    if (mounted) setState(() {
      if (cachedProducts.isNotEmpty) products = cachedProducts;
      if (cachedStudents.isNotEmpty) students = cachedStudents;
    });
    _studentsSub = SupabaseService.instance
        .streamStudents()
        .listen((data) {
      if (mounted) setState(() => students = data);
    }, onError: (_) {});
    _productsSub = SupabaseService.instance
        .streamProducts()
        .listen((data) {
      if (mounted) setState(() => products = data);
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _studentsSub?.cancel();
    _productsSub?.cancel();
    studentSearchController.dispose();
    super.dispose();
  }

  // =====================================================
  // ADD TO CART
  // =====================================================

  void addToCart(
      Map<String, dynamic> product,
      ) {

    final stock = (product['stock'] as num?)?.toInt() ?? 0;

    if (stock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Producto agotado'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final existingIndex =
    cart.indexWhere(

          (item) =>
      item['id'] ==
          product['id'],
    );

    if (existingIndex != -1) {
      final currentQty = cart[existingIndex]['quantity'] as int;
      if (currentQty >= stock) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Stock máximo disponible: $stock'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    setState(() {

      if (existingIndex != -1) {

        cart[existingIndex]
        ['quantity']++;

      } else {

        cart.add({

          ...product,

          'quantity': 1,
        });
      }

      calculateTotal();
    });
  }

  // =====================================================
  // TOTAL
  // =====================================================

  void calculateTotal() {

    total = 0;

    for (var item in cart) {

      total +=
          (item['price'] as num)
              .toDouble() *
              item['quantity'];
    }
  }

  // =====================================================
  // COMPLETE SALE
  // =====================================================

  Future<void> completeSale() async {
    try {
      if (selectedStudent == null ||
          cart.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(
              SnackBar(
                content: Text(
                  'Selecciona ${StoreConfig.instance.entityLC()} y productos',
              ),
            ),
          );
        }
        return;
      }

      final currentStudent = selectedStudent;
      final currentStudentId = selectedStudentId;
      final currentPaymentMethod = paymentMethod;
      final currentTotal = total;
      final cartSnapshot = cart.map((e) => Map<String, dynamic>.from(e)).toList();

      final now = DateTime.now();

      String recreo = 'Fuera de recreo';

      // RECREO 1
      if (now.hour == 10) {
        recreo = 'Recreo 1';
      }

      // RECREO 2
      if (now.hour == 12 &&
          now.minute >= 20) {
        recreo = 'Recreo 2';
      }

      // SALIDA
      if (now.hour == 14) {
        recreo = 'Salida';
      }

      final saleRows = cartSnapshot.map((item) {
        return {
          'student_id': currentStudentId ?? '',
          'product_id': item['id'],
          'quantity': item['quantity'],
          'total': (item['price'] as num).toDouble() * item['quantity'],
          'payment_method': currentPaymentMethod,
          'prepared_at': DateTime.now().toIso8601String(),
          'date': toISODate(now),
          'time': '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
          'recreo': recreo,
        };
      }).toList();

      await SupabaseService.instance.insertSalesBatch(saleRows);

      for (var item in cartSnapshot) {
        await SupabaseService.instance
            .updateProductStock(
          item['id'],
          (item['stock'] as int) -
              (item['quantity'] as int),
        );
      }

      if (currentPaymentMethod
          .toLowerCase()
          .trim() == 'pendiente') {
        await SupabaseService.instance
            .insertPending({
          'student_id': currentStudentId,
          'student': currentStudent,
          'amount': currentTotal,
          'created_at': now.toIso8601String(),
        });
      }

      if (mounted) {
        setState(() {
          cart.clear();
          total = 0;
        });

        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text('Venta completada'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            content: Text('Error al guardar venta: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // =====================================================
  // BUILD
  // =====================================================

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor:
      Theme.of(context).scaffoldBackgroundColor,

      appBar: AppBar(

        title:
        const Text('Ventas'),

        backgroundColor:
        Colors.blue,

        foregroundColor:
        Colors.white,
      ),

      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 600;

          final headerWidget = Padding(
            padding: EdgeInsets.fromLTRB(R.sp(context, 20), R.sp(context, 20), R.sp(context, 20), 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: studentSearchController,
                  decoration: InputDecoration(
                    labelText: StoreConfig.instance.entityName,
                    hintText: 'Escribí el nombre...',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    prefixIcon: const Icon(LucideIcons.search),
                    suffixIcon: selectedStudent != null
                        ? IconButton(
                            icon: const Icon(LucideIcons.x),
                            onPressed: () {
                              setState(() {
                                selectedStudent = null;
                                selectedStudentId = null;
                                studentSearchController.clear();
                              });
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) {
                    setState(() {
                      if (selectedStudent != null) {
                        selectedStudent = null;
                        selectedStudentId = null;
                      }
                    });
                  },
                ),
                if (selectedStudent != null)
                  Padding(
                    padding: EdgeInsets.only(top: R.sp(context, 6)),
                    child: Row(
                      children: [
                        Icon(LucideLucideIcons.checkCircle, size: R.fs(context, 18), color: Colors.green),
                        SizedBox(width: R.sp(context, 6)),
                        Text(
                          selectedStudent!,
                          style: TextStyle(
                            fontSize: R.fs(context, 18),
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        if (students.any((s) => s['name'] == selectedStudent && (s['grade'] ?? s['grado']) != null))
                          Text(
                            ' (${students.firstWhere((s) => s['name'] == selectedStudent)['grade'] ?? students.firstWhere((s) => s['name'] == selectedStudent)['grado']})',
                            style: TextStyle(
                              fontSize: R.fs(context, 16),
                              color: Colors.grey,
                            ),
                          ),
                      ],
                    ),
                  ),
                if (selectedStudent == null && _filteredStudents.isNotEmpty)
                  Container(
                    constraints: BoxConstraints(maxHeight: R.sp(context, 220)),
                    margin: EdgeInsets.only(top: R.sp(context, 6)),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ListView.builder(
                      padding: EdgeInsets.symmetric(vertical: R.sp(context, 6)),
                      itemCount: _filteredStudents.length,
                      itemBuilder: (context, index) {
                        final s = _filteredStudents[index];
                        return ListTile(
                          dense: true,
                          title: Text(
                            s['name'],
                            style: TextStyle(
                              fontSize: R.fs(context, 18),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: (s['grade'] ?? s['grado']) != null
                              ? Text(
                                  (s['grade'] ?? s['grado']),
                                  style: TextStyle(
                                    fontSize: R.fs(context, 14),
                                    color: Colors.grey,
                                  ),
                                )
                              : null,
                          onTap: () {
                                setState(() {
                                  selectedStudent = s['name'];
                                  selectedStudentId = s['id'];
                                  studentSearchController.clear();
                                });
                              },
                        );
                      },
                    ),
                  ),
                SizedBox(height: R.sp(context, 12)),
                DropdownButtonFormField<String>(
                  initialValue: paymentMethod,
                  decoration: const InputDecoration(
                    labelText: 'Método de pago',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Efectivo', child: Text('Efectivo')),
                    DropdownMenuItem(value: 'Yappy', child: Text('Yappy')),
                    DropdownMenuItem(value: 'Pendiente', child: Text('Pendiente')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      paymentMethod = value!;
                    });
                  },
                ),
              ],
            ),
          );

          return Column(
            children: [
              if (!isWide) headerWidget,
              SizedBox(height: R.sp(context, 8)),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: R.sp(context, isWide ? 20 : 16)),
                  children: [

                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _filterChip('Todas', selectedCategory == null, () => setState(() => selectedCategory = null)),
                    ),

                    ...products
                        .map((p) => p['category'] as String? ?? 'General')
                        .toSet()
                        .map((cat) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _filterChip(cat, selectedCategory == cat, () => setState(() => selectedCategory = cat)),
                            )),
                  ],
                ),
              ),
              SizedBox(height: R.sp(context, 4)),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {},
                  child: GridView.builder(
                    padding: EdgeInsets.all(R.sp(context, isWide ? 20 : 16)),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isWide ? 3 : 2,
                      crossAxisSpacing: isWide ? 16 : 12,
                      mainAxisSpacing: isWide ? 16 : 12,
                      childAspectRatio: isWide ? 0.85 : 0.72,
                    ),
                    itemCount: selectedCategory == null
                        ? products.length
                        : products.where((p) => (p['category'] as String? ?? 'General') == selectedCategory).length,
                    itemBuilder: (context, index) {
                      final filtered = selectedCategory == null
                          ? products
                          : products.where((p) => (p['category'] as String? ?? 'General') == selectedCategory).toList();
                      final product = filtered[index];
                      return GestureDetector(
                        onTap: () => addToCart(product),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Theme.of(context).cardColor,
                                Theme.of(context).brightness == Brightness.dark
                                    ? Theme.of(context).cardColor
                                    : const Color(0xFFF8FBFF),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(R.sp(context, 28)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(R.sp(context, 12)),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: EdgeInsets.all(R.sp(context, 12)),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _productIcon(product),
                                    size: R.sp(context, 36),
                                    color: Colors.blue,
                                  ),
                                ),
                                Text(
                                  product['name'],
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: R.fs(context, isWide ? 18 : 16),
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                                Text(
                                  '\$${(product['price'] as num).toDouble().toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: R.fs(context, isWide ? 20 : 18),
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade600,
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: R.sp(context, 14),
                                    vertical: R.sp(context, 6),
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).dividerColor.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(R.sp(context, 14)),
                                  ),
                                  child: Text(
                                    product['stock'] <= 0
                                        ? 'AGOTADO'
                                        : 'Stock: ${product['stock']}',
                                    style: TextStyle(
                                      fontSize: R.fs(context, 13),
                                      color: product['stock'] <= 0 ? Colors.red : Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              if (isWide) Padding(
                padding: EdgeInsets.all(R.sp(context, 20)),
                child: headerWidget,
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: Container(
        height: 80 + MediaQuery.of(context).padding.bottom,
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: R.sp(context, 20)),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🛒 Carrito (${cart.length})',
                      style: TextStyle(
                        fontSize: R.fs(context, 16),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: R.sp(context, 4)),
                    Text(
                      'Total: \$${total.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: R.fs(context, 22),
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 130,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    if (selectedStudent == null || cart.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Seleccioná ${StoreConfig.instance.entityLC()} y productos')),
                      );
                      return;
                    }
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      builder: (ctx) {
                        return StatefulBuilder(
                          builder: (ctx, setSheetState) {
                            final bottomInset = MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom;
                            return Padding(
                              padding: EdgeInsets.fromLTRB(
                                R.sp(context, 24),
                                R.sp(context, 24),
                                R.sp(context, 24),
                                bottomInset + R.sp(context, 24),
                              ),
                              child: SingleChildScrollView(
                                child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Center(
                                    child: Container(
                                      width: 40,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade300,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: R.sp(context, 20)),
                                  Text(
                                    'Carrito',
                                    style: TextStyle(
                                      fontSize: R.fs(context, 24),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: R.sp(context, 16)),
                                  if (cart.isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.all(20),
                                      child: Center(child: Text('Sin productos')),
                                    )
                                  else
                                    ...cart.asMap().entries.map((entry) {
                                      final item = entry.value;
                                      final idx = entry.key;
                                      return Padding(
                                        padding: EdgeInsets.only(bottom: R.sp(context, 8)),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                item['name'],
                                                style: TextStyle(fontSize: R.fs(context, 16)),
                                              ),
                                            ),
                                            SizedBox(width: R.sp(context, 12)),
                                            GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  item['quantity']--;
                                                  if (item['quantity'] <= 0) {
                                                    cart.removeAt(idx);
                                                  }
                                                  calculateTotal();
                                                });
                                                setSheetState(() {});
                                              },
                                              child: Container(
                                                padding: EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                  color: Colors.red.shade100,
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: const Icon(LucideIcons.minus, size: 16, color: Colors.red),
                                              ),
                                            ),
                                            SizedBox(width: R.sp(context, 10)),
                                            Text(
                                              '${item['quantity']}',
                                              style: TextStyle(
                                                fontSize: R.fs(context, 16),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            SizedBox(width: R.sp(context, 10)),
                                            GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  item['quantity']++;
                                                  calculateTotal();
                                                });
                                                setSheetState(() {});
                                              },
                                              child: Container(
                                                padding: EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                  color: Colors.green.shade100,
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: const Icon(LucideIcons.plus, size: 16, color: Colors.green),
                                              ),
                                            ),
                                            SizedBox(width: R.sp(context, 16)),
                                            Text(
                                              '\$${((item['price'] as num).toDouble() * item['quantity']).toStringAsFixed(2)}',
                                              style: TextStyle(
                                                fontSize: R.fs(context, 16),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  const Divider(height: 32),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Total',
                                        style: TextStyle(
                                          fontSize: R.fs(context, 20),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '\$${total.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: R.fs(context, 24),
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: R.sp(context, 24)),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 54,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        Navigator.pop(ctx);
                                        completeSale();
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                      ),
                                      child: const Text(
                                        'Completar Venta',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                          },
                        );
                      },
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Pagar',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}