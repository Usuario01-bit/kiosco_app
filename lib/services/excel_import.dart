import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'firestore_service.dart';

Future<int> pickAndImportStudents(BuildContext context) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['xlsx'],
    withData: true,
  );

  if (result == null || result.files.isEmpty) return 0;

  final Uint8List? bytes = result.files.single.bytes;
  if (bytes == null) return 0;

  final excel = Excel.decodeBytes(bytes);
  final sheet = excel.sheets.values.first;
  if (sheet.rows.isEmpty) return -1;

  final headerRow = sheet.rows.first;
  final colMap = <String, int>{};
  for (int i = 0; i < headerRow.length; i++) {
    final cell = headerRow[i];
    final val = cell?.value?.toString().trim().toLowerCase() ?? '';
    if (val == 'primernombre') colMap['firstName'] = i;
    if (val == 'segundonombre') colMap['secondName'] = i;
    if (val == 'apellidomaterno') colMap['lastName'] = i;
    if (val == 'grado') colMap['grado'] = i;
  }

  if (!colMap.containsKey('firstName') || !colMap.containsKey('lastName')) {
    return -2;
  }

  final students = <Map<String, dynamic>>[];
  for (int r = 1; r < sheet.rows.length; r++) {
    final row = sheet.rows[r];
    final primerNombre = row[colMap['firstName']!]?.value?.toString().trim() ?? '';
    final segundoNombre = colMap.containsKey('secondName') && colMap['secondName']! < row.length
        ? (row[colMap['secondName']!]?.value?.toString().trim() ?? '')
        : '';
    final apellidoMaterno = row[colMap['lastName']!]?.value?.toString().trim() ?? '';

    if (primerNombre.isEmpty && apellidoMaterno.isEmpty) continue;

    final name = '${primerNombre}${segundoNombre.isNotEmpty ? ' $segundoNombre' : ''} $apellidoMaterno'
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
    if (name.isEmpty) continue;

    final entry = <String, dynamic>{'name': name};
    if (colMap.containsKey('grado') && colMap['grado']! < row.length) {
      final grado = row[colMap['grado']!]?.value?.toString().trim() ?? '';
      if (grado.isNotEmpty) entry['grado'] = grado;
    }
    students.add(entry);
  }

  if (students.isEmpty) return 0;

  return FirestoreService.instance.insertManyStudents(students);
}
