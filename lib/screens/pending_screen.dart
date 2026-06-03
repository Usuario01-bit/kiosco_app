import 'package:flutter/material.dart';

import '../services/firestore_service.dart';
import '../services/responsive.dart';

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

  @override
  void initState() {

    super.initState();

    loadPending();
  }

  // =========================
  // CARGAR PENDIENTES
  // =========================

  Future<void> loadPending() async {

    final data =
    await FirestoreService.instance
        .getPendings();

    double total = 0;

    for (var item in data) {

      total +=
          (item['amount'] as num)
              .toDouble();
    }

    setState(() {

      pendingList = data;

      totalPending = total;

      loading = false;
    });
  }

  // =========================
  // PAGAR DEUDA
  // =========================

  Future<void> payPending(
      int id,
      String student,
      ) async {

    try {

      await FirestoreService.instance
          .payPendingSales(student);

      await loadPending();

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
      const Color(0xFFF5F7FB),

      appBar: AppBar(

        title: const Text(
          'Pendientes',
        ),

        backgroundColor:
        const Color(0xFF4A90E2),

        foregroundColor:
        Colors.white,
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
              ),
            ),

            SizedBox(
              height: R.sp(context, 10),
            ),

            Text(

              '${pendingList.length} estudiantes con deuda',

              style: TextStyle(

                fontSize: R.fs(context, 20),

                color:
                Colors.black54,
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
                R.sp(context, 30),
              ),

              decoration:
              BoxDecoration(

                color:
                const Color(
                  0xFFFFF4E5,
                ),

                borderRadius:
                BorderRadius.circular(
                  30,
                ),

                border: Border.all(

                  color:
                  Colors.orange.shade300,
                ),
              ),

              child: Column(

                children: [

                  Text(

                    'Total Fiado',

                    style: TextStyle(

                      fontSize: R.fs(context, 24),

                      color:
                      Colors.orange,
                    ),
                  ),

                  SizedBox(
                    height: R.sp(context, 15),
                  ),

                  Text(

                    '\$${totalPending.toStringAsFixed(2)}',

                    style:
                    TextStyle(

                      fontSize: R.fs(context, 50),

                      fontWeight:
                      FontWeight.bold,

                      color:
                      Colors.orange,
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
                        Colors.black54,
                      ),
                    ),
                  ],
                ),
              )

                  : RefreshIndicator(

                onRefresh: loadPending,

                child: ListView.builder(

                itemCount:
                pendingList.length,

                itemBuilder:
                    (context, index) {

                  final pending =
                  pendingList[index];

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

                    child: Row(

                      children: [

                        Expanded(
                          child: Column(

                            crossAxisAlignment:
                            CrossAxisAlignment
                                .start,

                            children: [

                              Text(

                                pending[
                                'student'],
                                overflow: TextOverflow.ellipsis,

                                style:
                                TextStyle(

                                  fontSize: R.fs(context, 28),

                                  fontWeight:
                                  FontWeight.bold,
                                ),
                              ),

                              SizedBox(
                                height: R.sp(context, 10),
                              ),

                              Text(

                                '\$${(pending['amount'] as num).toDouble().toStringAsFixed(2)}',

                                style:
                                TextStyle(

                                  fontSize: R.fs(context, 32),

                                  color:
                                  Colors.orange,

                                  fontWeight:
                                  FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(width: R.sp(context, 16)),

                        ElevatedButton(

                          style:
                          ElevatedButton
                              .styleFrom(

                            backgroundColor:
                            Colors.green,

                            padding: EdgeInsets.symmetric(
                              horizontal: R.sp(context, 30),
                              vertical: R.sp(context, 20),
                            ),

                            shape:
                            RoundedRectangleBorder(

                              borderRadius:
                              BorderRadius.circular(
                                18,
                              ),
                            ),
                          ),

                          onPressed: () {

                            payPending(
                              pending['id'],
                              pending['student'],
                            );
                          },

                          child: Text(

                            'Pagar',

                            style: TextStyle(

                              color:
                              Colors.white,

                              fontSize: R.fs(context, 20),

                              fontWeight:
                              FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            ),
          ],
        ),
      ),
    );
  }
}