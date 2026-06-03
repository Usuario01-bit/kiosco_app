import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';
import '../services/responsive.dart';

class ReportsScreen extends StatefulWidget {

  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() =>
      _ReportsScreenState();
}

class _ReportsScreenState
    extends State<ReportsScreen> {

  // =====================================================
  // VARIABLES
  // =====================================================

  double totalSales = 0;
  String selectedFilter = 'Hoy';

  double efectivoTotal = 0;

  double yappyTotal = 0;

  double pendienteTotal = 0;
  double recreo1Total = 0;

  double recreo2Total = 0;
  int totalTransactions = 0;
  String topProduct = '';

  int topProductCount = 0;

  List<Map<String, dynamic>> sales = [];

  // =====================================================
  // INIT
  // =====================================================

  @override
  void initState() {

    super.initState();

    loadReports();
  }

  // =====================================================
  // LOAD REPORTS
  // =====================================================

  Future<void> loadReports() async {

    var salesData =
    await FirestoreService.instance
        .getSales();

    double total = 0;

    double efectivo = 0;

    double yappy = 0;

    double pendiente = 0;

    Map<String, int> productCounter = {};

    String bestProduct = 'Ninguno';

    int bestCount = 0;
    final now = DateTime.now();

    salesData = salesData.where((sale) {

      final dateText = sale['date'] ?? '';

      // HOY
      if (selectedFilter == 'Hoy') {

        return dateText.contains(
          '${now.day}/${now.month}/${now.year}',
        );
      }

      // SEMANA
      if (selectedFilter == 'Semana') {
        return true;
      }

      // MES
      if (selectedFilter == 'Mes') {

        return dateText.contains(
          '/${now.month}/${now.year}',
        );
      }

      return true;

    }).toList();
    for (var sale in salesData) {

      String product =
          sale['product'] ?? '';

      if (product.isNotEmpty) {

        productCounter[product] =
            (productCounter[product] ?? 0) + 1;

        if (productCounter[product]! >
            bestCount) {

          bestCount =
          productCounter[product]!;

          bestProduct = product;
        }
      }

      final amount =

      (sale['total'] as num)
          .toDouble();

      total += amount;

      if (sale['paymentMethod'] ==
          'Efectivo') {

        efectivo += amount;
      }

      if (sale['paymentMethod'] ==
          'Yappy') {

        yappy += amount;
      }

        if (sale['paymentMethod'] ==
            'Pendiente') {

          pendiente += amount;

          if (sale['recreo'] ==
              'Recreo 1') {

            recreo1Total += amount;
          }

          if (sale['recreo'] ==
              'Recreo 2') {

            recreo2Total += amount;
          }
        }
    }

    setState(() {
      this.recreo1Total =
          recreo1Total;

      this.recreo2Total =
          recreo2Total;

      sales = salesData;

      totalSales = total;

      efectivoTotal = efectivo;

      yappyTotal = yappy;

      pendienteTotal = pendiente;

      totalTransactions =
          salesData.length;

      topProduct = bestProduct;

      topProductCount = bestCount;

    });
  }

  // =====================================================
  // BUILD
  // =====================================================

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor:
      const Color(0xFFF5F7FB),


      body: RefreshIndicator(

        onRefresh: loadReports,

        child: SingleChildScrollView(


        padding: EdgeInsets.all(
          R.sp(context, 24),
        ),

        child: Column(

          crossAxisAlignment:
          CrossAxisAlignment.start,

          children: [
            SizedBox(
              height: R.sp(context, 50),

              child: ListView(
                scrollDirection: Axis.horizontal,

                children: [

                  filterButton(
                    'Hoy',
                    selectedFilter == 'Hoy',
                        () {
                      setState(() {
                        selectedFilter = 'Hoy';
                      });

                      loadReports();
                    },
                  ),

                  filterButton(
                    'Semana',
                    selectedFilter == 'Semana',
                        () {
                      setState(() {
                        selectedFilter = 'Semana';
                      });

                      loadReports();
                    },
                  ),

                  filterButton(
                    'Mes',
                    selectedFilter == 'Mes',
                        () {
                      setState(() {
                        selectedFilter = 'Mes';
                      });

                      loadReports();
                    },
                  ),

                ],
              ),
            ),
            SizedBox(height: R.sp(context, 20)),

            // =================================================
            // TITLE
            // =================================================

            Text(

              'Reportes',

              style: TextStyle(

                fontSize: R.fs(context, 38),

                fontWeight:
                FontWeight.bold,

                color:
                const Color(0xFF1E1E2D),
              ),
            ),

            SizedBox(height: R.sp(context, 10)),

            Text(

              'Resumen general del kiosco',

              style: TextStyle(

                fontSize: R.fs(context, 18),

                color:
                Colors.black54,
              ),
            ),

            SizedBox(height: R.sp(context, 30)),

            // =================================================
            // TOP CARDS
            // =================================================

            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 500;
                final cards = [
                  reportCard(
                    title: 'Ventas Totales',
                    value: '\$${totalSales.toStringAsFixed(2)}',
                    color: Colors.blue,
                    icon: Icons.attach_money,
                  ),
                  reportCard(
                    title: 'Transacciones',
                    value: '$totalTransactions',
                    color: Colors.orange,
                    icon: Icons.receipt_long,
                  ),
                  reportCard(
                    title: 'Pendientes',
                    value: '\$${pendienteTotal.toStringAsFixed(2)}',
                    color: Colors.red,
                    icon: Icons.warning_rounded,
                  ),
                ];

                if (isWide) {
                  return Row(
                    children: [
                      Expanded(child: cards[0]),
                      const SizedBox(width: 30),
                      Expanded(child: cards[1]),
                      const SizedBox(width: 20),
                      Expanded(child: cards[2]),
                    ],
                  );
                }
                  return Column(
                    children: [
                      cards[0],
                      SizedBox(height: R.sp(context, 20)),
                      cards[1],
                      SizedBox(height: R.sp(context, 20)),
                      cards[2],
                    ],
                  );
                },
              ),

              SizedBox(height: R.sp(context, 30)),

            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 500;
                final cards = [
                  reportCard(
                    title: 'Recreo 1',
                    value: '\$${recreo1Total.toStringAsFixed(2)}',
                    color: Colors.purple,
                    icon: Icons.schedule,
                  ),
                  reportCard(
                    title: 'Recreo 2',
                    value: '\$${recreo2Total.toStringAsFixed(2)}',
                    color: Colors.teal,
                    icon: Icons.access_time_filled,
                  ),
                ];

                if (isWide) {
                  return Row(
                    children: [
                      Expanded(child: cards[0]),
                      const SizedBox(width: 20),
                      Expanded(child: cards[1]),
                    ],
                  );
                }
                return Column(
                  children: [
                    cards[0],
                    SizedBox(height: R.sp(context, 20)),
                    cards[1],
                  ],
                );
              },
            ),

            // =================================================
            // CHART
            // =================================================

            Container(

              padding: EdgeInsets.all(
                R.sp(context, 24),
              ),

              decoration:
              BoxDecoration(

                color: Colors.white,

                borderRadius:
                BorderRadius.circular(
                  28,
                ),

                boxShadow: [

                  BoxShadow(

                    color: Colors.black
                        .withValues(alpha: 
                      0.05,
                    ),

                    blurRadius: 18,

                    offset:
                    const Offset(
                      0,
                      8,
                    ),
                  ),
                ],
              ),

              child: Column(

                crossAxisAlignment:
                CrossAxisAlignment
                    .start,

                children: [

                  Text(

                    'Métodos de Pago',

                    style: TextStyle(

                      fontSize: R.fs(context, 26),

                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),

                  SizedBox(
                    height: R.sp(context, 30),
                  ),

                  SizedBox(

                    height: R.sp(context, 350),

                    child: BarChart(

                      BarChartData(

                        alignment:
                        BarChartAlignment
                            .spaceAround,

                        maxY:

                        [
                          efectivoTotal,
                          yappyTotal,
                          pendienteTotal
                        ].reduce(
                              (a, b) =>
                          a > b
                              ? a
                              : b,
                        ) +

                            20,

                        barGroups: [

                          BarChartGroupData(

                            x: 0,

                            barRods: [

                              BarChartRodData(

                                toY:
                                efectivoTotal,

                                width: 32,

                                borderRadius:
                                BorderRadius
                                    .circular(
                                  12,
                                ),

                                color:
                                Colors.green,
                              ),
                            ],
                          ),

                          BarChartGroupData(

                            x: 1,

                            barRods: [

                              BarChartRodData(

                                toY:
                                yappyTotal,

                                width: 32,

                                borderRadius:
                                BorderRadius
                                    .circular(
                                  12,
                                ),

                                color:
                                Colors.blue,
                              ),
                            ],
                          ),

                          BarChartGroupData(

                            x: 2,

                            barRods: [

                              BarChartRodData(

                                toY:
                                pendienteTotal,

                                width: 32,

                                borderRadius:
                                BorderRadius
                                    .circular(
                                  12,
                                ),

                                color:
                                Colors.red,
                              ),
                            ],
                          ),
                        ],
                        titlesData: FlTitlesData(

                          leftTitles: AxisTitles(

                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 60,
                              interval: 20,
                            ),
                          ),

                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: false,
                            ),
                          ),

                          topTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: false,
                            ),
                          ),

                          bottomTitles: AxisTitles(

                            sideTitles: SideTitles(

                              showTitles: true,

                              reservedSize: 35,

                              getTitlesWidget:
                                  (value, meta) {

                                switch (value.toInt()) {

                                  case 0:
                                    return const Text(
                                      'Efectivo',
                                    );

                                  case 1:
                                    return const Text(
                                      'Yappy',
                                    );

                                  case 2:
                                    return const Text(
                                      'Pendiente',
                                    );
                                }

                                return const Text('');
                              },
                            ),
                          ),
                        ),

                        borderData:
                        FlBorderData(
                          show: false,
                        ),

                        gridData:
                        const FlGridData(
                          show: false,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: R.sp(context, 30)),

            // =================================================
            // SALES LIST
            // =================================================

            Container(

              padding: EdgeInsets.all(
                R.sp(context, 24),
              ),

              decoration:
              BoxDecoration(

                color: Colors.white,

                borderRadius:
                BorderRadius.circular(
                  28,
                ),

                boxShadow: [

                  BoxShadow(

                    color: Colors.black
                        .withValues(alpha: 
                      0.05,
                    ),

                    blurRadius: 18,

                    offset:
                    const Offset(
                      0,
                      8,
                    ),
                  ),
                ],
              ),

              child: Column(

                crossAxisAlignment:
                CrossAxisAlignment
                    .start,

                children: [

                  Text(

                    'Últimas Ventas',

                    style: TextStyle(

                      fontSize: R.fs(context, 26),

                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),

                  SizedBox(
                    height: R.sp(context, 20),
                  ),

                  sales.isEmpty

                      ? Center(

                    child: Padding(

                      padding: EdgeInsets.all(
                        R.sp(context, 30),
                      ),

                      child: Text(

                        'No hay ventas',

                        style: TextStyle(
                          fontSize: R.fs(context, 18),
                        ),
                      ),
                    ),
                  )

                      : ListView.builder(

                    shrinkWrap: true,

                    physics:
                    const NeverScrollableScrollPhysics(),

                    itemCount:
                    sales.length,

                    itemBuilder:
                        (context,
                        index) {

                      final sale =
                      sales[index];

                      return Container(

                        margin: EdgeInsets.only(
                          bottom: R.sp(context, 16),
                        ),

                        padding: EdgeInsets.all(
                          R.sp(context, 20),
                        ),

                        decoration:
                        BoxDecoration(

                          color:
                          const Color(
                            0xFFF8F4FB,
                          ),

                          borderRadius:
                          BorderRadius.circular(
                            24,
                          ),
                        ),

                        child: Row(

                          children: [

                            Container(

                              padding: EdgeInsets.all(
                                R.sp(context, 14),
                              ),

                              decoration:
                              BoxDecoration(

                                color:
                                Colors.blue
                                    .shade100,

                                shape:
                                BoxShape.circle,
                              ),

                              child:
                              const Icon(

                                Icons.receipt_long,

                                color:
                                Colors.blue,
                              ),
                            ),

                            SizedBox(
                              width: R.sp(context, 18),
                            ),

                            Expanded(

                              child: Column(

                                crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,

                                children: [

                                  Text(

                                    sale['student'],

                                  style:
                                  TextStyle(

                                    fontSize: R.fs(context, 20),

                                    fontWeight:
                                    FontWeight.bold,
                                    ),
                                  ),

                                  SizedBox(
                                    height: R.sp(context, 4),
                                  ),

                                  Text(

                                    '${sale['product']} • ${sale['paymentMethod']}',

                                    style:
                                    const TextStyle(

                                      color:
                                      Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            Text(

                              '\$${(sale['total'] as num).toDouble().toStringAsFixed(2)}',

                              style:
                              TextStyle(

                                fontSize: R.fs(context, 22),

                                fontWeight:
                                FontWeight.bold,

                                color:
                                Colors.green,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
      );
    }
  Widget filterButton(
      String title,
      bool isSelected,
      VoidCallback onTap,
      ) {
    return GestureDetector(
      onTap: onTap,

      child: Container(
        margin: EdgeInsets.only(right: R.sp(context, 12)),

        padding: EdgeInsets.symmetric(
          horizontal: R.sp(context, 24),
          vertical: R.sp(context, 14),
        ),

        decoration: BoxDecoration(
          color:
          isSelected
              ? Colors.blue
              : Colors.white,

          borderRadius:
          BorderRadius.circular(18),
        ),

        child: Text(
          title,

          style: TextStyle(
            color:
            isSelected
                ? Colors.white
                : Colors.black,

            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
  // =====================================================
  // CARD
  // =====================================================

  Widget reportCard({

    required String title,

    required String value,

    required Color color,

    required IconData icon,

  }) {

    return Container(

      padding: EdgeInsets.all(R.sp(context, 24)),

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius:
        BorderRadius.circular(
          28,
        ),

        boxShadow: [

          BoxShadow(

            color:
            Colors.black.withValues(alpha: 
              0.05,
            ),

            blurRadius: 18,

            offset:
            const Offset(0, 8),
          ),
        ],
      ),

      child: Column(

        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [

          Container(

            padding: EdgeInsets.all(R.sp(context, 14)),

            decoration:
            BoxDecoration(

              color:
              color.withValues(alpha: 
                0.15,
              ),

              borderRadius:
              BorderRadius.circular(
                R.sp(context, 18),
              ),
            ),

            child: Icon(

              icon,

              color: color,

              size: R.sp(context, 30),
            ),
          ),

          SizedBox(height: R.sp(context, 24)),

          Text(

            value,

            style: TextStyle(

              fontSize: R.fs(context, 34),

              fontWeight:
              FontWeight.bold,

              color: color,
            ),
          ),

          SizedBox(height: R.sp(context, 8)),

          Text(

            title,

            style: TextStyle(

              fontSize: R.fs(context, 18),

              color:
              Colors.black54,
            ),
          ),
        ],
      ),
    );

  }
}