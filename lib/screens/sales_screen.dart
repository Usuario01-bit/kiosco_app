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

  String? _plusOneId;
  Timer? _plusOneTimer;
  bool _plusOneCheck = false;

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
    _plusOneTimer?.cancel();
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

    _plusOneTimer?.cancel();
    setState(() {
      _plusOneId = product['id'];
      _plusOneCheck = false;
    });
    _plusOneTimer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _plusOneCheck = true);
      _plusOneTimer = Timer(const Duration(milliseconds: 400), () {
        if (mounted) setState(() {
          _plusOneId = null;
          _plusOneCheck = false;
        });
      });
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
          final filtered = selectedCategory == null
              ? products
              : products.where((p) => (p['category'] as String? ?? 'General') == selectedCategory).toList();

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
                        Icon(LucideIcons.checkCircle, size: R.fs(context, 18), color: Colors.green),
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
                  child: ListView.builder(
                    padding: EdgeInsets.all(R.sp(context, isWide ? 20 : 16)),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final product = filtered[index];
                      final stock = (product['stock'] as num?)?.toInt() ?? 0;
                      final outOfStock = stock <= 0;
                      final lowStock = stock > 0 && stock <= 5;
                      final isDark = Theme.of(context).brightness == Brightness.dark;
                      final imageUrl = product['image_url'] as String?;
                      final hasImage = imageUrl != null && imageUrl.isNotEmpty;
                      return GestureDetector(
                        onTap: () => addToCart(product),
                        child: Stack(
                          children: [
                            Container(
                              margin: EdgeInsets.only(bottom: R.sp(context, 10)),
                              padding: EdgeInsets.all(R.sp(context, 12)),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: outOfStock
                                      ? (isDark
                                          ? const [Color(0xFF3A3A3A), Color(0xFF2E2E2E)]
                                          : const [Color(0xFFE9E9E9), Color(0xFFDDDDDD)])
                                      : [
                                          Theme.of(context).cardColor,
                                          isDark ? Theme.of(context).cardColor : const Color(0xFFF8FBFF),
                                        ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(R.sp(context, 20)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 12,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                                border: Border.all(
                                  color: outOfStock ? Colors.grey.shade400 : Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: R.sp(context, 64),
                                    height: R.sp(context, 64),
                                    decoration: BoxDecoration(
                                      color: outOfStock
                                          ? Colors.grey.withValues(alpha: 0.15)
                                          : Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(R.sp(context, 16)),
                                    ),
                                    child: hasImage
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(R.sp(context, 16)),
                                            child: Image.network(
                                              imageUrl,
                                              width: R.sp(context, 64),
                                              height: R.sp(context, 64),
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, _, _) => Icon(
                                                _productIcon(product),
                                                size: R.sp(context, 30),
                                                color: outOfStock ? Colors.grey : Colors.blue,
                                              ),
                                            ),
                                          )
                                        : Icon(
                                            _productIcon(product),
                                            size: R.sp(context, 30),
                                            color: outOfStock ? Colors.grey : Colors.blue,
                                          ),
                                  ),
                                  SizedBox(width: R.sp(context, 14)),
                                  Expanded(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          product['name'],
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: R.fs(context, 17),
                                            fontWeight: FontWeight.bold,
                                            color: outOfStock
                                                ? Colors.grey
                                                : isDark
                                                    ? Colors.white
                                                    : Colors.black87,
                                          ),
                                        ),
                                        SizedBox(height: R.sp(context, 4)),
                                        Text(
                                          '\$${(product['price'] as num).toDouble().toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontSize: R.fs(context, 16),
                                            fontWeight: FontWeight.bold,
                                            color: outOfStock ? Colors.grey : Colors.green.shade600,
                                          ),
                                        ),
                                        SizedBox(height: R.sp(context, 8)),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: R.sp(context, 12),
                                            vertical: R.sp(context, 5),
                                          ),
                                          decoration: BoxDecoration(
                                            color: outOfStock
                                                ? Colors.grey.withValues(alpha: 0.15)
                                                : lowStock
                                                    ? Colors.orange.withValues(alpha: 0.18)
                                                    : Theme.of(context).dividerColor.withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(R.sp(context, 12)),
                                          ),
                                          child: Text(
                                            outOfStock
                                                ? 'Agotado'
                                                : lowStock
                                                    ? 'Quedan $stock'
                                                    : 'Stock: $stock',
                                            style: TextStyle(
                                              fontSize: R.fs(context, 12),
                                              color: outOfStock
                                                  ? Colors.grey.shade600
                                                  : lowStock
                                                      ? Colors.orange.shade800
                                                      : Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!outOfStock)
                              Positioned(
                                top: R.sp(context, 8),
                                right: R.sp(context, 8),
                                child: IgnorePointer(
                                  child: AnimatedScale(
                                    scale: _plusOneId == product['id'] ? 1 : 0.5,
                                    duration: const Duration(milliseconds: 150),
                                    child: AnimatedOpacity(
                                      opacity: _plusOneId == product['id'] ? 1 : 0,
                                      duration: const Duration(milliseconds: 250),
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: R.sp(context, 10),
                                          vertical: R.sp(context, 5),
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green,
                                          borderRadius: BorderRadius.circular(R.sp(context, 14)),
                                        ),
                                        child: AnimatedSwitcher(
                                          duration: const Duration(milliseconds: 150),
                                          transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                                          child: Text(
                                            _plusOneCheck ? '✓' : '+1',
                                            key: ValueKey(_plusOneCheck),
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: R.fs(context, 15),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
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
              Badge(
                isLabelVisible: cart.isNotEmpty,
                label: Text('${cart.length}'),
                backgroundColor: Colors.blue,
                textColor: Colors.white,
                child: IconButton(
                  icon: Icon(
                    LucideIcons.shoppingCart,
                    color: Theme.of(context).colorScheme.primary,
                    size: 28,
                  ),
                  onPressed: _showCartSheet,
                  tooltip: 'Ver carrito',
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${cart.length} ${cart.length == 1 ? 'producto' : 'productos'} · \$${total.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: R.fs(context, 18),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 130,
                height: 48,
                child: ElevatedButton(
                  onPressed: cart.isEmpty
                      ? null
                      : () {
                          if (selectedStudent == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Seleccioná ${StoreConfig.instance.entityLC()} y productos')),
                            );
                            return;
                          }
                          _showCartSheet();
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    disabledBackgroundColor: Colors.grey.shade400,
                    disabledForegroundColor: Colors.white,
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

  void _showCartSheet() {
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
                                                width: 44,
                                                height: 44,
                                                decoration: BoxDecoration(
                                                  color: Colors.red.shade100,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(LucideIcons.minus, size: 20, color: Colors.red),
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
                                            _CartPlusButton(
                                              onAdd: () {
                                                setState(() {
                                                  item['quantity']++;
                                                  calculateTotal();
                                                });
                                                setSheetState(() {});
                                              },
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
  }
}

class _CartPlusButton extends StatefulWidget {
  final VoidCallback onAdd;

  const _CartPlusButton({required this.onAdd});

  @override
  State<_CartPlusButton> createState() => _CartPlusButtonState();
}

class _CartPlusButtonState extends State<_CartPlusButton> {
  bool _showCheck = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tap() {
    widget.onAdd();
    _timer?.cancel();
    setState(() => _showCheck = true);
    _timer = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _showCheck = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _tap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.green.shade100,
          shape: BoxShape.circle,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
          child: _showCheck
              ? const Icon(LucideIcons.check, key: ValueKey('check'), size: 20, color: Colors.green)
              : const Icon(LucideIcons.plus, key: ValueKey('plus'), size: 20, color: Colors.green),
        ),
      ),
    );
  }
}