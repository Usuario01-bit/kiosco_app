import 'package:flutter/material.dart';

import '../services/database_helper.dart';

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
    await DatabaseHelper.instance
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

      await DatabaseHelper.instance
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

        padding:
        const EdgeInsets.all(20),

        child: Column(

          crossAxisAlignment:
          CrossAxisAlignment.start,

          children: [

            // =========================
            // TITULO
            // =========================

            const Text(

              'Pendientes (Fiado)',

              style: TextStyle(

                fontSize: 38,

                fontWeight:
                FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 10,
            ),

            Text(

              '${pendingList.length} estudiantes con deuda',

              style: const TextStyle(

                fontSize: 20,

                color:
                Colors.black54,
              ),
            ),

            const SizedBox(
              height: 25,
            ),

            // =========================
            // TOTAL FIADO
            // =========================

            Container(

              width: double.infinity,

              padding:
              const EdgeInsets.all(
                30,
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

                  const Text(

                    'Total Fiado',

                    style: TextStyle(

                      fontSize: 24,

                      color:
                      Colors.orange,
                    ),
                  ),

                  const SizedBox(
                    height: 15,
                  ),

                  Text(

                    '\$${totalPending.toStringAsFixed(2)}',

                    style:
                    const TextStyle(

                      fontSize: 50,

                      fontWeight:
                      FontWeight.bold,

                      color:
                      Colors.orange,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              height: 30,
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

                      size: 90,

                      color:
                      Colors.green
                          .shade400,
                    ),

                    const SizedBox(
                      height: 20,
                    ),

                    const Text(

                      'No hay pendientes',

                      style: TextStyle(

                        fontSize: 30,

                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    const Text(

                      'Todas las cuentas están al día',

                      style: TextStyle(

                        fontSize: 20,

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

                    margin:
                    const EdgeInsets
                        .only(
                      bottom: 20,
                    ),

                    padding:
                    const EdgeInsets
                        .all(20),

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

                      mainAxisAlignment:
                      MainAxisAlignment
                          .spaceBetween,

                      children: [

                        Column(

                          crossAxisAlignment:
                          CrossAxisAlignment
                              .start,

                          children: [

                            Text(

                              pending[
                              'student'],

                              style:
                              const TextStyle(

                                fontSize:
                                28,

                                fontWeight:
                                FontWeight
                                    .bold,
                              ),
                            ),

                            const SizedBox(
                              height: 10,
                            ),

                            Text(

                              '\$${(pending['amount'] as num).toDouble().toStringAsFixed(2)}',

                              style:
                              const TextStyle(

                                fontSize:
                                32,

                                color:
                                Colors.orange,

                                fontWeight:
                                FontWeight
                                    .bold,
                              ),
                            ),
                          ],
                        ),

                        ElevatedButton(

                          style:
                          ElevatedButton
                              .styleFrom(

                            backgroundColor:
                            Colors.green,

                            padding:
                            const EdgeInsets
                                .symmetric(

                              horizontal:
                              30,

                              vertical:
                              20,
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

                          child: const Text(

                            'Pagar',

                            style: TextStyle(

                              color:
                              Colors.white,

                              fontSize:
                              20,

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