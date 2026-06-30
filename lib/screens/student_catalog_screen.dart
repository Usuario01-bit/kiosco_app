import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../services/supabase_service.dart';
import '../services/product_icons.dart' show resolveProductIcon;
import '../services/local_cache_service.dart';
import 'student_checkout_screen.dart';
import 'student_history_screen.dart';
import 'student_login_screen.dart';
import 'student_qr_screen.dart';

class StudentCatalogScreen extends StatefulWidget {
  final Map<String, dynamic> student;

  const StudentCatalogScreen({super.key, required this.student});

  @override
  State<StudentCatalogScreen> createState() => _StudentCatalogScreenState();
}

class _StudentCatalogScreenState extends State<StudentCatalogScreen> {
  final _storage = const FlutterSecureStorage();
  List<Map<String, dynamic>> products = [];
  final Map<String, int> cart = {};
  StreamSubscription? _productsSub;

  @override
  void initState() {
    super.initState();
    _loadCachedThenStream();
  }

  Future<void> _loadCachedThenStream() async {
    final cached = await LocalCacheService.instance.getCachedProducts();
    if (cached.isNotEmpty && mounted) {
      setState(() => products = cached);
    }
    _productsSub = SupabaseService.instance.streamProducts().listen((data) {
      if (mounted) setState(() => products = data);
    }, onError: (_) {
      if (mounted && products.isEmpty) setState(() => products = []);
    });
  }

  @override
  void dispose() {
    _productsSub?.cancel();
    super.dispose();
  }

  int get cartCount => cart.values.fold(0, (a, b) => a + b);
  double get cartTotal {
    double t = 0;
    for (final item in products) {
      final id = item['id'] as String;
      if (cart.containsKey(id)) {
        t += (item['price'] as num).toDouble() * cart[id]!;
      }
    }
    return t;
  }

  Set<String> get categories => products.map((p) => p['category'] as String? ?? 'General').toSet();

  List<Map<String, dynamic>> productsInCategory(String cat) {
    return products.where((p) => (p['category'] as String? ?? 'General') == cat).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sortedCategories = categories.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: Text('Hola, ${widget.student['name']}'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.qrCode),
            tooltip: 'Mi QR',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StudentQrScreen(student: widget.student),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(LucideIcons.history),
            tooltip: 'Mis compras',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StudentHistoryScreen(student: widget.student),
                ),
              );
            },
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(LucideIcons.shoppingCart),
                tooltip: 'Carrito',
                onPressed: () => _goToCheckout(),
              ),
              if (cartCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: cs.error, shape: BoxShape.circle),
                    child: Text(
                      '$cartCount',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(LucideIcons.logOut),
            tooltip: 'Cerrar sesión',
            onPressed: _logout,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: products.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.cloudOff, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text('Sin conexión', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sortedCategories.length,
              itemBuilder: (context, index) {
                final cat = sortedCategories[index];
                final catProducts = productsInCategory(cat);
                if (catProducts.isEmpty) return const SizedBox.shrink();
                return _buildCategorySection(context, cs, cat, catProducts);
              },
            ),
    );
  }

  Widget _buildCategorySection(BuildContext context, ColorScheme cs, String category, List<Map<String, dynamic>> catProducts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 16, bottom: 8),
          child: Text(
            category,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: cs.primary,
            ),
          ),
        ),
        ...catProducts.map((p) => _buildProductCard(context, cs, p)),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildProductCard(BuildContext context, ColorScheme cs, Map<String, dynamic> product) {
    final id = product['id'] as String;
    final qty = cart[id] ?? 0;
    final stock = (product['stock'] as num?)?.toInt() ?? 0;
    final price = (product['price'] as num).toDouble();
    final outOfStock = stock <= 0;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(resolveProductIcon(product), size: 28, color: cs.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['name'] as String,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    outOfStock ? 'AGOTADO' : '\$${price.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: outOfStock ? cs.error : Colors.green,
                    ),
                  ),
                ],
              ),
            ),
            if (outOfStock)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.errorContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('AGOTADO', style: TextStyle(color: cs.error, fontSize: 11, fontWeight: FontWeight.bold)),
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (qty > 0)
                    IconButton(
                      icon: const Icon(LucideIcons.minus_circle_outline),
                      onPressed: () => setState(() {
                        if (qty <= 1) {
                          cart.remove(id);
                        } else {
                          cart[id] = qty - 1;
                        }
                      }),
                    ),
                  if (qty > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('$qty', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  IconButton(
                    icon: Icon(LucideIcons.plus_circle, color: cs.primary),
                    onPressed: () {
                      if (qty >= stock) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(stock <= 0 ? 'Producto agotado' : 'Stock máximo disponible: $stock'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }
                      setState(() => cart[id] = (cart[id] ?? 0) + 1);
                    },
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _logout() async {
    await _storage.delete(key: 'student_qr_token');
    try {
      await SupabaseService.instance.setStudentQrToken(widget.student['id'], '');
    } catch (_) {}
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const StudentLoginScreen()),
      (route) => false,
    );
  }

  void _goToCheckout() {
    if (cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agregá productos al carrito primero')),
      );
      return;
    }
    final cartItems = cart.entries.map((e) {
      final product = products.firstWhere((p) => p['id'] == e.key);
      return {
        'product': product,
        'quantity': e.value,
      };
    }).toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentCheckoutScreen(
          student: widget.student,
          cartItems: cartItems,
        ),
      ),
    ).then((_) {
      setState(() => cart.clear());
    });
  }
}
