import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/date_utils.dart';
import '../services/product_icons.dart' show resolveProductIcon;
import '../services/local_cache_service.dart';
import '../services/responsive.dart';
import '../services/store_config.dart';
import 'student_qr_scanner_screen.dart';

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

  // =====================================================
  // ESCALADO LOCAL
  // =====================================================

  /// `R.sp`/`R.fs` escalan lineal con el ancho de la ventana, asi que en un
  /// monitor se vuelven gigantes. En esta pantalla el factor se limita a 1.5x:
  /// en celular y tablet escala igual que el resto de la app, y en desktop
  /// queda compacto en lugar de desbordarse.
  double get _scale => (MediaQuery.sizeOf(context).width / 430).clamp(1.0, 1.5);

  double _s(double value) => value * _scale;

  double _f(double value) => value * _scale;

  // =====================================================
  // HELPERS DE PRESENTACION
  // =====================================================

  /// Registro completo del alumno seleccionado, para mostrar grado y datos
  /// sin depender de que el nombre sea unico.
  Map<String, dynamic>? get _selectedStudentRecord {
    final id = selectedStudentId;
    if (id == null) return null;
    for (final s in students) {
      if (s['id']?.toString() == id) return s;
    }
    return null;
  }

  String _initialsOf(String? name) {
    final clean = (name ?? '').trim();
    if (clean.isEmpty) return '?';
    final parts = clean.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  String _studentSubtitle(Map<String, dynamic>? student) {
    if (student == null) return '';
    final grade = (student['grade'] ?? student['grado'])?.toString().trim();
    return (grade == null || grade.isEmpty) ? '' : grade;
  }

  void _selectStudent(Map<String, dynamic> student) {
    setState(() {
      selectedStudent = student['name'] as String?;
      selectedStudentId = student['id']?.toString();
      studentSearchController.clear();
    });
  }

  void _clearStudent() {
    setState(() {
      selectedStudent = null;
      selectedStudentId = null;
      studentSearchController.clear();
    });
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: _s(16), vertical: _s(8)),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary
              : (isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFEFF1F5)),
          borderRadius: BorderRadius.circular(_s(20)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: _f(14),
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? cs.onPrimary
                : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }

  /// Color del semaforo de stock. El verde queda reservado para
  /// disponibilidad: precio va en el color primario, nunca en verde.
  Color _stockColor(int stock, bool isDark) {
    if (stock <= 0) return Colors.grey;
    if (stock <= 5) {
      return isDark ? Colors.orange.shade300 : Colors.orange.shade800;
    }
    return isDark ? Colors.green.shade400 : Colors.green.shade600;
  }

  List<Map<String, dynamic>> get _filteredStudents {
    final query = studentSearchController.text.toLowerCase().trim();
    if (query.isEmpty) return [];
    return students.where((s) {
      final name = (s['name'] as String? ?? '').toLowerCase();
      return name.contains(query);
    }).toList();
  }

  // =====================================================
  // QR
  // =====================================================

  Future<void> _openQrScanner() async {
    // mobile_scanner no soporta Windows/Linux: se avisa en vez de abrir una
    // pantalla que va a fallar al inicializar la camara.
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El escaner QR solo esta disponible en Android e iOS'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentQrScannerScreen(
          onStudentFound: (student, token) {
            setState(() {
              final id = student['id']?.toString();
              if (id != null && !students.any((s) => s['id']?.toString() == id)) {
                students = [...students, student];
              }
              selectedStudent = student['name'] as String?;
              selectedStudentId = id;
              studentSearchController.clear();
            });
            Navigator.pop(context);
          },
        ),
      ),
    );
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

      // Un cobro en el mostrador ya esta pago: paid_at se setea salvo
      // que la venta sea fiado. Sin esto, una venta en efectivo queda
      // con paid_at NULL y los reportes la muestran como impaga.
      final isFiado = currentPaymentMethod.toLowerCase().trim() == 'pendiente';
      final soldAt = DateTime.now().toIso8601String();

      final saleRows = cartSnapshot.map((item) {
        return {
          'student_id': currentStudentId ?? '',
          'product_id': item['id'],
          'quantity': item['quantity'],
          'total': (item['price'] as num).toDouble() * item['quantity'],
          'payment_method': currentPaymentMethod,
          'paid_at': isFiado ? null : soldAt,
          'prepared_at': soldAt,
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

      if (isFiado) {
        await SupabaseService.instance
            .insertPending({
          'student_id': currentStudentId,
          'student': currentStudent,
          'amount': currentTotal,
          'created_at': soldAt,
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

  StreamSubscription? _studentsSub;
  StreamSubscription? _productsSub;

  // =====================================================
  // BUILD
  // =====================================================

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Ventas'),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final columns = width >= 1300
              ? 5
              : width >= 900
                  ? 4
                  : width >= 600
                      ? 3
                      : 2;

          final filtered = selectedCategory == null
              ? products
              : products
                  .where((p) =>
                      (p['category'] as String? ?? 'General') ==
                      selectedCategory)
                  .toList();

          final selectedRecord = _selectedStudentRecord;

          return Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(_s(16), _s(14), _s(16), 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ---- Buscador + QR ----
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: studentSearchController,
                            decoration: InputDecoration(
                              hintText:
                                  'Buscar ${StoreConfig.instance.entityLC()}...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(_s(14)),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: _s(16),
                                vertical: _s(14),
                              ),
                              prefixIcon: const Icon(LucideIcons.search),
                              suffixIcon: selectedStudent != null
                                  ? IconButton(
                                      icon: const Icon(LucideIcons.x),
                                      onPressed: _clearStudent,
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
                        ),
                        SizedBox(width: _s(10)),
                        SizedBox(
                          width: _s(52),
                          height: _s(52),
                          child: OutlinedButton(
                            onPressed: _openQrScanner,
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              side: BorderSide(
                                color: cs.primary.withValues(alpha: 0.4),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(_s(14)),
                              ),
                            ),
                            child: Icon(
                              LucideIcons.qrCode,
                              color: cs.primary,
                              size: _f(22),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // ---- Alumno seleccionado ----
                    if (selectedStudent != null)
                      Padding(
                        padding: EdgeInsets.only(top: _s(10)),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: _s(12),
                            vertical: _s(10),
                          ),
                          decoration: BoxDecoration(
                            color: cs.primary.withValues(alpha: isDark ? 0.18 : 0.08),
                            borderRadius: BorderRadius.circular(_s(16)),
                            border: Border.all(
                              color: cs.primary.withValues(alpha: 0.28),
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: _s(21),
                                backgroundColor:
                                    cs.primary.withValues(alpha: 0.16),
                                child: Text(
                                  _initialsOf(selectedStudent),
                                  style: TextStyle(
                                    fontSize: _f(15),
                                    fontWeight: FontWeight.w700,
                                    color: cs.primary,
                                  ),
                                ),
                              ),
                              SizedBox(width: _s(12)),
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      selectedStudent!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: _f(16),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (_studentSubtitle(selectedRecord).isNotEmpty)
                                      Text(
                                        _studentSubtitle(selectedRecord),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: _f(12),
                                          color: isDark
                                              ? Colors.white60
                                              : Colors.black54,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(LucideIcons.x, size: _f(18)),
                                color: isDark ? Colors.white54 : Colors.black45,
                                onPressed: _clearStudent,
                              ),
                            ],
                          ),
                        ),
                      ),

                    // ---- Sugerencias de busqueda ----
                    if (selectedStudent == null && _filteredStudents.isNotEmpty)
                      Container(
                        constraints: BoxConstraints(maxHeight: _s(220)),
                        margin: EdgeInsets.only(top: _s(6)),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(_s(16)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ListView.builder(
                          padding: EdgeInsets.symmetric(vertical: _s(6)),
                          itemCount: _filteredStudents.length,
                          itemBuilder: (context, index) {
                            final s = _filteredStudents[index];
                            final subtitle = _studentSubtitle(s);
                            return ListTile(
                              dense: true,
                              title: Text(
                                s['name'] as String? ?? '',
                                style: TextStyle(
                                  fontSize: _f(16),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: subtitle.isEmpty
                                  ? null
                                  : Text(
                                      subtitle,
                                      style: TextStyle(
                                        fontSize: _f(13),
                                        color: isDark
                                            ? Colors.white60
                                            : Colors.black54,
                                      ),
                                    ),
                              onTap: () => _selectStudent(s),
                            );
                          },
                        ),
                      ),

                    SizedBox(height: _s(10)),

                    // ---- Metodo de pago ----
                    DropdownButtonFormField<String>(
                      initialValue: paymentMethod,
                      decoration: InputDecoration(
                        labelText: 'Método de pago',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(_s(14)),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: _s(14),
                          vertical: _s(12),
                        ),
                      ),
                      items: [
                        _paymentOption('Efectivo', LucideIcons.banknote,
                            isDark ? Colors.green.shade300 : Colors.green.shade700),
                        _paymentOption('Yappy', LucideIcons.smartphone,
                            isDark ? Colors.blue.shade200 : Colors.blue.shade700),
                        _paymentOption('Pendiente', LucideIcons.clock,
                            isDark ? Colors.orange.shade300 : Colors.orange.shade800),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => paymentMethod = value);
                      },
                    ),
                  ],
                ),
              ),

              // ---- Categorias ----
              SizedBox(height: _s(10)),
              SizedBox(
                height: _s(38),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: _s(16)),
                  children: [
                    Padding(
                      padding: EdgeInsets.only(right: _s(8)),
                      child: _filterChip(
                        'Todas',
                        selectedCategory == null,
                        () => setState(() => selectedCategory = null),
                      ),
                    ),
                    ...products
                        .map((p) => p['category'] as String? ?? 'General')
                        .toSet()
                        .map((cat) => Padding(
                              padding: EdgeInsets.only(right: _s(8)),
                              child: _filterChip(
                                cat,
                                selectedCategory == cat,
                                () => setState(() => selectedCategory = cat),
                              ),
                            )),
                  ],
                ),
              ),

              SizedBox(height: _s(8)),

              // ---- Grilla de productos ----
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No hay productos en esta categoría',
                          style: TextStyle(
                            fontSize: _f(14),
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      )
                    : GridView.builder(
                        padding: EdgeInsets.fromLTRB(_s(16), 0, _s(16), _s(16)),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: _s(10),
                          mainAxisSpacing: _s(10),
                          mainAxisExtent: _s(226),
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) =>
                            _productTile(context, filtered[index]),
                      ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: _cartBar(context),
    );
  }

  DropdownMenuItem<String> _paymentOption(
      String value, IconData icon, Color color) {
    return DropdownMenuItem<String>(
      value: value,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: _f(18), color: color),
          SizedBox(width: _s(10)),
          Text(value),
        ],
      ),
    );
  }

  // =====================================================
  // TILE DE PRODUCTO
  // =====================================================

  Widget _productTile(BuildContext context, Map<String, dynamic> product) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final stock = (product['stock'] as num?)?.toInt() ?? 0;
    final outOfStock = stock <= 0;
    final lowStock = stock > 0 && stock <= 5;
    final imageUrl = product['image_url'] as String?;
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    final stockColor = _stockColor(stock, isDark);
    final stockLabel = outOfStock
        ? 'Agotado'
        : lowStock
            ? 'Quedan $stock'
            : '$stock disp.';

    return GestureDetector(
      onTap: outOfStock ? null : () => addToCart(product),
      child: Stack(
        children: [
          Container(
            padding: EdgeInsets.all(_s(10)),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: outOfStock
                    ? (isDark
                        ? const [Color(0xFF3A3A3A), Color(0xFF2E2E2E)]
                        : const [Color(0xFFE9E9E9), Color(0xFFDDDDDD)])
                    : [
                        Theme.of(context).cardColor,
                        isDark
                            ? Theme.of(context).cardColor
                            : const Color(0xFFF8FBFF),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(_s(18)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: outOfStock
                    ? Colors.grey.shade400
                    : (isDark ? Colors.white24 : Colors.white),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Imagen / icono del producto
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(_s(12)),
                    child: Container(
                      width: double.infinity,
                      color: outOfStock
                          ? Colors.grey.withValues(alpha: 0.15)
                          : cs.primary.withValues(alpha: 0.08),
                      child: hasImage
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              errorBuilder: (_, _, _) => Icon(
                                _productIcon(product),
                                size: _f(38),
                                color: outOfStock ? Colors.grey : cs.primary,
                              ),
                            )
                          : Icon(
                              _productIcon(product),
                              size: _f(38),
                              color: outOfStock ? Colors.grey : cs.primary,
                            ),
                    ),
                  ),
                ),
                SizedBox(height: _s(8)),
                Text(
                  product['name'] as String? ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: _f(14),
                    fontWeight: FontWeight.w700,
                    color: outOfStock
                        ? Colors.grey
                        : (isDark ? Colors.white : Colors.black87),
                  ),
                ),
                SizedBox(height: _s(2)),
                // Precio: color primario (marca), nunca verde.
                Text(
                  '\$${(product['price'] as num).toDouble().toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: _f(15),
                    fontWeight: FontWeight.w700,
                    color: outOfStock ? Colors.grey : cs.primary,
                  ),
                ),
                SizedBox(height: _s(5)),
                // Stock: el verde queda reservado para disponibilidad.
                Row(
                  children: [
                    Container(
                      width: _s(7),
                      height: _s(7),
                      decoration: BoxDecoration(
                        color: stockColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: _s(5)),
                    Flexible(
                      child: Text(
                        stockLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: _f(11),
                          fontWeight: FontWeight.w600,
                          color: stockColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!outOfStock)
            Positioned(
              top: _s(8),
              right: _s(8),
              child: IgnorePointer(
                child: AnimatedScale(
                  scale: _plusOneId == product['id'] ? 1 : 0.5,
                  duration: const Duration(milliseconds: 150),
                  child: AnimatedOpacity(
                    opacity: _plusOneId == product['id'] ? 1 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: _s(10),
                        vertical: _s(5),
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(_s(14)),
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 150),
                        transitionBuilder: (child, anim) =>
                            ScaleTransition(scale: anim, child: child),
                        child: Text(
                          _plusOneCheck ? '✓' : '+1',
                          key: ValueKey(_plusOneCheck),
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: _f(14),
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
  }

  // =====================================================
  // BARRA DE CARRITO
  // =====================================================

  Widget _cartBar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: _s(78) + MediaQuery.of(context).padding.bottom,
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
        padding: EdgeInsets.symmetric(horizontal: _s(16)),
        child: Row(
          children: [
            Badge(
              isLabelVisible: cart.isNotEmpty,
              label: Text('${cart.length}'),
              backgroundColor: cs.primary,
              textColor: cs.onPrimary,
              child: IconButton(
                icon: Icon(
                  LucideIcons.shoppingCart,
                  color: cs.primary,
                  size: _f(26),
                ),
                onPressed: _showCartSheet,
                tooltip: 'Ver carrito',
              ),
            ),
            SizedBox(width: _s(6)),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${cart.length} ${cart.length == 1 ? 'producto' : 'productos'}',
                    style: TextStyle(
                      fontSize: _f(12),
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                  Text(
                    'Total: \$${total.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: _f(18),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: _s(10)),
            SizedBox(
              height: _s(46),
              child: ElevatedButton(
                onPressed: cart.isEmpty
                    ? null
                    : () {
                        if (selectedStudent == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Seleccioná ${StoreConfig.instance.entityLC()} y productos',
                              ),
                            ),
                          );
                          return;
                        }
                        _showCartSheet();
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  disabledBackgroundColor: Colors.grey.shade400,
                  disabledForegroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: _s(18)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_s(14)),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      cart.isEmpty
                          ? 'Pagar'
                          : 'Pagar \$${total.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: _f(15),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: _s(6)),
                    Icon(LucideIcons.chevronRight, size: _f(18)),
                  ],
                ),
              ),
            ),
          ],
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
