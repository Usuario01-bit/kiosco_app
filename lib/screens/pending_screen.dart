import 'dart:async';
import 'package:flutter/material.dart';

import '../services/supabase_service.dart';
import '../services/responsive.dart';
import '../services/exporter.dart';
import '../services/store_config.dart';

class PendingScreen extends StatefulWidget {

  const PendingScreen({super.key});

  @override
  State<PendingScreen> createState() =>
      _PendingScreenState();
}

class _PendingScreenState
    extends State<PendingScreen> {

  List<Map<String, dynamic>>
  pendingList = [];

  double totalPending = 0;

  bool loading = true;

  StreamSubscription? _pendingSub;

  @override
  void initState() {
    super.initState();
    _pendingSub = SupabaseService.instance
        .streamPendings()
        .listen((data) {
      double total = 0;
      for (var item in data) {
        final amount = (item['amount'] as num).toDouble();
        final paid = (item['paid'] as num?)?.toDouble() ?? 0;
        total += amount - paid;
      }
      setState(() {
        pendingList = data;
        totalPending = total;
        loading = false;
      });
    }, onError: (e) {
      debugPrint('Pending stream error: $e');
      setState(() => loading = false);
    });
  }

  @override
  void dispose() {
    _pendingSub?.cancel();
    super.dispose();
  }

  // =========================
  // ABONAR (PARCIAL)
  // =========================

  void showAbonarDialog(
      dynamic id,
      String student,
      double currentAmount,
      double currentPaid,
      ) {
    final remaining = currentAmount - currentPaid;
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Abonar a $student',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Debe: \$${remaining.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: R.fs(context, 20),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: R.sp(context, 15)),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Monto a abonar',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(
                controller.text.replaceAll(',', '.'),
              );
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Ingrese un monto válido'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              if (amount > remaining) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('El abono no puede superar la deuda (\$${remaining.toStringAsFixed(2)})'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              try {
                await SupabaseService.instance
                    .abonarPending(id, amount);
                Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Abono de \$${amount.toStringAsFixed(2)} registrado',
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Error al abonar: $e',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: Text('Abonar'),
          ),
        ],
      ),
    );
  }

  // =========================
  // PAGAR DEUDA
  // =========================

  Future<void> payPending(
      dynamic id,
      String student,
      ) async {

    try {

      await SupabaseService.instance
          .payPendingSales(student, id);

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            content: Text(
              'Deuda de "$student" pagada',
            ),
          ),
        );
      }
    } catch (e) {

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            content: Text(
              'Error al pagar: $e',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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

      appBar: AppBar(

        title: const Text(
          'Pendientes',
        ),

        backgroundColor:
        const Color(0xFF4A90E2),

        foregroundColor:
        Colors.white,

        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Exportar a Excel',
            onPressed: () => exportPendingToExcel(context),
          ),
        ],
      ),

      body: Padding(

        padding: EdgeInsets.all(
          R.sp(context, 20),
        ),

        child: Column(

          crossAxisAlignment:
          CrossAxisAlignment.start,

          children: [

            // =========================
            // TITULO
            // =========================

            Text(

              'Pendientes (Fiado)',

              style: TextStyle(

                fontSize: R.fs(context, 38),

                fontWeight:
                FontWeight.bold,

                color:
                Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),

            SizedBox(
              height: R.sp(context, 10),
            ),

            Text(

              '${pendingList.length} ${StoreConfig.instance.entityLC()} con deuda',

              style: TextStyle(

                fontSize: R.fs(context, 20),

                color:
                Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
              ),
            ),

            SizedBox(
              height: R.sp(context, 25),
            ),

            // =========================
            // TOTAL FIADO
            // =========================

            Container(

              width: double.infinity,

              padding:
              EdgeInsets.all(
                R.sp(context, 20),
              ),

              decoration:
              BoxDecoration(

                color:
                Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF2A2020)
                    : const Color(0xFFFFF4E5),

                borderRadius:
                BorderRadius.circular(
                  24,
                ),

                border: Border.all(

                  color:
                  Colors.orange,
                ),
              ),

              child: Row(

                children: [

                  Container(
                    padding: EdgeInsets.all(R.sp(context, 8)),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.warning_rounded, color: Colors.orange),
                  ),

                  SizedBox(width: R.sp(context, 16)),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        Text(
                          'Total Fiado',
                          style: TextStyle(
                            fontSize: R.fs(context, 18),
                            color: Colors.orange,
                          ),
                        ),

                        SizedBox(height: R.sp(context, 4)),

                        Text(
                          '\$${totalPending.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: R.fs(context, 34),
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(
              height: R.sp(context, 30),
            ),

            // =========================
            // LISTA
            // =========================

            Expanded(

              child: pendingList.isEmpty

                  ? Center(

                child: Column(

                  mainAxisAlignment:
                  MainAxisAlignment
                      .center,

                  children: [

                    Icon(

                      Icons.check_circle,

                      size: R.sp(context, 90),

                      color:
                      Colors.green
                          .shade400,
                    ),

                    SizedBox(
                      height: R.sp(context, 20),
                    ),

                    Text(

                      'No hay pendientes',

                      style: TextStyle(

                        fontSize: R.fs(context, 30),

                        fontWeight:
                        FontWeight.bold,

                        color:
                        Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),

                    SizedBox(
                      height: R.sp(context, 10),
                    ),

                    Text(

                      'Todas las cuentas están al día',

                      style: TextStyle(

                        fontSize: R.fs(context, 20),

                        color:
                        Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                          ),
                        ),
                      ],

                ),
              )

                  : ListView.builder(

                itemCount:
                pendingList.length,

                itemBuilder:
                    (context, index) {

                  final pending =
                  pendingList[index];
                  final amount =
                      (pending['amount'] as num).toDouble();
                  final paid =
                      (pending['paid'] as num?)?.toDouble() ?? 0;
                  final remaining = amount - paid;

                  return Container(

                    margin: EdgeInsets.only(
                      bottom: R.sp(context, 20),
                    ),

                    padding: EdgeInsets.all(
                      R.sp(context, 20),
                    ),

                    decoration:
                    BoxDecoration(

                      color:
                      Theme.of(context)
                          .cardColor,

                      borderRadius:
                      BorderRadius.circular(
                        25,
                      ),

                      boxShadow: [

                        BoxShadow(

                          color:
                          Colors
                              .black12,

                          blurRadius:
                          10,

                          offset:
                          const Offset(
                            0,
                            4,
                          ),
                        ),
                      ],
                    ),

                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        Text(
                          pending['student'] ?? 'Desconocido',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: R.fs(context, 28),
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),

                        SizedBox(height: R.sp(context, 6)),

                        Text(
                          '\$${remaining.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: R.fs(context, 32),
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        if (paid > 0)
                          Padding(
                            padding: EdgeInsets.only(top: R.sp(context, 4)),
                            child: Text(
                              'Abonado: \$${paid.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: R.fs(context, 18),
                                color: Colors.green.shade600,
                              ),
                            ),
                          ),

                        SizedBox(height: R.sp(context, 14)),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [

                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange.shade700,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(horizontal: R.sp(context, 18), vertical: R.sp(context, 14)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                              ),
                              icon: const Icon(Icons.payments, size: 20),
                              label: Text('Abonar', style: TextStyle(fontSize: R.fs(context, 16), fontWeight: FontWeight.bold)),
                              onPressed: () => showAbonarDialog(pending['id'], pending['student'], amount, paid),
                            ),

                            SizedBox(width: R.sp(context, 10)),

                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(horizontal: R.sp(context, 18), vertical: R.sp(context, 14)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                              ),
                              icon: const Icon(Icons.check_circle, size: 20),
                              label: Text('Pagar', style: TextStyle(fontSize: R.fs(context, 16), fontWeight: FontWeight.bold)),
                              onPressed: () => payPending(pending['id'], pending['student']),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],   // close Column children
      ),     // close Column
    ),       // close Padding
  );         // close Scaffold
  }
}
