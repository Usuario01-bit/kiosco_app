import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../services/supabase_service.dart';
import '../services/date_utils.dart';
import '../services/responsive.dart';
import '../services/store_config.dart';

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

  List<Map<String, dynamic>> _allSales = [];

  StreamSubscription? _salesSub;

  // =====================================================
  // INIT
  // =====================================================

  @override
  void initState() {
    super.initState();
    _salesSub = SupabaseService.instance
        .streamSales()
        .listen((data) {
      _allSales = data;
      _computeReports();
    })
      ..onError((e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error en reportes: $e'), backgroundColor: Colors.red),
          );
        }
      });
  }

  @override
  void dispose() {
    _salesSub?.cancel();
    super.dispose();
  }

  void _computeReports() {
    var salesData = _allSales.where((sale) {
      final dateText = sale['date'] ?? '';
      final now = DateTime.now();

      if (selectedFilter == 'Hoy') {
        final todayStr =
            toISODate(now);
        return dateText == todayStr;
      }

      if (selectedFilter == 'Semana') {
        final weekAgo = DateTime.now()
            .subtract(const Duration(days: 6))
            .toIso8601String()
            .substring(0, 10);
        return dateText.compareTo(weekAgo) >= 0;
      }

      if (selectedFilter == 'Mes') {
        final monthStr =
            '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
        return dateText.startsWith(monthStr);
      }

      return true;
    }).toList();

    double total = 0;
    double efectivo = 0;
    double yappy = 0;
    double pendiente = 0;
    double r1 = 0;
    double r2 = 0;
    Map<String, int> productCounter = {};
    String bestProduct = 'Ninguno';
    int bestCount = 0;

    for (var sale in salesData) {
      String product = sale['product'] ?? '';
      if (product.isNotEmpty) {
        productCounter[product] = (productCounter[product] ?? 0) + 1;
        if (productCounter[product]! > bestCount) {
          bestCount = productCounter[product]!;
          bestProduct = product;
        }
      }

      final amount = (sale['total'] as num).toDouble();
      total += amount;

      if (sale['payment_method'] == 'Efectivo') {
        efectivo += amount;
      }
      if (sale['payment_method'] == 'Yappy') {
        yappy += amount;
      }
      if (sale['payment_method'] == 'Pendiente') {
        pendiente += amount;
        if (sale['recreo'] == 'Recreo 1') r1 += amount;
        if (sale['recreo'] == 'Recreo 2') r2 += amount;
      }
    }

    setState(() {
      this.sales = salesData;
      totalSales = total;
      efectivoTotal = efectivo;
      yappyTotal = yappy;
      pendienteTotal = pendiente;
      recreo1Total = r1;
      recreo2Total = r2;
      totalTransactions = salesData.length;
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
      Theme.of(context).scaffoldBackgroundColor,


      body: SingleChildScrollView(


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
                      _computeReports();
                    },
                  ),

                  filterButton(
                    'Semana',
                    selectedFilter == 'Semana',
                        () {
                      setState(() {
                        selectedFilter = 'Semana';
                      });
                      _computeReports();
                    },
                  ),

                  filterButton(
                    'Mes',
                    selectedFilter == 'Mes',
                        () {
                      setState(() {
                        selectedFilter = 'Mes';
                      });
                      _computeReports();
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
                Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),

            SizedBox(height: R.sp(context, 10)),

            Text(

              StoreConfig.instance.appSubtitle,

              style: TextStyle(

                fontSize: R.fs(context, 18),

                color:
                Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
              ),
            ),

            SizedBox(height: R.sp(context, 30)),

            // =================================================
            // TOP CARDS (responsive wrap)
            // =================================================

            Wrap(
              spacing: R.sp(context, 16),
              runSpacing: R.sp(context, 16),
              children: [
                _miniCard(
                  title: 'Ventas Totales',
                  value: '\$${totalSales.toStringAsFixed(2)}',
                  color: Colors.blue,
                  icon: Icons.attach_money,
                ),
                _miniCard(
                  title: 'Transacciones',
                  value: '$totalTransactions',
                  color: Colors.orange,
                  icon: Icons.receipt_long,
                ),
                _miniCard(
                  title: 'Pendientes',
                  value: '\$${pendienteTotal.toStringAsFixed(2)}',
                  color: Colors.red,
                  icon: Icons.warning_rounded,
                ),
                _miniCard(
                  title: 'Recreo 1',
                  value: '\$${recreo1Total.toStringAsFixed(2)}',
                  color: Colors.purple,
                  icon: Icons.schedule,
                ),
                _miniCard(
                  title: 'Recreo 2',
                  value: '\$${recreo2Total.toStringAsFixed(2)}',
                  color: Colors.teal,
                  icon: Icons.access_time_filled,
                ),
              ],
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

                color:
                Theme.of(context).cardColor,

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

                      color:
                      Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),

                  SizedBox(
                    height: R.sp(context, 30),
                  ),

                  SizedBox(

                    height: R.sp(context, 220),

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

            Container(

              padding: EdgeInsets.all(
                R.sp(context, 24),
              ),

              decoration:
              BoxDecoration(

                color:
                Theme.of(context).cardColor,

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

                      color:
                      Theme.of(context).textTheme.bodyLarge?.color,
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

                      : Column(
                    children: sales.map((sale) {
                      final isPending = (sale['payment_method'] ?? '')
                          .toString().toLowerCase().contains('pendiente');
                      return Container(
                        margin: EdgeInsets.only(
                          bottom: R.sp(context, 16),
                        ),
                        padding: EdgeInsets.all(
                          R.sp(context, 20),
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(R.sp(context, 14)),
                              decoration: BoxDecoration(
                                color: (isPending ? Colors.orange : Colors.green).withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isPending ? Icons.access_time : Icons.check,
                                color: isPending ? Colors.orange : Colors.green,
                              ),
                            ),
                            SizedBox(width: R.sp(context, 18)),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          sale['student']?.toString() ?? '',
                                          style: TextStyle(
                                            fontSize: R.fs(context, 20),
                                            fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isPending)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Text(
                                            'Pendiente',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.orange,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  SizedBox(height: R.sp(context, 4)),
                                  Text(
                                    '${sale['product'] ?? ''}',
                                    style: TextStyle(
                                      color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                                    ),
                                  ),
                                  Text(
                                    '${sale['date'] ?? ''} · ${formatTime(sale['time'])}',
                                    style: TextStyle(
                                      fontSize: R.fs(context, 12),
                                      color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.4),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '\$${((sale['total'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: R.fs(context, 22),
                                fontWeight: FontWeight.bold,
                                color: isPending
                                    ? Colors.orange
                                    : (Theme.of(context).brightness == Brightness.dark
                                        ? Colors.green.shade300
                                        : Colors.green),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
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
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).cardColor,

          borderRadius:
          BorderRadius.circular(18),
        ),

        child: Text(
          title,

          style: TextStyle(
            color:
            isSelected
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).textTheme.bodyLarge?.color,

            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
  // =====================================================
  // MINI CARD (compact, wrap-friendly)
  // =====================================================

  Widget _miniCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      width: (MediaQuery.of(context).size.width - R.sp(context, 48) - R.sp(context, 16)) / 2,
      padding: EdgeInsets.all(R.sp(context, 14)),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(R.sp(context, 8)),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: R.sp(context, 22)),
          ),
          SizedBox(width: R.sp(context, 10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: R.fs(context, 20),
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                SizedBox(height: R.sp(context, 2)),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: R.fs(context, 12),
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}