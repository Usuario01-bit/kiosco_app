import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../services/database_helper.dart';

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
    await DatabaseHelper.instance
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

          print(bestProduct);
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


        padding:
        const EdgeInsets.all(24),

        child: Column(

          crossAxisAlignment:
          CrossAxisAlignment.start,

          children: [
            SizedBox(
              height: 50,

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
            const SizedBox(height: 20),

            // =================================================
            // TITLE
            // =================================================

            const Text(

              'Reportes',

              style: TextStyle(

                fontSize: 38,

                fontWeight:
                FontWeight.bold,

                color:
                Color(0xFF1E1E2D),
              ),
            ),

            const SizedBox(height: 10),

            const Text(

              'Resumen general del kiosco',

              style: TextStyle(

                fontSize: 18,

                color:
                Colors.black54,
              ),
            ),

            const SizedBox(height: 30),

            // =================================================
            // TOP CARDS
            // =================================================

            Row(

              children: [

                Expanded(

                  child: reportCard(

                    title:
                    'Ventas Totales',

                    value:
                    '\$${totalSales.toStringAsFixed(2)}',

                    color:
                    Colors.blue,

                    icon:
                    Icons.attach_money,
                  ),
                ),

                const SizedBox(width: 30),

                Expanded(

                  child: reportCard(

                    title:
                    'Transacciones',

                    value:
                    '$totalTransactions',

                    color:
                    Colors.orange,

                    icon:
                    Icons.receipt_long,
                  ),
                ),

                const SizedBox(width: 20),

                Expanded(

                  child: reportCard(

                    title:
                    'Pendientes',

                    value:
                    '\$${pendienteTotal.toStringAsFixed(2)}',

                    color:
                    Colors.red,

                    icon:
                    Icons.warning_rounded,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),
            const SizedBox(height: 30),

            Row(

              children: [

                Expanded(

                  child: reportCard(

                    title:
                    'Recreo 1',

                    value:
                    '\$${recreo1Total.toStringAsFixed(2)}',

                    color:
                    Colors.purple,

                    icon:
                    Icons.schedule,
                  ),
                ),

                const SizedBox(width: 20),

                Expanded(

                  child: reportCard(

                    title:
                    'Recreo 2',

                    value:
                    '\$${recreo2Total.toStringAsFixed(2)}',

                    color:
                    Colors.teal,

                    icon:
                    Icons.access_time_filled,
                  ),
                ),
              ],
            ),

            // =================================================
            // CHART
            // =================================================

            Container(

              padding:
              const EdgeInsets.all(
                24,
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

                  const Text(

                    'Métodos de Pago',

                    style: TextStyle(

                      fontSize: 26,

                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    height: 30,
                  ),

                  SizedBox(

                    height: 350,

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

            const SizedBox(height: 30),

            // =================================================
            // SALES LIST
            // =================================================

            Container(

              padding:
              const EdgeInsets.all(
                24,
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

                  const Text(

                    'Últimas Ventas',

                    style: TextStyle(

                      fontSize: 26,

                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  sales.isEmpty

                      ? const Center(

                    child: Padding(

                      padding:
                      EdgeInsets.all(
                        30,
                      ),

                      child: Text(

                        'No hay ventas',

                        style: TextStyle(
                          fontSize: 18,
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

                        margin:
                        const EdgeInsets.only(
                          bottom: 16,
                        ),

                        padding:
                        const EdgeInsets.all(
                          20,
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

                              padding:
                              const EdgeInsets.all(
                                14,
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

                            const SizedBox(
                              width: 18,
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
                                    const TextStyle(

                                      fontSize:
                                      20,

                                      fontWeight:
                                      FontWeight.bold,
                                    ),
                                  ),

                                  const SizedBox(
                                    height:
                                    4,
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
                              const TextStyle(

                                fontSize:
                                22,

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
        margin: const EdgeInsets.only(right: 12),

        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 14,
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

      padding:
      const EdgeInsets.all(24),

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

            padding:
            const EdgeInsets.all(14),

            decoration:
            BoxDecoration(

              color:
              color.withValues(alpha: 
                0.15,
              ),

              borderRadius:
              BorderRadius.circular(
                18,
              ),
            ),

            child: Icon(

              icon,

              color: color,

              size: 30,
            ),
          ),

          const SizedBox(height: 24),

          Text(

            value,

            style: TextStyle(

              fontSize: 34,

              fontWeight:
              FontWeight.bold,

              color: color,
            ),
          ),

          const SizedBox(height: 8),

          Text(

            title,

            style: const TextStyle(

              fontSize: 18,

              color:
              Colors.black54,
            ),
          ),
        ],
      ),
    );

  }
}