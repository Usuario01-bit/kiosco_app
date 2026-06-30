import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:async';
import 'package:flutter/material.dart';

import '../services/supabase_service.dart';
import '../services/product_icons.dart' show productIcons, resolveProductIcon;
import '../services/local_cache_service.dart';
import '../services/responsive.dart';


class ProductsScreen extends StatefulWidget {

  const ProductsScreen({
    super.key,
  });

  @override
  State<ProductsScreen> createState() =>
      _ProductsScreenState();
}

class _ProductsScreenState
    extends State<ProductsScreen> {

  List<Map<String, dynamic>> products = [];

  bool loading = true;

  StreamSubscription? _productsSub;

  @override
  void initState() {
    super.initState();
    _loadCachedThenStream();
  }

  Future<void> _loadCachedThenStream() async {
    final cached = await LocalCacheService.instance.getCachedProducts();
    if (cached.isNotEmpty && mounted) {
      setState(() { products = cached; loading = false; });
    }
    _productsSub = SupabaseService.instance
        .streamProducts()
        .listen((data) {
      if (mounted) setState(() { products = data; loading = false; });
    }, onError: (_) {
      if (mounted) setState(() => loading = false);
    });
  }

  @override
  void dispose() {
    _productsSub?.cancel();
    super.dispose();
  }

  Future<void> addProductDialog() async {

    final nameController =
    TextEditingController();

    final priceController =
    TextEditingController();

    final stockController =
    TextEditingController();

    String selectedIcon = 'inventory_2';
    String selectedCategory = 'General';

    final messenger = ScaffoldMessenger.of(context);

    showDialog(

      context: context,

      builder: (dialogContext) {

        return StatefulBuilder(
          builder: (_, setDialogState) {
        return AlertDialog(

          shape: RoundedRectangleBorder(

            borderRadius:
            BorderRadius.circular(20),
          ),

          title: const Text(
            'Nuevo Producto',
          ),

          content: Column(

            mainAxisSize: MainAxisSize.min, children: [ TextField( controller: nameController, decoration: InputDecoration( labelText: 'Nombre', border: OutlineInputBorder( borderRadius: BorderRadius.circular( 12, ), ), ), ), const SizedBox(height: 15), TextField( controller: priceController, keyboardType: TextInputType.number, decoration: InputDecoration( labelText: 'Precio', border: OutlineInputBorder( borderRadius: BorderRadius.circular( 12, ), ), ), ), const SizedBox(height: 15), TextField( controller: stockController, keyboardType: TextInputType.number, decoration: InputDecoration( labelText: 'Stock', border: OutlineInputBorder( borderRadius: BorderRadius.circular( 12, ), ), ), ), const SizedBox(height: 15), Align( alignment: Alignment.centerLeft, child: Text( 'Categoría', style: TextStyle( fontSize: 14, fontWeight: FontWeight.bold, color: Theme.of(context) .textTheme .bodyMedium?.color, ), ), ), const SizedBox(height: 8), DropdownButtonFormField<String>( value: selectedCategory, decoration: InputDecoration( border: OutlineInputBorder( borderRadius: BorderRadius.circular(12), ), contentPadding: const EdgeInsets.symmetric( horizontal: 12, vertical: 10, ), ), items: ['Emparedados', 'Empanadas', 'Especiales', 'Café', 'Bebidas', 'Duros', 'General'].map((c) => DropdownMenuItem( value: c, child: Text(c, style: const TextStyle(fontSize: 14)), )).toList(), onChanged: (v) { if (v != null) { setDialogState(() { selectedCategory = v; }); } }, ), const SizedBox(height: 20), Align( alignment: Alignment.centerLeft, child: Text( 'Icono', style: TextStyle( fontSize: 14, fontWeight: FontWeight.bold, color: Theme.of(context) .textTheme .bodyMedium?.color, ), ), ),             const SizedBox(height: 10), SizedBox( height: 120, child: SingleChildScrollView( child: Wrap( spacing: 8, runSpacing: 8, children: productIcons.entries .map((entry) { final isSelected = selectedIcon == entry.key; return GestureDetector( onTap: () { setDialogState(() { selectedIcon = entry.key; }); }, child: Container( width: 48, height: 48, decoration: BoxDecoration( color: isSelected ? const Color(0xFF2563EB) .withValues(alpha:  0.15) : Colors.grey .withValues(alpha: 0.08), borderRadius: BorderRadius.circular( 12), border: isSelected ? Border.all( color: const Color( 0xFF2563EB), width: 2) : null, ), child: Icon( entry.value, color: isSelected ? const Color( 0xFF2563EB) : Colors.grey[600], size: 24, ), ), ); }).toList(), ), ), ), ], ),

          actions: [

            TextButton(

              onPressed: () {

                Navigator.pop(dialogContext);
              },

              child: const Text(
                'Cancelar',
              ),
            ),

            ElevatedButton(

              style:
              ElevatedButton.styleFrom(

                backgroundColor:
                const Color(0xFF2563EB),
              ),

              onPressed: () async {

                final name = nameController.text.trim();
                final priceText = priceController.text.trim();
                final stockText = stockController.text.trim();

                if (name.isEmpty) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('El nombre no puede estar vacío')),
                  );
                  return;
                }

                final price = double.tryParse(priceText);
                if (price == null || price <= 0) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Ingresá un precio válido')),
                  );
                  return;
                }

                final stock = int.tryParse(stockText);
                if (stock == null || stock < 0) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Ingresá un stock válido')),
                  );
                  return;
                }

                try {

                  await SupabaseService.instance
                      .insertProduct({
                    'name': name,
                    'price': price,
                    'stock': stock,
                    'icon': selectedIcon,
                    'category': selectedCategory,
                  });
                } catch (e) {

                  if (!dialogContext.mounted) return;

                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        'Error al guardar: $e',
                      ),
                    ),
                  );

                  return;
                }

                if (!dialogContext.mounted) return;

                Navigator.pop(dialogContext);
              },

              child: const Text(
                'Guardar',
              ),
            ),
          ],
        );
      },
    );
  },
);
}

      Future<void> editProductDialog(
      Map<String, dynamic> product,
      ) async {

    final nameController =
    TextEditingController(
      text: product['name'],
    );

    final priceController =
    TextEditingController(
      text: product['price'].toString(),
    );

    final stockController =
    TextEditingController(
      text: product['stock'].toString(),
    );

    String selectedIcon =
        product['icon'] as String? ??
            'inventory_2';
    String selectedCategory =
        product['category'] as String? ??
            'General';

    final messenger = ScaffoldMessenger.of(context);

    showDialog(

      context: context,

      builder: (dialogContext) {

        return StatefulBuilder(
          builder: (_, setDialogState) {
        return AlertDialog(

          shape: RoundedRectangleBorder(

            borderRadius:
            BorderRadius.circular(20),
          ),

          title: const Text(
            'Editar Producto',
          ),

          content: Column(

            mainAxisSize: MainAxisSize.min,

            children: [

              TextField(

                controller: nameController,

                decoration:
                InputDecoration(

                  labelText: 'Nombre',

                  border:
                  OutlineInputBorder(

                    borderRadius:
                    BorderRadius.circular(
                      12,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 15),

              TextField(

                controller: priceController,

                keyboardType:
                TextInputType.number,

                decoration:
                InputDecoration(

                  labelText: 'Precio',

                  border:
                  OutlineInputBorder(

                    borderRadius:
                    BorderRadius.circular(
                      12,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 15),

              TextField(

                controller: stockController,

                keyboardType:
                TextInputType.number,

                decoration:
                InputDecoration(

                  labelText: 'Stock',

                  border:
                  OutlineInputBorder(

                    borderRadius:
                    BorderRadius.circular(
                      12,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 15),

              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Categoría',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.color,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(12),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                items: [
                  'Emparedados',
                  'Empanadas',
                  'Especiales',
                  'Café',
                  'Bebidas',
                  'Duros',
                  'General',
                ].map((c) => DropdownMenuItem(
                      value: c,
                      child: Text(
                        c,
                        style:
                            const TextStyle(fontSize: 14),
                      ),
                    )).toList(),
                onChanged: (v) {
                  if (v != null) {
                    setDialogState(() {
                      selectedCategory = v;
                    });
                  }
                },
              ),

              const SizedBox(height: 20),

              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Icono',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.color,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              SizedBox(
                height: 100,
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: productIcons.entries
                        .map((entry) {
                      final isSelected =
                          selectedIcon == entry.key;
                      return GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            selectedIcon = entry.key;
                          });
                        },
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(
                                        0xFF2563EB)
                                    .withValues(alpha: 0.15)
                                : Colors.grey
                                    .withValues(alpha: 0.08),
                            borderRadius:
                                BorderRadius.circular(
                              12,
                            ),
                            border: isSelected
                                ? Border.all(
                                    color: const Color(
                                      0xFF2563EB,
                                    ),
                                    width: 2,
                                  )
                                : null,
                          ),
                          child: Icon(
                            entry.value,
                            color: isSelected
                                ? const Color(0xFF2563EB)
                                                : Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                            size: 24,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),

          actions: [

            TextButton(

              onPressed: () {

                Navigator.pop(dialogContext);
              },

              child: const Text(
                'Cancelar',
              ),
            ),

            ElevatedButton(

              style:
              ElevatedButton.styleFrom(

                backgroundColor:
                const Color(0xFF2563EB),
              ),

              onPressed: () async {

                final name = nameController.text.trim();
                final priceText = priceController.text.trim();
                final stockText = stockController.text.trim();

                if (name.isEmpty) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('El nombre no puede estar vacío')),
                  );
                  return;
                }

                final price = double.tryParse(priceText);
                if (price == null || price <= 0) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Ingresá un precio válido')),
                  );
                  return;
                }

                final stock = int.tryParse(stockText);
                if (stock == null || stock < 0) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Ingresá un stock válido')),
                  );
                  return;
                }

                try {

                  await SupabaseService.instance
                      .updateProduct(
                    product['id'],
                    {
                      'name': name,
                      'price': price,
                      'stock': stock,
                      'icon': selectedIcon,
                      'category': selectedCategory,
                    },
                  );
                } catch (e) {

                  if (!dialogContext.mounted) return;

                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        'Error al guardar: $e',
                      ),
                    ),
                  );

                  return;
                }

                if (!dialogContext.mounted) return;

                Navigator.pop(dialogContext);

                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Producto agregado correctamente'),
                    backgroundColor: Colors.green,
                  ),
                );
              },

              child: const Text(
                'Guardar',
              ),
            ),
          ],
        );
      },
    );
  },
);
}

  Future<void> deleteProduct(
      int id,
      ) async {

    await SupabaseService.instance
        .deleteProduct(id);
  }

  Color getProductColor(
      int index,
      ) {

    final colors = [

      const Color(0xFFE0EAFF),

      const Color(0xFFFFF1DD),

      const Color(0xFFE8F7EC),

      const Color(0xFFF2E8FF),

      const Color(0xFFFFE5EF),

      const Color(0xFFE5F7FF),
    ];

    return colors[index % colors.length];
  }


  @override
  Widget build(BuildContext context) {

    if (loading) {

      return const Scaffold(

        body: Center(

          child:
          CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(

      backgroundColor:
      Theme.of(context).scaffoldBackgroundColor,

      body: Column(

        children: [

          // HEADER

          Container(

            padding:
            EdgeInsets.fromLTRB(
              R.sp(context, 25),
              R.sp(context, 60),
              R.sp(context, 25),
              R.sp(context, 30),
            ),

            decoration: const BoxDecoration(

              gradient: LinearGradient(

                colors: [

                  Color(0xFF2563EB),

                  Color(0xFF1D4ED8),
                ],
              ),
            ),

            child: Row(

              children: [

                Container(

                  padding: EdgeInsets.all(
                    R.sp(context, 22),
                  ),

                  decoration: BoxDecoration(

                    color: Colors.white24,

                    borderRadius:
                    BorderRadius.circular(
                      R.sp(context, 18),
                    ),
                  ),

                  child: Icon(

                    LucideIcons.package,

                    color: Colors.white,

                    size: R.sp(context, 38),
                  ),
                ),

                SizedBox(width: R.sp(context, 18)),

                Expanded(

                  child: Column(

                    crossAxisAlignment:
                    CrossAxisAlignment.start,

                    children: [

                      Text(

                        'Productos',

                        style: TextStyle(

                          color: Colors.white,

                          fontSize: R.fs(context, 34),

                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),

                      SizedBox(height: R.sp(context, 5)),

                      Text(

                        'Gestiona tu inventario',

                        style: TextStyle(

                          color: Colors.white70,

                          fontSize: R.fs(context, 18),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: IconButton(
                    icon: const Icon(LucideIcons.plus, color: Colors.white, size: 28),
                    onPressed: addProductDialog,
                    tooltip: 'Agregar producto',
                  ),
                ),
              ],
            ),
          ),

          // GRID

          Expanded(

            child: Padding(

              padding: EdgeInsets.all(R.sp(context, 20)),

              child: GridView.builder(
                itemCount: products.length,
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 420,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.8,
                ),

                itemBuilder:
                    (context, index) {

                  final product =
                  products[index];

                  return Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(context).dividerColor,
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(R.sp(context, 12)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                resolveProductIcon(product),
                                size: R.sp(context, 28),
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              SizedBox(width: R.sp(context, 10)),
                              Expanded(
                                child: Text(
                                  product['name'],
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: R.fs(context, 15),
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).textTheme.bodyLarge?.color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          // price + stock + buttons
                          Row(
                            children: [
                              Text(
                                '\$${product['price'].toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: R.fs(context, 18),
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.green.shade300
                                      : const Color(0xFF16A34A),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (product['stock'] <= 5)
                                Padding(
                                  padding: EdgeInsets.only(left: R.sp(context, 8)),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? (product['stock'] <= 0 ? Colors.red.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2))
                                          : (product['stock'] <= 0 ? Colors.red.shade50 : Colors.orange.shade50),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      product['stock'] <= 0 ? 'AGOTADO' : '${product['stock']}',
                                      style: TextStyle(
                                        fontSize: R.fs(context, 11),
                                        color: product['stock'] <= 0 ? Colors.red : Colors.orange,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              const Spacer(),
                              SizedBox(
                                height: 30,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: Theme.of(context).colorScheme.primary),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                  ),
                                  onPressed: () => editProductDialog(product),
                                  icon: const Icon(LucideIcons.pencil, size: 12),
                                  label: const Text('Editar', style: TextStyle(fontSize: 11)),
                                ),
                              ),
                              const SizedBox(width: 6),
                              SizedBox(
                                height: 30,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Colors.red),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                  ),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        title: const Text('Eliminar producto'),
                                        content: Text('¿Seguro que querés eliminar "${product['name']}"?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx),
                                            child: const Text('Cancelar'),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                            ),
                                            onPressed: () {
                                              Navigator.pop(ctx);
                                              deleteProduct(product['id']);
                                            },
                                            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  icon: const Icon(LucideIcons.trash2, size: 12),
                                  label: const Text('Eliminar', style: TextStyle(fontSize: 11)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}