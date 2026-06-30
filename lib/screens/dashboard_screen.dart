import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/supabase_service.dart';
import '../services/date_utils.dart';
import '../services/responsive.dart';
import '../services/store_config.dart';

class DashboardScreen extends StatefulWidget {

  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() =>
  _DashboardScreenState();
}

class _DashboardScreenState
    extends State<DashboardScreen> {

  double totalSales = 0;
  double totalPending = 0;
  int totalProducts = 0;
  int totalSalesCount = 0;
  double todaySales = 0;
  String? topProduct;
  List<Map<String, dynamic>> recentSales = [];
  List<Map<String, dynamic>> weeklySales = [];
  List<Map<String, dynamic>> topProducts = [];
  bool isLoading = true;
  String? loadError;

  StreamSubscription? _salesSub;
  StreamSubscription? _pendingSub;
  StreamSubscription? _productsSub;

  @override
  void initState() {
    super.initState();
    _loadInitialSales();
    _salesSub = SupabaseService.instance
        .streamSales()
        .listen(_onSalesChanged)
      ..onError((e) => setState(() => loadError = e.toString()));
    _pendingSub = SupabaseService.instance
        .streamPendings()
        .listen((data) {
      double sum = 0;
      for (final doc in data) {
        final amount = (doc['amount'] as num?)?.toDouble() ?? 0;
        final paid = (doc['paid'] as num?)?.toDouble() ?? 0;
        sum += amount - paid;
      }
      setState(() {
        totalPending = sum;
        isLoading = false;
      });
    });
    _productsSub = SupabaseService.instance
        .streamProducts()
        .listen((data) {
      setState(() {
        totalProducts = data.length;
        isLoading = false;
      });
    }, onError: (_) {
      if (mounted) setState(() => isLoading = false);
    });
  }

  Future<void> _loadInitialSales() async {
    try {
      final sales = await SupabaseService.instance.getSales();
      if (mounted) _onSalesChanged(sales);
    } catch (_) {}
  }

  void _onSalesChanged(List<Map<String, dynamic>> sales) {
    final now = DateTime.now();
    final todayStr =
        toISODate(now);
    final weekAgo = now
        .subtract(const Duration(days: 6))
        .toIso8601String()
        .substring(0, 10);

    double totalSum = 0;
    double todaySum = 0;
    final Map<String, int> productCounts = {};
    final Map<String, double> productTotals = {};
    final Map<String, double> weeklyGrouped = {};

    for (final sale in sales) {
      final total = (sale['total'] as num?)?.toDouble() ?? 0;
      totalSum += total;

      final pm = (sale['payment_method'] as String? ?? '').toLowerCase();
      final date = sale['date'] as String? ?? '';

      if (!pm.contains('pendiente')) {
        if (date == todayStr) todaySum += total;
        if (date.compareTo(weekAgo) >= 0) {
          weeklyGrouped[date] = (weeklyGrouped[date] ?? 0) + total;
        }
      }

      final product = sale['product'] as String? ?? '';
      if (product.isNotEmpty) {
        final qty = (sale['quantity'] as num?)?.toInt() ?? 0;
        productCounts[product] = (productCounts[product] ?? 0) + qty;
        productTotals[product] = (productTotals[product] ?? 0) + total;
      }
    }

    final sortedWeekly = weeklyGrouped.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final sortedEntries = productTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topProductsList = sortedEntries
        .take(5)
        .map((e) => {'product': e.key, 'total': e.value})
        .toList();

    setState(() {
      totalSales = totalSum;
      todaySales = todaySum;
      totalSalesCount = sales.length;
      topProduct = productCounts.entries.isEmpty
          ? null
          : productCounts.entries
              .reduce((a, b) => a.value > b.value ? a : b)
              .key;
      recentSales = sales.take(20).toList();
      weeklySales = sortedWeekly
          .map((e) => {'date': e.key, 'total': e.value})
          .toList();
      topProducts = topProductsList;
      isLoading = false;
    });
  }

  @override
  void dispose() {
    _salesSub?.cancel();
    _pendingSub?.cancel();
    _productsSub?.cancel();
    super.dispose();
  }

  Widget buildCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {

    return Container(
      padding: EdgeInsets.all(R.sp(context, 20)),
      decoration: BoxDecoration(
        color:
        Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 
              0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment:
        MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                    fontSize: R.fs(context, 16),
                  ),
                ),
                SizedBox(height: R.sp(context, 10)),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: R.fs(context, 26),
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.all(R.sp(context, 14)),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 
                  0.12),
              borderRadius:
              BorderRadius.circular(R.sp(context, 18)),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: R.sp(context, 30),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    if (isLoading) {

      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (loadError != null) {

      return Scaffold(
        appBar: AppBar(
          title: Text(StoreConfig.instance.storeName),
          foregroundColor: Colors.white,
          elevation: 0,
          backgroundColor: const Color(0xFF4A90E2),
        ),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(R.sp(context, 32)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  LucideIcons.cloudOff,
                  size: R.sp(context, 64),
                  color: Theme.of(context).disabledColor,
                ),
                SizedBox(height: R.sp(context, 16)),
                Text(
                  'Error al cargar datos',
                  style: TextStyle(
                    fontSize: R.fs(context, 20),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: R.sp(context, 8)),
                Text(
                  'Verificá tu conexión a internet',
                  style: TextStyle(
                    fontSize: R.fs(context, 14),
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                  ),
                ),
                SizedBox(height: R.sp(context, 24)),
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(LucideIcons.refreshCw),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    return Scaffold(
      backgroundColor:
      Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/logos/logo oficial.png', height: 32),
            const SizedBox(width: 8),
            Expanded(child: Text(StoreConfig.instance.storeName)),
          ],
        ),
        foregroundColor: Colors.white,
        elevation: 0,
        backgroundColor: const Color(
            0xFF4A90E2),
        actions: const [],
      ),
      body: SingleChildScrollView(
          padding: EdgeInsets.all(R.sp(context, 20)),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Panel de ventas',
                    style: TextStyle(
                      fontSize: R.fs(context, 34),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration:
                    BoxDecoration(
                      color:
                      Theme.of(
                        context,
                      ).cardColor,
                      borderRadius:
                      BorderRadius
                          .circular(16),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).dividerColor,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: Theme.of(
                            context,
                          ).primaryColor,
                        ),
                        const SizedBox(
                            width: 6),
                        Text(
                          dateStr,
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(
                              context,
                            ).textTheme
                                .bodyMedium
                                ?.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: R.sp(context, 8)),
              Text(
                StoreConfig.instance.appSubtitle,
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).textTheme.bodyMedium
                      ?.color
                      ?.withValues(alpha: 0.7),
                  fontSize: R.fs(context, 16),
                ),
              ),
              SizedBox(height: R.sp(context, 25)),
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                shrinkWrap: true,
                physics:
                const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.25,
                children: [
                  buildCard(
                    title: 'Ventas totales',
                    value:
                    '\$${totalSales.toStringAsFixed(2)}',
                    icon: Icons.point_of_sale,
                    iconColor: Colors.blue,
                  ),
                  buildCard(
                    title: 'Ventas hoy',
                    value:
                    '\$${todaySales.toStringAsFixed(2)}',
                    icon: Icons.today,
                    iconColor: Colors.green,
                  ),
                  buildCard(
                    title: 'Pendientes',
                    value:
                    '\$${totalPending.toStringAsFixed(2)}',
                    icon: Icons
                        .pending_actions,
                    iconColor: Colors.orange,
                  ),
                  buildCard(
                    title: 'Productos',
                    value: totalProducts
                        .toString(),
                    icon: Icons.inventory,
                    iconColor: Colors.purple,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              buildWeeklyChart(),
              const SizedBox(height: 20),
              buildTopProductsChart(),
              const SizedBox(height: 20),
              if (topProduct != null)
                buildTopProductCard(),
              const SizedBox(height: 20),
              buildRecentSalesCard(),
            ],
          ),
        ),
    );
  }

  Widget buildWeeklyChart() {

    if (weeklySales.isEmpty) return const SizedBox.shrink();

    final maxY = weeklySales.fold<double>(
      0,
      (max, s) {
        final val =
            (s['total'] as num?)?.toDouble() ?? 0;
        return val > max ? val : max;
      },
    );

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Text(
          'Ventas semanales',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(
              context,
            ).textTheme.bodyLarge?.color,
          ),
        ),
        SizedBox(height: R.sp(context, 12)),
        Container(
          height: R.sp(context, 200),
          width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                  R.sp(context, 12), R.sp(context, 20), R.sp(context, 12), 0),
              decoration: BoxDecoration(
                color:
                Theme.of(context).cardColor,
                borderRadius:
                BorderRadius.circular(R.sp(context, 24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: BarChart(
            BarChartData(
              alignment:
              BarChartAlignment
                  .spaceAround,
              maxY: maxY * 1.3,
              barGroups: List.generate(
                weeklySales.length,
                (i) {
                  final total =
                      (weeklySales[i]['total']
                          as num?)
                              ?.toDouble() ??
                          0;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: total,
                        color: const Color(
                            0xFF4A90E2),
                        width: 18,
                        borderRadius:
                        const BorderRadius
                            .vertical(
                          top: Radius
                              .circular(
                              6),
                        ),
                      ),
                    ],
                  );
                },
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget:
                        (value, meta) {
                      final idx =
                          value.toInt();
                      if (idx < 0 ||
                          idx >=
                              weeklySales
                                  .length) {
                        return const SizedBox
                            .shrink();
                      }
                      final date =
                          weeklySales[idx]
                                  ['date']
                              as String? ??
                          '';
                      final day =
                          date.length >= 10
                              ? date.substring(
                                  8, 10)
                              : date;
                      return Padding(
                        padding: const EdgeInsets
                            .only(
                            top: 8),
                        child: Text(
                          day,
                          style: const TextStyle(
                              fontSize: 12),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 60,
                    getTitlesWidget:
                        (value, meta) {
                      final num = value.toInt();
                      String label;
                      if (num >= 1000) {
                        label = '\$${(num / 1000).toStringAsFixed(1)}K';
                      } else {
                        label = '\$$num';
                      }
                      return Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Text(
                          label,
                          style: const TextStyle(
                              fontSize: 10),
                          textAlign: TextAlign.right,
                        ),
                      );
                    },
                  ),
                ),
                topTitles: AxisTitles(
                  sideTitles: SideTitles(
                      showTitles: false),
                ),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(
                      showTitles: false),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval:
                maxY > 0
                    ? maxY / 4
                    : 1,
              ),
              borderData:
              FlBorderData(show: false),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildTopProductsChart() {

    if (topProducts.isEmpty) {
      return const SizedBox.shrink();
    }

    final total = topProducts.fold<double>(
      0,
      (sum, p) =>
          sum +
              ((p['total'] as num?)
                      ?.toDouble() ??
                  0),
    );

    final colors = [
      const Color(0xFF4A90E2),
      const Color(0xFF50C878),
      const Color(0xFFFFA500),
      const Color(0xFF9B59B6),
      const Color(0xFFE74C3C),
    ];

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Text(
          'Productos más vendidos',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(
              context,
            ).textTheme.bodyLarge?.color,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color:
            Theme.of(context).cardColor,
            borderRadius:
            BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding:
            const EdgeInsets.all(20),
            child: Column(
              children: [
                SizedBox(
                  height: 160,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections:
                          List.generate(
                        topProducts
                            .length,
                        (i) {
                          final value =
                              (topProducts[i]
                                      ['total']
                                  as num?)
                                      ?.toDouble() ??
                                  0;
                          return PieChartSectionData(
                            color: colors[
                                i %
                                    colors
                                        .length],
                            value: total > 0
                                ? value /
                                    total *
                                    100
                                : 0,
                            title: total > 0
                                ? '${(value / total * 100).toStringAsFixed(0)}%'
                                : '0%',
                            radius: 28,
                            titleStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight:
                              FontWeight
                                  .bold,
                              color: Colors
                                  .white,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children:
                      List.generate(
                    topProducts
                        .length,
                    (i) {
                      final name =
                          topProducts[i]
                                  ['product']
                              as String? ??
                          '';
                      return Row(
                        mainAxisSize:
                        MainAxisSize
                            .min,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration:
                            BoxDecoration(
                              color: colors[
                                  i %
                                      colors
                                          .length],
                              borderRadius:
                              BorderRadius
                                  .circular(
                                  3),
                            ),
                          ),
                          const SizedBox(
                              width: 6),
                          Text(
                            name,
                            style: const TextStyle(
                                fontSize:
                                    13),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget buildTopProductCard() {

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(
            24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 
                0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
              Colors.purple.withValues(alpha: 
                  0.12),
              borderRadius:
              BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.emoji_events,
              color: Colors.purple,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  'Producto top',
                  style: TextStyle(
                    color:
                    Theme.of(
                      context,
                    ).textTheme
                        .bodyMedium
                        ?.color
                        ?.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  topProduct!,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight:
                    FontWeight.bold,
                    color:
                    Theme.of(
                      context,
                    ).textTheme
                        .bodyLarge
                        ?.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildRecentSalesCard() {

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Text(
          'Últimas ventas',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(
              context,
            ).textTheme.bodyLarge?.color,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(
                24),
            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: recentSales.isEmpty
              ? Padding(
            padding: const EdgeInsets
                .all(20),
            child: Text(
              'Sin ventas registradas',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                fontSize: 15,
              ),
            ),
          )
              : ListView.separated(
            shrinkWrap: true,
            physics:
            const NeverScrollableScrollPhysics(),
            itemCount: recentSales.length,
            separatorBuilder:
                (_, __) =>
                const Divider(
              height: 1,
            ),
            itemBuilder:
                (context, index) {

              final sale =
              recentSales[index];

              final isPending =
              (sale['payment_method']
                      ?.toString() ??
                  '')
                  .toLowerCase()
                  .contains('pendiente');

              return ListTile(
                dense: true,
                contentPadding:
                const EdgeInsets
                    .symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                leading: CircleAvatar(
                  radius: 20,
                  backgroundColor:
                  (isPending ? Colors.orange
                      : Colors
                      .green)
                      .withValues(alpha: 0.15),
                  child: Icon(
                    isPending
                        ? Icons
                        .access_time
                        : Icons
                        .check,
                    color:
                    isPending
                        ? Colors.orange
                        : Colors
                        .green,
                    size: 18,
                  ),
                ),
                title: Text(
                  sale['product']?.toString() ??
                      'Producto',
                  style:
                  const TextStyle(
                    fontSize: 15,
                  ),
                ),
                subtitle: Text(
                  '${sale['date'] ?? ''} · ${formatTime(sale['time'])}',
                  style: const TextStyle(
                    fontSize: 12,
                  ),
                ),
                trailing: Text(
                  '\$${((sale['total'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight:
                    FontWeight.bold,
                    color:
                    isPending
                        ? Colors.orange
                        : Colors
                        .green,
                    fontSize: 15,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
