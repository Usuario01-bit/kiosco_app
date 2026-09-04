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
import 'student_payment_chat_screen.dart';

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
          IconButton(
            icon: const Icon(LucideIcons.wallet),
            tooltip: 'Enviar pago',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StudentPaymentChatScreen(student: widget.student),
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
    final lowStock = stock > 0 && stock <= 5;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final imageUrl = product['image_url'] as String?;

    return GestureDetector(
      onTap: () {
        if (outOfStock) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Producto agotado'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
        if (qty >= stock) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Stock máximo disponible: $stock'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
        setState(() => cart[id] = qty + 1);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
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
          borderRadius: BorderRadius.circular(20),
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
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: outOfStock
                    ? Colors.grey.withValues(alpha: 0.15)
                    : cs.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        imageUrl,
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Icon(
                          resolveProductIcon(product),
                          size: 30,
                          color: outOfStock ? Colors.grey : cs.primary,
                        ),
                      ),
                    )
                  : Icon(
                      resolveProductIcon(product),
                      size: 30,
                      color: outOfStock ? Colors.grey : cs.primary,
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['name'] as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: outOfStock
                          ? Colors.grey
                          : isDark
                              ? Colors.white
                              : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\$${price.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: outOfStock ? Colors.grey : Colors.green.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: outOfStock
                          ? Colors.grey.withValues(alpha: 0.15)
                          : lowStock
                              ? Colors.orange.withValues(alpha: 0.18)
                              : Theme.of(context).dividerColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      outOfStock
                          ? 'Agotado'
                          : lowStock
                              ? 'Quedan $stock'
                              : 'Stock: $stock',
                      style: TextStyle(
                        fontSize: 12,
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
            if (!outOfStock) ...[
              if (qty > 0)
                GestureDetector(
                  onTap: () => setState(() {
                    if (qty <= 1) {
                      cart.remove(id);
                    } else {
                      cart[id] = qty - 1;
                    }
                  }),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.minus, size: 18, color: Colors.red),
                  ),
                ),
              if (qty > 0)
                SizedBox(
                  width: 28,
                  child: Text(
                    '$qty',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              _CatalogPlusButton(
                onAdd: () {
                  if (qty >= stock) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Stock máximo disponible: $stock'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }
                  setState(() => cart[id] = (cart[id] ?? 0) + 1);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _logout() async {
    final savedToken = await _storage.read(key: 'student_qr_token');
    if (savedToken != null && savedToken.isNotEmpty) {
      try {
        await SupabaseService.instance.clearStudentQrToken(savedToken);
      } catch (_) {}
    }
    await _storage.delete(key: 'student_qr_token');
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

class _CatalogPlusButton extends StatefulWidget {
  final VoidCallback onAdd;

  const _CatalogPlusButton({required this.onAdd});

  @override
  State<_CatalogPlusButton> createState() => _CatalogPlusButtonState();
}

class _CatalogPlusButtonState extends State<_CatalogPlusButton> {
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
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.green.shade100,
          shape: BoxShape.circle,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
          child: _showCheck
              ? const Icon(LucideIcons.check, key: ValueKey('check'), size: 18, color: Colors.green)
              : const Icon(LucideIcons.plus, key: ValueKey('plus'), size: 18, color: Colors.green),
        ),
      ),
    );
  }
}
