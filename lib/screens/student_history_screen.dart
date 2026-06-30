import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';

import '../services/supabase_service.dart';
import '../services/date_utils.dart';

class StudentHistoryScreen extends StatefulWidget {
  final Map<String, dynamic> student;

  const StudentHistoryScreen({super.key, required this.student});

  @override
  State<StudentHistoryScreen> createState() => _StudentHistoryScreenState();
}

class _StudentHistoryScreenState extends State<StudentHistoryScreen> {
  final SupabaseService _supabase = SupabaseService.instance;
  List<Map<String, dynamic>> sales = [];
  double debt = 0;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final results = await Future.wait([
        _supabase.getSalesByStudent(widget.student['name'] as String),
        _supabase.getStudentDebt(widget.student['name'] as String),
      ]);
      if (!mounted) return;
      setState(() {
        sales = results[0] as List<Map<String, dynamic>>;
        debt = results[1] as double;
        loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    if (raw.contains('-')) {
      final parts = raw.split('-');
      if (parts.length == 3) return '${parts[2]}/${parts[1]}/${parts[0]}';
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final todaySales = sales.where((s) {
      final now = DateTime.now();
      final today = toISODate(now);
      return s['date'] == today;
    }).toList();
    final todayTotal = todaySales.fold<double>(0, (sum, s) => sum + ((s['total'] as num?)?.toDouble() ?? 0));
    final isPendiente = (s) => (s['paymentMethod'] as String? ?? '').toLowerCase().contains('pendiente');

    return Scaffold(
      appBar: AppBar(title: const Text('Mis compras')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: cs.primary.withValues(alpha: 0.12),
                                child: Icon(LucideIcons.user, color: cs.primary),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.student['name'] as String,
                                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      (widget.student['grade'] ?? widget.student['grado']) as String? ?? '',
                                      style: TextStyle(color: cs.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  children: [
                                    Text(
                                      '\$${debt.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: debt > 0 ? cs.tertiary : Colors.green,
                                      ),
                                    ),
                                    Text('Saldo pendiente', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                                  ],
                                ),
                              ),
                              Container(width: 1, height: 40, color: cs.outlineVariant),
                              Expanded(
                                child: Column(
                                  children: [
                                    Text(
                                      '\$${todayTotal.toStringAsFixed(2)}',
                                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: cs.primary),
                                    ),
                                    Text('Hoy', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    debt > 0
                        ? 'Tenés \$${debt.toStringAsFixed(2)} pendiente — acercate al kiosco para saldarlo'
                        : 'No tenés deudas pendientes',
                    style: TextStyle(
                      fontSize: 14,
                      color: debt > 0 ? cs.tertiary : Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Historial de compras', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (sales.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text('No tenés compras registradas', style: TextStyle(color: cs.onSurfaceVariant)),
                      ),
                    )
                  else
                    ...sales.map((sale) {
                      final pendiente = isPendiente(sale);
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor: pendiente ? cs.tertiaryContainer.withValues(alpha: 0.4) : Colors.green.withValues(alpha: 0.12),
                            child: Icon(
                              pendiente ? LucideIcons.clock : LucideIcons.checkCircle,
                              color: pendiente ? cs.tertiary : Colors.green,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            '${sale['product']} x${sale['quantity']}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${_formatDate(sale['date'] as String?)} — ${sale['recreo'] ?? 'Sin recreo'}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '\$${((sale['total'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: pendiente ? cs.tertiary : cs.primary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: pendiente
                                      ? Colors.orange.withValues(alpha: 0.15)
                                      : Colors.green.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  sale['paymentMethod'] as String? ?? '',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: pendiente ? Colors.orange.shade800 : Colors.green.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}
