import 'package:flutter/material.dart';

import '../services/supabase_service.dart';
import '../services/date_utils.dart';
import '../services/recreo_schedule.dart';
import 'student_catalog_screen.dart';

class StudentCheckoutScreen extends StatefulWidget {
  final Map<String, dynamic> student;
  final List<Map<String, dynamic>> cartItems;

  const StudentCheckoutScreen({
    super.key,
    required this.student,
    required this.cartItems,
  });

  @override
  State<StudentCheckoutScreen> createState() => _StudentCheckoutScreenState();
}

class _StudentCheckoutScreenState extends State<StudentCheckoutScreen> {
  final SupabaseService _supabase = SupabaseService.instance;
  bool loading = false;
  String? selectedRecreo;
  double _debt = 0;
  String paymentMethod = 'Pendiente';

  @override
  void initState() {
    super.initState();
    _loadDebt();
  }

  Future<void> _loadDebt() async {
    final debt = await _supabase.getStudentDebt(widget.student['name'] as String);
    if (mounted) setState(() => _debt = debt);
  }

  double get total {
    double t = 0;
    for (final item in widget.cartItems) {
      final product = item['product'] as Map<String, dynamic>;
      final qty = item['quantity'] as int;
      t += (product['price'] as num).toDouble() * qty;
    }
    return t;
  }

  bool get allLocked => RecreoSchedule.windows.every((w) => w.isLocked(DateTime.now()));

  Future<void> _confirm() async {
    if (loading) return;
    if (selectedRecreo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccioná un recreo o salida')),
      );
      return;
    }

    final now = DateTime.now();
    final selected = RecreoSchedule.windows.firstWhere((w) => w.name == selectedRecreo);
    if (selected.isLocked(now)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('El kiosco ya está preparando pedidos para $selectedRecreo, no se pueden recibir más'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final date = toISODate(now);
      final time = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      await _supabase.checkoutStudentOrder(
        student: widget.student,
        cartItems: widget.cartItems,
        recreo: selectedRecreo!,
        paymentMethod: paymentMethod,
        date: date,
        time: time,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pedido registrado'), backgroundColor: Colors.green),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => StudentCatalogScreen(student: widget.student),
        ),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final styles = Theme.of(context).textTheme;
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: const Text('Confirmar pedido')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 24),
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: cs.primary.withValues(alpha: 0.12),
                        child: Icon(Icons.person, color: cs.primary),
                      ),
                      const SizedBox(width: 12),
                      Text(widget.student['name'] as String, style: styles.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  if (_debt > 0) ...[
                    const Divider(),
                    Row(
                      children: [
                        const Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Debés \$${_debt.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Productos', style: styles.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...widget.cartItems.map((item) {
            final product = item['product'] as Map<String, dynamic>;
            final qty = item['quantity'] as int;
            final price = (product['price'] as num).toDouble();
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                title: Text(product['name'] as String),
                trailing: Text('$qty x \$${price.toStringAsFixed(2)} = \$${(price * qty).toStringAsFixed(2)}'),
              ),
            );
          }),
          const Divider(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text(
                '\$${total.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: cs.primary),
              ),
            ],
          ),
          if (_debt > 0) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Deuda anterior:', style: TextStyle(color: cs.onSurfaceVariant)),
                Text('-\$${_debt.toStringAsFixed(2)}', style: TextStyle(color: cs.onSurfaceVariant)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total con deuda:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                Text(
                  '\$${(_debt + total).toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.tertiary),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          Text('¿Cuándo lo retirás?', style: styles.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),

          if (allLocked)
            _buildAllLocked(cs, styles)
          else
            ...RecreoSchedule.windows.map((w) {
              final isSelected = selectedRecreo == w.name;
              final locked = w.isLocked(now);
              final open = w.isOpen(now);

              IconData icon;
              Color iconColor;
              String status;

              if (open) {
                icon = Icons.check_circle;
                iconColor = Colors.green;
                status = 'Abierto ahora';
              } else if (locked) {
                icon = Icons.timer_off;
                iconColor = cs.onSurfaceVariant;
                status = 'En preparación — no se reciben más pedidos';
              } else {
                icon = Icons.schedule;
                iconColor = cs.primary;
                status = 'Disponible';
              }

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: isSelected ? BorderSide(color: cs.primary, width: 2) : BorderSide.none,
                ),
                color: isSelected ? cs.primary.withValues(alpha: 0.08) : null,
                child: RadioListTile<String>(
                  title: Text(w.name, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                  subtitle: Row(
                    children: [
                      Icon(icon, size: 16, color: iconColor),
                      const SizedBox(width: 6),
                      Text(status, style: TextStyle(color: iconColor, fontSize: 12)),
                    ],
                  ),
                  value: w.name,
                  groupValue: selectedRecreo,
                  onChanged: locked ? null : (v) => setState(() => selectedRecreo = v),
                ),
              );
            }),

          const SizedBox(height: 24),
          Text('¿Cómo vas a pagar?', style: styles.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildPaymentOption(Icons.money, 'Efectivo', Colors.green),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildPaymentOption(Icons.phone_android, 'Yappy', const Color(0xFF7C3AED)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildPaymentOption(Icons.pending, 'Pendiente', Colors.orange),
              ),
            ],
          ),

          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: loading ? null : _confirm,
              icon: loading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check_circle),
              label: Text(loading ? 'Procesando...' : 'Confirmar pedido'),
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption(IconData icon, String label, Color color) {
    final selected = paymentMethod == label;
    return GestureDetector(
      onTap: () => setState(() => paymentMethod = label),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : null,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : Theme.of(context).colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? color : null, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? color : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllLocked(ColorScheme cs, TextTheme styles) {
    return Container(
      padding: const EdgeInsets.all(32),
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(Icons.restaurant_menu, size: 64, color: cs.primary.withValues(alpha: 0.5)),
          const SizedBox(height: 20),
          Text(
            '¡Ya estamos preparando los pedidos!',
            style: styles.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'El kiosco está ultimando los pedidos del día. Volvé más tarde para hacer tu compra.',
            style: styles.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Icon(Icons.emoji_events, size: 40, color: Colors.amber.shade400),
        ],
      ),
    );
  }
}
