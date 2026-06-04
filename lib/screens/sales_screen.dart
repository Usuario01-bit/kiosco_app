import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../services/product_icons.dart';
import '../services/responsive.dart';

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

  String paymentMethod = 'Efectivo';

  double total = 0;

  final studentSearchController = TextEditingController();

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

    loadData();
  }

  @override
  void dispose() {
    studentSearchController.dispose();
    super.dispose();
  }

  // =====================================================
  // LOAD DATA
  // =====================================================

  Future<void> loadData() async {

    final studentsData =
    await FirestoreService.instance
        .getStudents();

    final productsData =
    await FirestoreService.instance
        .getProducts();

    setState(() {

      students = studentsData;

      products = productsData;
    });
  }

  // =====================================================
  // ADD TO CART
  // =====================================================

  void addToCart(
      Map<String, dynamic> product,
      ) {

    final existingIndex =
    cart.indexWhere(

          (item) =>
      item['id'] ==
          product['id'],
    );

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

    if (selectedStudent == null ||
        cart.isEmpty) {

      ScaffoldMessenger.of(context)
          .showSnackBar(

        const SnackBar(
          content: Text(
            'Selecciona estudiante y productos',
          ),
        ),
      );

      return;
    }

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

    for (var item in cart) {

      // =========================================
      // SAVE SALE
      // =========================================

      await FirestoreService.instance
          .insertSale({

        'student': selectedStudent,

        'product': item['name'],

        'quantity': item['quantity'],

        'total':
        (item['price'] as num)
            .toDouble() *
            item['quantity'],

        'paymentMethod':
        paymentMethod,

        'date':
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',

        'time':
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',

        'recreo': recreo,
      });

      // =========================================
      // UPDATE STOCK
      // =========================================

      await FirestoreService.instance
          .updateProductStock(

        item['id'],

        item['stock'] -
            item['quantity'],
      );
    }

    // =========================================
    // SAVE PENDING
    // =========================================

    if (paymentMethod
        .toLowerCase()
        .trim() == 'pendiente') {

      await FirestoreService.instance
          .insertPending({

        'student': selectedStudent,

        'amount': total,

        'date':
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',

        'time':
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',

        'recreo': recreo,
      });
    }

    // =========================================
    // RELOAD
    // =========================================

    await loadData();

    // =========================================
    // CLEAR
    // =========================================

    setState(() {

      cart.clear();

      total = 0;
    });

    ScaffoldMessenger.of(context)
        .showSnackBar(

      const SnackBar(

        content:
        Text('Venta completada'),
      ),
    );
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
                    labelText: 'Estudiante',
                    hintText: 'Escribí el nombre...',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: selectedStudent != null
                        ? IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              setState(() {
                                selectedStudent = null;
                                studentSearchController.clear();
                              });
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) {
                    setState(() {
                      if (selectedStudent != null) selectedStudent = null;
                    });
                  },
                ),
                if (selectedStudent != null)
                  Padding(
                    padding: EdgeInsets.only(top: R.sp(context, 6)),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, size: R.fs(context, 18), color: Colors.green),
                        SizedBox(width: R.sp(context, 6)),
                        Text(
                          selectedStudent!,
                          style: TextStyle(
                            fontSize: R.fs(context, 18),
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        if (students.any((s) => s['name'] == selectedStudent && s['grado'] != null))
                          Text(
                            ' (${students.firstWhere((s) => s['name'] == selectedStudent)['grado']})',
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
                          subtitle: s['grado'] != null
                              ? Text(
                                  s['grado'],
                                  style: TextStyle(
                                    fontSize: R.fs(context, 14),
                                    color: Colors.grey,
                                  ),
                                )
                              : null,
                          onTap: () {
                            setState(() {
                              selectedStudent = s['name'];
                              studentSearchController.text = s['name'];
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
              Expanded(
                child: RefreshIndicator(
                  onRefresh: loadData,
                  child: GridView.builder(
                    padding: EdgeInsets.all(R.sp(context, isWide ? 20 : 16)),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isWide ? 3 : 2,
                      crossAxisSpacing: isWide ? 16 : 12,
                      mainAxisSpacing: isWide ? 16 : 12,
                      childAspectRatio: isWide ? 0.85 : 0.72,
                    ),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];
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
                                    productIcons[product['icon'] as String?] ?? Icons.fastfood_rounded,
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
        height: 80,
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
                        const SnackBar(content: Text('Seleccioná estudiante y productos')),
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
                            return Padding(
                              padding: EdgeInsets.fromLTRB(
                                R.sp(context, 24),
                                R.sp(context, 24),
                                R.sp(context, 24),
                                MediaQuery.of(ctx).viewInsets.bottom + R.sp(context, 24),
                              ),
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
                                                child: const Icon(Icons.remove, size: 16, color: Colors.red),
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
                                                child: const Icon(Icons.add, size: 16, color: Colors.green),
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