import 'package:flutter/material.dart';

import '../services/supabase_service.dart';
import '../services/product_icons.dart' show productIcons, resolveProductIcon;

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  List<Map<String, dynamic>> allSales = [];

  @override
  void initState() {
    super.initState();
    SupabaseService.instance.streamTodaySales().listen((data) {
      if (mounted) setState(() => allSales = data);
    });
  }

  List<Map<String, dynamic>> get _activeSales =>
      allSales.where((s) => s['prepared_at'] == null && s['paid_at'] == null).toList();

  Set<String> get recreos => _activeSales.map((s) => s['recreo'] as String? ?? 'Sin recreo').toSet();

  List<Map<String, dynamic>> salesForRecreo(String recreo) =>
      _activeSales.where((s) => (s['recreo'] as String? ?? 'Sin recreo') == recreo).toList();

  Set<String> studentsInRecreo(String recreo) =>
      salesForRecreo(recreo).map((s) => s['student'] as String? ?? '').where((n) => n.isNotEmpty).toSet();

  List<Map<String, dynamic>> studentSales(String recreo, String student) =>
      salesForRecreo(recreo).where((s) => s['student'] == student).toList();

  double studentTotal(String recreo, String student) =>
      studentSales(recreo, student).fold<double>(0, (sum, s) => sum + ((s['total'] as num?)?.toDouble() ?? 0));

  bool studentIsReady(String recreo, String student) =>
      studentSales(recreo, student).every((s) => s['prepared_at'] != null);

  IconData _iconFor(String? iconName) {
    if (iconName != null && productIcons.containsKey(iconName)) return productIcons[iconName]!;
    return Icons.shopping_bag;
  }

  void _showPaymentOptions(String student, String recreo, double total) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text(student, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(recreo, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            Text('\$${total.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
            const SizedBox(height: 24),
            const Text('¿Cómo pagó?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _markAsPaid(student, recreo, 'Efectivo');
                },
                icon: const Icon(Icons.money),
                label: const Text('Efectivo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _markAsPaid(student, recreo, 'Yappy');
                },
                icon: const Icon(Icons.phone_android),
                label: const Text('Yappy'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _markAsPreparedOnly(student, recreo);
                },
                icon: const Icon(Icons.pending),
                label: const Text('Pendiente (fiado)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Future<void> _markAsPaid(String student, String recreo, String paymentMethod) async {
    await SupabaseService.instance.markStudentRecreoAsPaid(student, recreo, paymentMethod);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$student — $recreo — Pagó con $paymentMethod'), backgroundColor: Colors.green),
    );
  }

  Future<void> _markAsPreparedOnly(String student, String recreo) async {
    await SupabaseService.instance.markStudentRecreoAsPrepared(student, recreo);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$student — $recreo marcado como listo (pendiente)'), backgroundColor: Colors.orange),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final styles = Theme.of(context).textTheme;
    final orderedRecreos = ['Recreo 1', 'Recreo 2', 'Salida'];
    final presentRecreos = orderedRecreos.where((r) => recreos.contains(r)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pedidos del día'),
        actions: [
          if (presentRecreos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '${_activeSales.length} productos',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
              ),
            ),
        ],
      ),
      body: _activeSales.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 72, color: Colors.green.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text('Todos los pedidos están pagos', style: styles.titleLarge?.copyWith(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Text('No hay pedidos pendientes por hoy',
                      style: styles.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                for (final recreo in orderedRecreos)
                  if (recreos.contains(recreo)) _buildRecreoSection(context, cs, styles, recreo),
              ],
            ),
    );
  }

  Widget _buildRecreoSection(BuildContext context, ColorScheme cs, TextTheme styles, String recreo) {
    final students = studentsInRecreo(recreo);
    final totalOrders = salesForRecreo(recreo).length;
    final readyCount = salesForRecreo(recreo).where((s) => s['prepared_at'] != null).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 20, bottom: 8),
          child: Row(
            children: [
              Text(recreo, style: styles.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: readyCount == totalOrders ? Colors.green.withValues(alpha: 0.15) : cs.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$readyCount/$totalOrders',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: readyCount == totalOrders ? Colors.green : cs.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        for (final student in students) _buildStudentCard(context, cs, styles, recreo, student),
      ],
    );
  }

  Widget _buildStudentCard(BuildContext context, ColorScheme cs, TextTheme styles, String recreo, String student) {
    final sales = studentSales(recreo, student);
    final total = studentTotal(recreo, student);
    final allPrepared = studentIsReady(recreo, student);
    final anyPrepared = sales.any((s) => s['prepared_at'] != null);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: allPrepared
                  ? Colors.green.withValues(alpha: 0.08)
                  : cs.primaryContainer.withValues(alpha: 0.15),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: allPrepared ? Colors.green.withValues(alpha: 0.2) : cs.primary.withValues(alpha: 0.12),
                  child: Icon(
                    allPrepared ? Icons.check_circle : Icons.person,
                    color: allPrepared ? Colors.green : cs.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(student, style: styles.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text('$total producto${sales.length != 1 ? 's' : ''}',
                              style: styles.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                          ..._paymentBadges(cs, sales),
                        ],
                      ),
                    ],
                  ),
                ),
                Text('\$${total.toStringAsFixed(2)}',
                    style: styles.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: cs.primary)),
              ],
            ),
          ),
          ...sales.map((sale) => _buildProductRow(context, cs, styles, sale)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () => _showPaymentOptions(student, recreo, total),
                icon: Icon(allPrepared ? Icons.payment : Icons.check_circle_outline, size: 18),
                label: Text(allPrepared ? 'Cobrar / Finalizar' : 'Entregar y cobrar'),
                style: FilledButton.styleFrom(
                  backgroundColor: allPrepared ? cs.primaryContainer : null,
                  foregroundColor: allPrepared ? cs.onPrimaryContainer : null,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _paymentBadges(ColorScheme cs, List<Map<String, dynamic>> sales) {
    final methods = sales
        .map((s) => (s['payment_method'] as String? ?? '').trim())
        .where((m) => m.isNotEmpty)
        .toSet();
    if (methods.isEmpty) return [];
    return methods.take(3).map((method) {
      final (Color bg, Color fg) = switch (method.toLowerCase()) {
        'efectivo' => (Colors.green.withValues(alpha: 0.15), Colors.green.shade800),
        'yappy' => (Colors.blue.withValues(alpha: 0.15), Colors.blue.shade800),
        _ => (Colors.orange.withValues(alpha: 0.15), Colors.orange.shade800),
      };
      return Padding(
        padding: const EdgeInsets.only(left: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
          child: Text(method, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg)),
        ),
      );
    }).toList();
  }

  Widget _buildProductRow(BuildContext context, ColorScheme cs, TextTheme styles, Map<String, dynamic> sale) {
    final prepared = sale['prepared_at'] != null;
    final pendiente = (sale['payment_method'] as String? ?? '').toLowerCase().contains('pendiente');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(_iconFor(sale['icon'] as String?), size: 22, color: cs.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${sale['product']} x${sale['quantity']}',
                    style: styles.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                if (sale['time'] != null)
                  Text(sale['time'] as String,
                      style: styles.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('\$${((sale['total'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}',
                  style: styles.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
              if (sale['payment_method'] != null && (sale['payment_method'] as String).isNotEmpty)
                Text(sale['payment_method'] as String,
                    style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
              if (prepared && pendiente)
                Text('Listo', style: TextStyle(fontSize: 11, color: Colors.orange)),
            ],
          ),
          const SizedBox(width: 8),
          Icon(
            prepared ? Icons.check_circle : Icons.access_time,
            size: 18,
            color: prepared ? Colors.green : cs.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}
