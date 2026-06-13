import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/excel_import.dart';
import '../services/supabase_service.dart';
import '../services/local_cache_service.dart';
import '../services/responsive.dart';
import '../services/store_config.dart';

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

  final TextEditingController gradoController =
  TextEditingController();

  final TextEditingController tempPasswordCtrl =
  TextEditingController();

  final TextEditingController searchController =
  TextEditingController();

  String currentRole = 'alumno';

  List<Map<String, dynamic>> students = [];

  StreamSubscription? _studentsSub;

  // =====================================================
  // INIT
  // =====================================================

  @override
  void initState() {
    super.initState();
    _loadCachedThenStream();
  }

  Future<void> _loadCachedThenStream() async {
    final cached = await LocalCacheService.instance.getCachedStudents();
    if (cached.isNotEmpty && mounted) {
      setState(() => students = cached);
    }
    _studentsSub = SupabaseService.instance
        .streamStudents()
        .listen((data) {
      if (mounted) setState(() => students = data);
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _studentsSub?.cancel();
    searchController.dispose();
    nameController.dispose();
    gradoController.dispose();
    tempPasswordCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredStudents {
    final query = searchController.text.toLowerCase().trim();
    if (query.isEmpty) return students;
    return students.where((s) {
      final name = (s['name'] as String? ?? '').toLowerCase();
      return name.contains(query);
    }).toList();
  }

  Map<String, List<Map<String, dynamic>>> get _groupedByRole {
    final filtered = _filteredStudents;
    final Map<String, List<Map<String, dynamic>>> groups = {};
    for (final s in filtered) {
      final role = s['role'] as String? ?? 'alumno';
      groups.putIfAbsent(role, () => []);
      groups[role]!.add(s);
    }
    final ordered = <String>['alumno', 'profesor', 'otro'];
    for (final key in ordered.reversed) {
      if (groups.containsKey(key)) {
        final entry = groups.remove(key)!;
        if (key == 'alumno') {
          final Map<String?, List<Map<String, dynamic>>> gradoGroups = {};
          for (final s in entry) {
            final g = (s['grade'] ?? s['grado']) as String?;
            final k = (g != null && g.trim().isNotEmpty) ? g.trim() : null;
            gradoGroups.putIfAbsent(k, () => []);
            gradoGroups[k]!.add(s);
          }
          final sortedKeys = gradoGroups.keys.toList()..sort((a, b) {
            if (a == null) return 1;
            if (b == null) return -1;
            return a.compareTo(b);
          });
          for (final k in sortedKeys) {
            final list = gradoGroups[k]!;
            list.sort((a, b) => (a['name'] as String? ?? '').compareTo(b['name'] as String? ?? ''));
            groups['alumno__${k ?? '_'}'] = list;
          }
        } else {
          final list = entry;
          list.sort((a, b) => (a['name'] as String? ?? '').compareTo(b['name'] as String? ?? ''));
          groups[key] = list;
        }
      }
    }
    return groups;
  }

  // =====================================================
  // ADD STUDENT
  // =====================================================

  Future<void> addStudent() async {
    final name = nameController.text.trim();
    if (name.isEmpty) return;

    final grado = gradoController.text.trim();
    final tempPassword = tempPasswordCtrl.text.trim();

    try {
      await SupabaseService.instance.insertStudent({
        'name': name,
        if (grado.isNotEmpty) 'grado': grado,
        'role': currentRole,
        'tempPassword': tempPassword,
      });

      nameController.clear();
      gradoController.clear();
      tempPasswordCtrl.clear();

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$name agregado'),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al agregar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> showAddDialog() async {
    nameController.clear();
    gradoController.clear();
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789';
    final rng = Random();
    tempPasswordCtrl.text = List.generate(8, (_) => chars[rng.nextInt(chars.length)]).join();
    currentRole = 'alumno';

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.person_add,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Agregar ${StoreConfig.instance.entityLC()}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Nombre y apellido',
                        hintText: 'Ej: Juan Pérez',
                        prefixIcon: const Icon(Icons.person),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: currentRole,
                      decoration: InputDecoration(
                        labelText: 'Rol',
                        prefixIcon: const Icon(Icons.badge),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'alumno', child: Text('Alumno')),
                        DropdownMenuItem(value: 'profesor', child: Text('Profesor')),
                        DropdownMenuItem(value: 'otro', child: Text('Otro')),
                      ],
                      onChanged: (v) {
                        setDialogState(() => currentRole = v ?? 'alumno');
                      },
                    ),
                    if (currentRole == 'alumno') ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: gradoController,
                        decoration: InputDecoration(
                          labelText: 'Grado',
                          hintText: 'Ej: 5° A',
                          prefixIcon: const Icon(Icons.school),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: tempPasswordCtrl,
                        keyboardType: TextInputType.text,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(8),
                        ],
                        decoration: InputDecoration(
                          labelText: 'Contraseña temporal',
                          hintText: 'Ej: aB3kF9x2',
                          prefixIcon: const Icon(Icons.lock),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.refresh),
                            tooltip: 'Generar nueva contraseña',
                            onPressed: () {
                              const _chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789';
                              final rng = Random();
                              setDialogState(() {
                                tempPasswordCtrl.text = List.generate(8, (_) => _chars[rng.nextInt(_chars.length)]).join();
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                FilledButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await addStudent();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // =====================================================
  // DELETE STUDENT
  // =====================================================

  Future<void> deleteStudent(
      dynamic id) async {

    await SupabaseService.instance
        .deleteStudent(id);
  }

  Future<void> _showPasswordDialog(Map<String, dynamic> student) async {
    final pwCtrl = TextEditingController();

    final newPw = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Cambiar contraseña de ${student['name']}'),
        content: TextField(
          controller: pwCtrl,
          keyboardType: TextInputType.text,
          inputFormatters: [
            LengthLimitingTextInputFormatter(8),
          ],
          decoration: InputDecoration(
            labelText: 'Nueva contraseña (máx 8 caracteres)',
            prefixIcon: const Icon(Icons.lock),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, pwCtrl.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (newPw != null && newPw.isNotEmpty && mounted) {
      try {
        await SupabaseService.instance.setStudentTempPassword(student['id'], newPw);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contraseña actualizada'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  // =====================================================
  // UI
  // =====================================================

  @override
  Widget build(BuildContext context) {

    final groups = _groupedByRole;
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
                            StoreConfig.instance.entityPlural,
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
                            'Gestiona los ${StoreConfig.instance.entityPluralLC()}',
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
                          content: Text('¿Seguro que querés borrar TODOS los ${StoreConfig.instance.entityPluralLC()}?'),
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
                        final count = await SupabaseService.instance.deleteAllStudents();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$count ${count == 1 ? StoreConfig.instance.entityLC() : StoreConfig.instance.entityPluralLC()} eliminado${count == 1 ? '' : 's'}')),
                        );
                      }
                    },
                    icon: const Icon(
                      Icons.delete_sweep,
                      color: Colors.white,
                      size: 28,
                    ),
                    tooltip: 'Eliminar todos los ${StoreConfig.instance.entityPluralLC()}',
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
                'Buscar ${StoreConfig.instance.entityLC()}...',

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
          // ADD BUTTON
          // =================================================

          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: R.sp(context, 24),
              vertical: R.sp(context, 12),
            ),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: showAddDialog,
                icon: const Icon(Icons.person_add),
                label: Text(
                  'Agregar ${StoreConfig.instance.entityLC()}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
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

                'No hay ${StoreConfig.instance.entityPluralLC()}',

                style: TextStyle(

                  fontSize: R.fs(context, 28),

                  color:
                  Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                ),
              ),
            )

                : ListView(

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

                      // Section header
                      Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: R.sp(context, 8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              entry.key == 'profesor'
                                  ? Icons.school
                                  : entry.key == 'otro'
                                      ? Icons.person
                                      : Icons.school,
                              size: R.fs(context, 22),
                              color: entry.key == 'profesor'
                                  ? Colors.green
                                  : entry.key == 'otro'
                                      ? Colors.grey
                                      : Theme.of(context).colorScheme.primary,
                            ),
                            SizedBox(width: R.sp(context, 8)),
                            Text(
                              entry.key == 'profesor'
                                  ? 'Profesores'
                                  : entry.key == 'otro'
                                      ? 'Otros'
                                      : entry.key.startsWith('alumno__')
                                          ? (entry.key == 'alumno___'
                                              ? 'Sin grado'
                                              : entry.key.substring(8))
                                          : entry.key,
                              style: TextStyle(
                                fontSize: R.fs(context, 22),
                                fontWeight: FontWeight.bold,
                                color: entry.key == 'profesor'
                                    ? Colors.green
                                    : entry.key == 'otro'
                                        ? Colors.grey
                                        : Theme.of(context).colorScheme.primary,
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
                                    if ((student['grade'] ?? student['grado']) != null && ((student['grade'] ?? student['grado']) as String).trim().isNotEmpty)
                                      Text(
                                        student['grade'] ?? student['grado'],
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
                                  await SupabaseService.instance
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

                                                    final method = (sale['payment_method'] ?? '').toString().toLowerCase();

                                                    if (method.contains('pendiente')) {

                                                      await SupabaseService.instance
                                                          .paySale(sale['id']);

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
                                                              : (sale['payment_method'] ?? '')
                                                              .toString()
                                                              .toLowerCase()
                                                              .contains('pendiente')
                                                              ? 'Pendiente'
                                                              : 'Pagado',

                                                        style: TextStyle(
                                                          color: (sale['payment_method'] ?? '')
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
                                onPressed: () => _showPasswordDialog(student),
                                icon: Icon(
                                  Icons.lock,
                                  color: student['tempPassword'] != null && (student['tempPassword'] as String).isNotEmpty
                                      ? Colors.orange.shade600
                                      : Colors.grey,
                                  size: R.sp(context, 26),
                                ),
                                tooltip: 'Cambiar contraseña temporal',
                              ),
                              IconButton(

                                onPressed: () {

                                  showDialog(

                                    context: context,

                                    builder: (ctx) => AlertDialog(

                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),

                                      title: Text('Eliminar ${StoreConfig.instance.entityLC()}'),

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
          SnackBar(content: Text('No se importaron ${StoreConfig.instance.entityPluralLC()}')),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Se importaron $count ${StoreConfig.instance.entityPluralLC()}')),
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
