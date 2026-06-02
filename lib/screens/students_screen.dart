import 'package:flutter/material.dart';

import '../services/database_helper.dart';
import '../services/responsive.dart';

class StudentsScreen extends StatefulWidget {

  const StudentsScreen({super.key});

  @override
  State<StudentsScreen> createState() =>
      _StudentsScreenState();
}

class _StudentsScreenState
    extends State<StudentsScreen> {

  final TextEditingController nameController =
  TextEditingController();

  List<Map<String, dynamic>> students = [];

  // =====================================================
  // INIT
  // =====================================================

  @override
  void initState() {

    super.initState();

    loadStudents();
  }

  // =====================================================
  // LOAD STUDENTS
  // =====================================================

  Future<void> loadStudents() async {

    final data =
    await DatabaseHelper.instance
        .getStudents();

    setState(() {

      students = data;
    });
  }

  // =====================================================
  // ADD STUDENT
  // =====================================================

  Future<void> addStudent() async {

    if (nameController.text
        .trim()
        .isEmpty) {

      return;
    }

    await DatabaseHelper.instance
        .insertStudent({

      'name': nameController.text.trim(),

    });

    nameController.clear();

    await loadStudents();

    ScaffoldMessenger.of(context)
        .showSnackBar(

      const SnackBar(

        content:
        Text('Estudiante agregado'),

      ),
    );
  }

  // =====================================================
  // DELETE STUDENT
  // =====================================================

  Future<void> deleteStudent(
      int id) async {

    await DatabaseHelper.instance
        .deleteStudent(id);

    await loadStudents();
  }

  // =====================================================
  // UI
  // =====================================================

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor:
      const Color(0xFFF5F7FB),

      body: Column(

        children: [

          // =================================================
          // HEADER
          // =================================================

          Container(

            width: double.infinity,

            padding:
            EdgeInsets.all(R.sp(context, 30)),

            decoration:
            const BoxDecoration(

              gradient: LinearGradient(

                colors: [

                  Color(0xFF2563EB),

                  Color(0xFF1D4ED8),

                ],
              ),
            ),

            child: SafeArea(

              child: Row(

                children: [

                  Container(

                    padding:
                    const EdgeInsets.all(
                        18),

                    decoration:
                    BoxDecoration(

                      color: Colors.white
                          .withValues(alpha: 0.2),

                      borderRadius:
                      BorderRadius
                          .circular(
                          24),
                    ),

                    child: const Icon(

                      Icons.people,

                      color: Colors.white,

                      size: 40,
                    ),
                  ),

                  const SizedBox(width: 20),

                  const Column(

                    crossAxisAlignment:
                    CrossAxisAlignment
                        .start,

                    children: [

                      Text(

                        'Estudiantes',

                        style: TextStyle(

                          color:
                          Colors.white,

                          fontSize: 34,

                          fontWeight:
                          FontWeight
                              .bold,
                        ),
                      ),

                      SizedBox(height: 8),

                      Text(

                        'Gestiona los estudiantes',

                        style: TextStyle(

                          color:
                          Colors.white70,

                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // =================================================
          // INPUT
          // =================================================

          Padding(

            padding:
            const EdgeInsets.all(24),

            child: Container(

              padding:
              const EdgeInsets.all(
                  20),

              decoration: BoxDecoration(

                color: Colors.white,

                borderRadius:
                BorderRadius.circular(
                    28),

                boxShadow: [

                  BoxShadow(

                    color: Colors.black
                        .withValues(alpha: 0.05),

                    blurRadius: 20,

                    offset:
                    const Offset(0, 8),
                  ),
                ],
              ),

              child: Row(

                children: [

                  Expanded(

                    child: TextField(

                      controller:
                      nameController,

                      decoration:
                      InputDecoration(

                        hintText:
                        'Nombre del estudiante',

                        prefixIcon:
                        const Icon(
                          Icons.person,
                        ),

                        filled: true,

                        fillColor:
                        const Color(
                            0xFFF5F5F5),

                        border:
                        OutlineInputBorder(

                          borderRadius:
                          BorderRadius
                              .circular(
                              20),

                          borderSide:
                          BorderSide
                              .none,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 20),

                  SizedBox(

                    height: 72,

                    child:
                    ElevatedButton.icon(

                      onPressed:
                      addStudent,

                      icon: const Icon(
                        Icons.add,
                      ),

                      label: const Text(

                        'Agregar',

                        style: TextStyle(

                          fontSize: 18,

                          fontWeight:
                          FontWeight
                              .bold,
                        ),
                      ),

                      style:
                      ElevatedButton
                          .styleFrom(

                        backgroundColor:
                        const Color(
                            0xFF2196F3),

                        foregroundColor:
                        Colors.white,

                        padding:
                        const EdgeInsets
                            .symmetric(
                          horizontal: 28,
                        ),

                        shape:
                        RoundedRectangleBorder(

                          borderRadius:
                          BorderRadius
                              .circular(
                              22),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // =================================================
          // LIST
          // =================================================

          Expanded(

            child: students.isEmpty

                ? const Center(

              child: Text(

                'No hay estudiantes',

                style: TextStyle(

                  fontSize: 28,

                  color:
                  Colors.grey,
                ),
              ),
            )

                : RefreshIndicator(

                onRefresh: loadStudents,

                child: ListView.builder(

              padding:
              const EdgeInsets
                  .symmetric(
                horizontal: 24,
              ),

              itemCount:
              students.length,

              itemBuilder:
                  (context, index) {

                final student =
                students[index];

                return Container(

                  margin:
                  const EdgeInsets
                      .only(
                    bottom: 20,
                  ),

                  padding:
                  const EdgeInsets
                      .all(22),

                  decoration:
                  BoxDecoration(

                    color:
                    Theme.of(context)
                        .cardColor,

                    borderRadius:
                    BorderRadius
                        .circular(
                        26),

                    boxShadow: [

                      BoxShadow(

                        color: Colors
                            .black
                            .withValues(alpha: 
                            0.04),

                        blurRadius:
                        14,

                        offset:
                        const Offset(
                            0, 6),
                      ),
                    ],
                  ),

                  child: Row(

                    children: [

                      Container(

                        padding:
                        const EdgeInsets
                            .all(
                            16),

                        decoration:
                        BoxDecoration(

                          color: const Color(
                              0xFFDBEAFE)
                              .withValues(alpha: 
                              0.9),

                          shape: BoxShape
                              .circle,
                        ),

                        child:
                        const Icon(

                          Icons.person,

                          color: Color(
                              0xFF2563EB),

                          size: 30,
                        ),
                      ),

                      const SizedBox(
                          width: 20),

                      Expanded(

                        child: Text(

                          student['name'],

                          style:
                          const TextStyle(

                            fontSize: 24,

                            fontWeight:
                            FontWeight
                                .bold,
                          ),
                        ),
                      ),
                      IconButton(

                        onPressed: () async {

                          final sales =
                          await DatabaseHelper.instance
                              .getSalesByStudent(

                            student['name'],
                          );

                          showDialog(

                            context: context,

                            builder: (context) {

                              return AlertDialog(

                                title: Text(
                                  student['name'],
                                ),

                                content: SizedBox(

                                  width: MediaQuery.of(context).size.width * 0.9,

                                  child: sales.isEmpty

                                      ? const Text(
                                    'Sin compras',
                                  )

                                      : ListView.builder(

                                    shrinkWrap: true,

                                    itemCount:
                                    sales.length,

                                    itemBuilder:
                                        (context,
                                        index) {

                                      final sale =
                                      sales[index];

                                      return ListTile(

                                        onTap: () async {

                                          final method = (sale['paymentMethod'] ?? '').toString().toLowerCase();

                                          if (method.contains('pendiente')) {

                                            await DatabaseHelper.instance
                                                .paySale(sale['id']);

                                            await loadStudents();

                                            Navigator.pop(context);
                                          }
                                        },
                                        leading:
                                        const Icon(
                                          Icons.receipt,
                                        ),
                                        title: Text(
                                          sale['product'] ?? 'Producto',
                                        ),

                                        subtitle: Column(
                                          crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              sale['paid_at'] != null
                                                  ? 'Pagado el ${sale['paid_at'].toString().substring(0, 10)}'
                                                  : (sale['paymentMethod'] ?? '')
                                                  .toString()
                                                  .toLowerCase()
                                                  .contains('pendiente')
                                                  ? 'Pendiente'
                                                  : 'Pagado',

                                              style: TextStyle(
                                                color: (sale['paymentMethod'] ?? '')
                                                    .toString()
                                                    .toLowerCase()
                                                    .contains('pendiente')
                                                    ? Colors.orange
                                                    : Colors.green,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),

                                            const SizedBox(height: 4),

                                            Text(
                                              '${sale['date'] ?? ''} - ${sale['time'] ?? ''}',

                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),

                                            Text(
                                              sale['recreo'] ??
                                                  'Sin recreo',

                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                        trailing: Text(

                                          '\$${(sale['total'] as num).toDouble().toStringAsFixed(2)}',
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                actions: [

                                  TextButton(

                                    onPressed: () {

                                      Navigator.pop(
                                          context);
                                    },

                                    child: const Text(
                                      'Cerrar',
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },

                        icon: const Icon(

                          Icons.history,

                          color: Colors.blue,

                          size: 30,
                        ),
                      ),
                      IconButton(

                        onPressed: () {

                          showDialog(

                            context: context,

                            builder: (ctx) => AlertDialog(

                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),

                              title: const Text('Eliminar estudiante'),

                              content: Text('¿Seguro que querés eliminar a "${student['name']}"?'),

                              actions: [

                                TextButton(

                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Cancelar'),
                                ),

                                ElevatedButton(

                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                  ),

                                  onPressed: () {

                                    Navigator.pop(ctx);

                                    deleteStudent(
                                      student['id'],
                                    );
                                  },

                                  child: const Text(
                                    'Eliminar',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },

                        icon: const Icon(

                          Icons.delete,

                          color:
                          Colors.red,

                          size: 30,
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
    );
  }
}