import 'dart:async';
import 'package:flutter/material.dart';

import '../services/excel_import.dart';
import '../services/firestore_service.dart';
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

  final TextEditingController searchController =
  TextEditingController();

  List<Map<String, dynamic>> students = [];

  StreamSubscription? _studentsSub;

  // =====================================================
  // INIT
  // =====================================================

  @override
  void initState() {
    super.initState();
    _studentsSub = FirestoreService.instance
        .streamStudents()
        .listen((data) => setState(() => students = data));
  }

  @override
  void dispose() {
    _studentsSub?.cancel();
    searchController.dispose();
    nameController.dispose();
    super.dispose();
  }

  // =====================================================
  // LOAD STUDENTS
  // =====================================================

  Future<void> loadStudents() async {}

  List<Map<String, dynamic>> get _filteredStudents {
    final query = searchController.text.toLowerCase().trim();
    if (query.isEmpty) return students;
    return students.where((s) {
      final name = (s['name'] as String? ?? '').toLowerCase();
      return name.contains(query);
    }).toList();
  }

  Map<String?, List<Map<String, dynamic>>> get _groupedByGrado {
    final filtered = _filteredStudents;
    final Map<String?, List<Map<String, dynamic>>> groups = {};
    for (final s in filtered) {
      final grado = s['grado'] as String?;
      final key = (grado != null && grado.trim().isNotEmpty) ? grado.trim() : null;
      groups.putIfAbsent(key, () => []);
      groups[key]!.add(s);
    }
    final sortedKeys = groups.keys.toList()
      ..sort((a, b) {
        if (a == null) return 1;
        if (b == null) return -1;
        return a.compareTo(b);
      });
    return {for (final k in sortedKeys) k: groups[k]!};
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

    await FirestoreService.instance
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

    await FirestoreService.instance
        .deleteStudent(id);

    await loadStudents();
  }

  // =====================================================
  // UI
  // =====================================================

  @override
  Widget build(BuildContext context) {

    final groups = _groupedByGrado;
    final totalFiltered = _filteredStudents.length;

    return Scaffold(

      backgroundColor:
      Theme.of(context).scaffoldBackgroundColor,

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

                    padding: EdgeInsets.all(
                      R.sp(context, 18),
                    ),

                    decoration:
                    BoxDecoration(

                      color: Colors.white
                          .withValues(alpha: 0.2),

                      borderRadius:
                      BorderRadius.circular(
                        R.sp(context, 24),
                      ),
                    ),

                    child: Icon(

                      Icons.people,

                      color: Colors.white,

                      size: R.sp(context, 40),
                    ),
                  ),

                  SizedBox(width: R.sp(context, 12)),

                  Expanded(
                    child: Column(

                      crossAxisAlignment:
                      CrossAxisAlignment
                          .start,

                      children: [

                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Estudiantes',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: R.fs(context, 34),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        SizedBox(height: R.sp(context, 6)),

                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Gestiona los estudiantes',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: R.fs(context, 18),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                  IconButton(
                    onPressed: importFromExcel,
                    icon: const Icon(
                      Icons.file_upload_outlined,
                      color: Colors.white,
                      size: 28,
                    ),
                    tooltip: 'Importar desde Excel',
                  ),
                  IconButton(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          title: const Text('Eliminar todos'),
                          content: const Text('¿Seguro que querés borrar TODOS los estudiantes?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancelar'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Eliminar todo', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        final count = await FirestoreService.instance.deleteAllStudents();
                        if (!context.mounted) return;
                        await loadStudents();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$count estudiante${count == 1 ? '' : 's'} eliminado${count == 1 ? '' : 's'}')),
                        );
                      }
                    },
                    icon: const Icon(
                      Icons.delete_sweep,
                      color: Colors.white,
                      size: 28,
                    ),
                    tooltip: 'Eliminar todos los estudiantes',
                  ),
                ],
              ),
            ),
          ),

          // =================================================
          // SEARCH
          // =================================================

          Padding(

            padding: EdgeInsets.fromLTRB(
              R.sp(context, 24),
              R.sp(context, 16),
              R.sp(context, 24),
              0,
            ),

            child: TextField(

              controller: searchController,

              onChanged: (_) => setState(() {}),

              decoration:
              InputDecoration(

                hintText:
                'Buscar estudiante...',

                prefixIcon:
                const Icon(
                  Icons.search,
                ),

                suffixIcon:
                searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,

                filled: true,

                fillColor:
                Theme.of(context).cardColor,

                border:
                OutlineInputBorder(

                  borderRadius:
                  BorderRadius
                      .circular(
                      24),

                  borderSide:
                  BorderSide
                      .none,
                ),
              ),
            ),
          ),

          // =================================================
          // INPUT
          // =================================================

          Padding(

            padding: EdgeInsets.symmetric(
              horizontal: R.sp(context, 24),
            ),

            child: Container(

              padding: EdgeInsets.all(
                R.sp(context, 20),
              ),

              decoration: BoxDecoration(

                color:
                Theme.of(context).cardColor,

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
                        Theme.of(context).colorScheme.surfaceContainerHighest,

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

                    height: R.sp(context, 72),

                    child:
                    ElevatedButton.icon(

                      onPressed:
                      addStudent,

                      icon: const Icon(
                        Icons.add,
                      ),

                      label: Text(

                        'Agregar',

                        style: TextStyle(

                          fontSize: R.fs(context, 18),

                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),

                      style:
                      ElevatedButton
                          .styleFrom(

                        backgroundColor:
                        Theme.of(context).colorScheme.primary,

                        foregroundColor:
                        Theme.of(context).colorScheme.onPrimary,

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

          SizedBox(height: R.sp(context, 12)),

          // =================================================
          // LIST
          // =================================================

          Expanded(

            child: students.isEmpty

                ? Center(

              child: Text(

                'No hay estudiantes',

                style: TextStyle(

                  fontSize: R.fs(context, 28),

                  color:
                  Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                ),
              ),
            )

                : RefreshIndicator(

                onRefresh: loadStudents,

                child: ListView(

              padding: EdgeInsets.symmetric(
                horizontal: R.sp(context, 24),
              ),

              children: [

                // =========================
                // RESULT COUNT
                // =========================

                if (searchController.text.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: R.sp(context, 12),
                    ),
                    child: Text(
                      '$totalFiltered resultado${totalFiltered == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: R.fs(context, 18),
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                      ),
                    ),
                  ),

                // =========================
                // GROUPED LIST
                // =========================

                for (final entry in groups.entries)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // Grade header
                      Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: R.sp(context, 8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.school,
                              size: R.fs(context, 22),
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            SizedBox(width: R.sp(context, 8)),
                            Text(
                              entry.key ?? 'Sin grado',
                              style: TextStyle(
                                fontSize: R.fs(context, 22),
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            Spacer(),
                            Text(
                              '${entry.value.length}',
                              style: TextStyle(
                                fontSize: R.fs(context, 18),
                                color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Students in this grade
                      for (final student in entry.value)
                        Container(

                          margin:
                          const EdgeInsets
                              .only(
                            bottom: 14,
                          ),

                          padding:
                          const EdgeInsets
                              .all(18),

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

                                padding: EdgeInsets.all(R.sp(context, 10)),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.person,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 22,
                                ),
                              ),

                              SizedBox(
                                  width: R.sp(context, 16)),

                              Expanded(

                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      student['name'],
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: R.fs(context, 22),
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).textTheme.bodyLarge?.color,
                                      ),
                                    ),
                                    if (student['grado'] != null && (student['grado'] as String).trim().isNotEmpty)
                                      Text(
                                        student['grado'],
                                        style: TextStyle(
                                          fontSize: R.fs(context, 16),
                                          color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              IconButton(

                                  onPressed: () async {
                                  try {
                                  final sales =
                                  await FirestoreService.instance
                                      .getSalesByStudentId(

                                    student['id'],
                                  );

                                  if (!context.mounted) return;

                                  showDialog(

                                    context: context,

                                    builder: (ctx) {

                                      return AlertDialog(

                                        title: Text(
                                          student['name'],
                                        ),

                                        content: ConstrainedBox(

                                          constraints: BoxConstraints(
                                            maxHeight: MediaQuery.of(context).size.height * 0.6,
                                          ),

                                          child: SizedBox(

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

                                                      await FirestoreService.instance
                                                          .paySale(sale['id']);

                                                      await loadStudents();

                                                      if (ctx.mounted) Navigator.pop(ctx);
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
                                                        sale['paid_at'] != null && (sale['paid_at'] as String).length >= 10
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
                                                        '${sale['date'] ?? ''} - ${formatTime(sale['time'])}',

                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                        ),
                                                      ),

                                                      Text(
                                                        sale['recreo'] ??
                                                            'Sin recreo',

                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
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
                                        ),
                                        actions: [

                                          TextButton(

                                            onPressed: () {

                                              Navigator.pop(
                                                  ctx);
                                            },

                                            child: const Text(
                                              'Cerrar',
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error al cargar historial: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },

                              icon: Icon(
                                Icons.history,

                                  color: Theme.of(context).colorScheme.primary,

                                  size: R.sp(context, 26),
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

                                icon: Icon(

                                  Icons.delete,

                                  color:
                                  Colors.red,

                                  size: R.sp(context, 26),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
              ],
            ),
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // IMPORT FROM EXCEL
  // =====================================================

  Future<void> importFromExcel() async {
    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final count = await pickAndImportStudents(context);

      if (!context.mounted) return;

      Navigator.pop(context);

      if (count == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se importaron estudiantes')),
        );
      } else if (count == -1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El archivo está vacío')),
        );
      } else if (count == -2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El Excel debe tener columnas: PrimerNombre, SegundoNombre, ApellidoMaterno, Grado')),
        );
      } else {
        await loadStudents();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Se importaron $count estudiantes')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al importar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
