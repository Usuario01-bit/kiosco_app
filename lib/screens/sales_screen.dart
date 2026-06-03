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

  // =====================================================
  // INIT
  // =====================================================

  @override
  void initState() {

    super.initState();

    loadData();
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
        '${now.day}/${now.month}/${now.year}',

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
        '${now.day}/${now.month}/${now.year}',

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
      const Color(0xFFF5F7FB),

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

          final productsWidget = Expanded(
            flex: isWide ? 3 : 1,

            child: RefreshIndicator(

              onRefresh: loadData,

              child: GridView.builder(

              padding:
              EdgeInsets.all(
                R.sp(context, 20),
              ),

              gridDelegate:
              SliverGridDelegateWithFixedCrossAxisCount(

                crossAxisCount: 2,

                crossAxisSpacing: 20,

                mainAxisSpacing: 20,

                childAspectRatio: isWide ? 0.92 : 0.7,
              ),

              itemCount:
              products.length,

              itemBuilder:
                  (context, index) {

                final product =
                products[index];

                return GestureDetector(

                  onTap: () {

                    addToCart(
                      product,
                    );
                  },

                  child:
                  AnimatedContainer(

                    duration:
                    const Duration(
                      milliseconds:
                      200,
                    ),

                    decoration:
                    BoxDecoration(

                      gradient:
                      LinearGradient(

                        colors: [

                          Colors.white,

                          const Color(
                            0xFFF8FBFF,
                          ),
                        ],

                        begin:
                        Alignment
                            .topLeft,

                        end:
                        Alignment
                            .bottomRight,
                      ),

                      borderRadius:
                      BorderRadius.circular(
                        32,
                      ),

                      boxShadow: [

                        BoxShadow(

                          color:
                          Colors
                              .black12,

                          blurRadius:
                          18,

                          offset:
                          const Offset(
                            0,
                            8,
                          ),
                        ),
                      ],

                      border:
                      Border.all(

                        color:
                        Colors
                            .white,

                        width: 2,
                      ),
                    ),

                    child: Padding(

                      padding:
                      const EdgeInsets.all(
                        14,
                      ),

                      child: Column(

                        mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,

                        children: [

                          // ICON

                          Container(

                            padding:
                            const EdgeInsets.all(
                              14,
                            ),

                            decoration:
                            BoxDecoration(

                              color:
                              Colors.blue.shade100,

                              shape:
                              BoxShape.circle,
                            ),

                            child: Icon(

                              productIcons[
                                  product['icon']
                                      as String?] ??
                                  Icons.fastfood_rounded,

                              size: 42,

                              color:
                              Colors.blue,
                            ),
                          ),

                          // NAME

                          Text(

                            product['name'],

                            textAlign:
                            TextAlign.center,

                            style:
                            const TextStyle(

                              fontSize:
                              22,

                              fontWeight:
                              FontWeight.bold,

                              color:
                              Color(
                                0xFF1E1E2D,
                              ),
                            ),
                          ),

                          // PRICE

                          Text(

                            '\$${(product['price'] as num).toDouble().toStringAsFixed(2)}',

                            style:
                            TextStyle(

                              fontSize:
                              24,

                              fontWeight:
                              FontWeight.bold,

                              color:
                              Colors.green.shade600,
                            ),
                          ),

                          // STOCK

                          Container(

                            padding:
                            const EdgeInsets.symmetric(

                              horizontal:
                              18,

                              vertical:
                              10,
                            ),

                            decoration:
                            BoxDecoration(

                              color:
                              const Color(
                                0xFFF5F5F5,
                              ),

                              borderRadius:
                              BorderRadius.circular(
                                18,
                              ),
                            ),

                            child: Text(

                              product['stock'] <= 0
                                  ? 'AGOTADO'
                                  : 'Stock: ${product['stock']}',

                              style: TextStyle(

                                fontSize: 16,

                                color:
                                product['stock'] <= 0
                                    ? Colors.red
                                    : Colors.black54,

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
          );

          final panelWidget = Expanded(
            flex: isWide ? 1 : 1,

            child: Container(

              padding:
              EdgeInsets.all(
                R.sp(context, 30),
              ),

              color:
              Theme.of(context).cardColor,

              child: Column(

                crossAxisAlignment:
                CrossAxisAlignment.start,

                children: [

                  const Text(

                    'Nueva Venta',

                    style: TextStyle(

                      fontSize: 36,

                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    height: 30,
                  ),

                  // STUDENT

                  DropdownButtonFormField<
                      String>(

                    value:
                    selectedStudent,

                    decoration:
                    const InputDecoration(

                      labelText:
                      'Estudiante',

                      border:
                      OutlineInputBorder(),
                    ),

                    items: students.map((student) {

                      return DropdownMenuItem<String>(

                        value:
                        student['name'],

                        child: Text(
                          student['name'],
                        ),
                      );
                    }).toList(),

                    onChanged: (value) {

                      setState(() {

                        selectedStudent =
                            value;
                      });
                    },
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  // PAYMENT METHOD

                  DropdownButtonFormField<
                      String>(

                    value:
                    paymentMethod,

                    decoration:
                    const InputDecoration(

                      labelText:
                      'Método de pago',

                      border:
                      OutlineInputBorder(),
                    ),

                    items: const [

                      DropdownMenuItem(

                        value:
                        'Efectivo',

                        child: Text(
                          'Efectivo',
                        ),
                      ),

                      DropdownMenuItem(

                        value:
                        'Yappy',

                        child: Text(
                          'Yappy',
                        ),
                      ),

                      DropdownMenuItem(

                        value:
                        'Pendiente',

                        child: Text(
                          'Pendiente',
                        ),
                      ),
                    ],

                    onChanged: (value) {

                      setState(() {

                        paymentMethod =
                        value!;
                      });
                    },
                  ),

                  const SizedBox(
                    height: 40,
                  ),

                  const Text(

                    'Carrito',

                    style: TextStyle(

                      fontSize: 28,

                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  Expanded(

                    child: cart.isEmpty

                        ? const Center(

                      child: Text(
                        'Sin productos',
                      ),
                    )

                        : ListView.builder(

                      itemCount:
                      cart.length,

                      itemBuilder:
                          (context,
                          index) {

                        final item =
                        cart[index];

                        return Card(

                          child:
                          ListTile(

                            title:
                            Text(
                              item[
                              'name'],
                            ),

                            subtitle: Row(

                              children: [

                                // MINUS

                                GestureDetector(

                                  onTap: () {

                                    setState(() {

                                      item['quantity']--;

                                      if (item['quantity'] <= 0) {

                                        cart.removeAt(index);
                                      }

                                      calculateTotal();
                                    });
                                  },

                                  child: Container(

                                    padding:
                                    const EdgeInsets.all(6),

                                    decoration:
                                    BoxDecoration(

                                      color:
                                      Colors.red.shade100,

                                      borderRadius:
                                      BorderRadius.circular(
                                        10,
                                      ),
                                    ),

                                    child: const Icon(

                                      Icons.remove,

                                      size: 18,

                                      color: Colors.red,
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 14),

                                // QUANTITY

                                Text(

                                  '${item['quantity']}',

                                  style: const TextStyle(

                                    fontSize: 18,

                                    fontWeight:
                                    FontWeight.bold,
                                  ),
                                ),

                                const SizedBox(width: 14),

                                // PLUS

                                GestureDetector(

                                  onTap: () {

                                    setState(() {

                                      item['quantity']++;

                                      calculateTotal();
                                    });
                                  },

                                  child: Container(

                                    padding:
                                    const EdgeInsets.all(6),

                                    decoration:
                                    BoxDecoration(

                                      color:
                                      Colors.green.shade100,

                                      borderRadius:
                                      BorderRadius.circular(
                                        10,
                                      ),
                                    ),

                                    child: const Icon(

                                      Icons.add,

                                      size: 18,

                                      color: Colors.green,
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 18),

                                Text(
                                  'x \$${item['price']}',
                                ),
                              ],
                            ),
                            trailing:
                            Text(
                              '\$${((item['price'] as num).toDouble() * item['quantity']).toStringAsFixed(2)}',
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  // TOTAL

                  Container(

                    width:
                    double.infinity,

                    padding:
                    const EdgeInsets.all(
                      30,
                    ),

                    decoration:
                    BoxDecoration(

                      color:
                      Colors.blue.shade50,

                      borderRadius:
                      BorderRadius.circular(
                        25,
                      ),
                    ),

                    child: Column(

                      children: [

                        const Text(

                          'TOTAL',

                          style:
                          TextStyle(

                            fontSize:
                            18,
                          ),
                        ),

                        const SizedBox(
                          height: 10,
                        ),

                        Text(

                          '\$${total.toStringAsFixed(2)}',

                          style:
                          const TextStyle(

                            fontSize:
                            48,

                            fontWeight:
                            FontWeight.bold,

                            color:
                            Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(
                    height: 25,
                  ),

                  // BUTTON

                  SizedBox(

                    width:
                    double.infinity,

                    height: 70,

                    child:
                    ElevatedButton(

                      onPressed:
                      completeSale,

                      style:
                      ElevatedButton.styleFrom(

                        backgroundColor:
                        Colors.blue,

                        shape:
                        RoundedRectangleBorder(

                          borderRadius:
                          BorderRadius.circular(
                            22,
                          ),
                        ),
                      ),

                      child:
                      const Text(

                        'Completar Venta',

                        style:
                        TextStyle(

                          color:
                          Colors.white,

                          fontSize: 26,

                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );

          if (isWide) {
            return Row(
              children: [productsWidget, panelWidget],
            );
          }
          return Column(
            children: [productsWidget, panelWidget],
          );
        },
      ),
    );
  }
}