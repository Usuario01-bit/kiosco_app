import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';

import '../services/supabase_service.dart';
import 'student_qr_scanner_screen.dart';

class StudentQrDetailScreen extends StatefulWidget {
  final Map<String, dynamic> student;

  const StudentQrDetailScreen({super.key, required this.student});

  @override
  State<StudentQrDetailScreen> createState() => _StudentQrDetailScreenState();
}

class _StudentQrDetailScreenState extends State<StudentQrDetailScreen> {
  final SupabaseService _supabase = SupabaseService.instance;
  List<Map<String, dynamic>> todaySales = [];
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
      final studentName = widget.student['name'] as String;
      final results = await Future.wait([
        _supabase.getTodaySalesByStudent(studentName),
        _supabase.getStudentDebt(studentName),
      ]);
      if (!mounted) return;
      setState(() {
        todaySales = results[0] as List<Map<String, dynamic>>;
        debt = results[1] as double;
        loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  double get todayTotal => todaySales.fold<double>(0, (s, sale) => s + ((sale['total'] as num?)?.toDouble() ?? 0));

  Map<String, List<Map<String, dynamic>>> get salesByRecreo {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final sale in todaySales) {
      final recreo = sale['recreo'] as String? ?? 'Sin recreo';
      map.putIfAbsent(recreo, () => []).add(sale);
    }
    return map;
  }

  String _timeAgo(String? time) {
    if (time == null || time.isEmpty) return '';
    return time;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.student['name'] as String),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.qrCode_scanner),
            tooltip: 'Escanear otro',
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const StudentQrScannerScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: _load,
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 36,
                            backgroundColor: cs.primary.withValues(alpha: 0.12),
                            child: Icon(LucideIcons.user, size: 36, color: cs.primary),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.student['name'] as String,
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          if ((widget.student['grade'] ?? widget.student['grado']) != null && ((widget.student['grade'] ?? widget.student['grado']) as String).trim().isNotEmpty)
                            Text(
                              (widget.student['grade'] ?? widget.student['grado']) as String,
                              style: TextStyle(fontSize: 16, color: cs.onSurfaceVariant),
                            ),
                          const Divider(height: 28),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  children: [
                                    Text(
                                      '\$${todayTotal.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: cs.primary,
                                      ),
                                    ),
                                    Text('Hoy', style: TextStyle(color: cs.onSurfaceVariant)),
                                  ],
                                ),
                              ),
                              Container(width: 1, height: 40, color: cs.outlineVariant),
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
                                    Text('Debe', style: TextStyle(color: cs.onSurfaceVariant)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  if (debt > 0)
                    Container(
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: cs.tertiaryContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: cs.tertiary.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          Icon(LucideIcons.triangleAlert, color: cs.tertiary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Debe \$${debt.toStringAsFixed(2)} — recordá cobrarle antes de entregar',
                              style: TextStyle(color: cs.tertiary, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const Text('Pedidos de hoy', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),

                  if (todaySales.isEmpty)
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(child: Text('Sin pedidos hoy', style: TextStyle(color: cs.onSurfaceVariant))),
                      ),
                    )
                  else
                    ...salesByRecreo.entries.map((entry) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 4, top: 12, bottom: 6),
                            child: Text(
                              entry.key,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: cs.primary,
                              ),
                            ),
                          ),
                          ...entry.value.map((sale) {
                            final pendiente = (sale['paymentMethod'] as String? ?? '').toLowerCase().contains('pendiente');
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 3),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: ListTile(
                                leading: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: pendiente ? cs.tertiaryContainer.withValues(alpha: 0.4) : Colors.green.withValues(alpha: 0.12),
                                  child: Icon(
                                    pendiente ? LucideIcons.clock : LucideLucideIcons.checkCircle,
                                    color: pendiente ? cs.tertiary : Colors.green,
                                    size: 18,
                                  ),
                                ),
                                title: Text('${sale['product']} x${sale['quantity']}'),
                                subtitle: Text(_timeAgo(sale['time'] as String?)),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '\$${((sale['total'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: pendiente ? cs.tertiary : cs.primary,
                                      ),
                                    ),
                                    if (pendiente)
                                      Text('Pendiente', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: cs.tertiary)),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      );
                    }),
                ],
              ),
            ),
    );
  }
}
