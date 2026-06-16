import 'dart:io';
import 'package:excel/excel.dart';

void main() {
  var bytes = File('807b4f5ae_listadeestudiantes.xlsx').readAsBytesSync();
  var excel = Excel.decodeBytes(bytes);
  var sheet = excel.tables.keys.first;
  var rows = excel.tables[sheet]!.rows;

  // Sort by grade (column index 4, 0-based)
  var dataRows = rows.sublist(1);
  dataRows.sort((a, b) {
    var ga = a.length > 4 ? (a[4]?.value?.toString().trim() ?? '') : '';
    var gb = b.length > 4 ? (b[4]?.value?.toString().trim() ?? '') : '';
    var na = int.tryParse(ga) ?? 999;
    var nb = int.tryParse(gb) ?? 999;
    return na.compareTo(nb);
  });

  print('BEGIN;');
  for (var row in dataRows) {
    var parts = <String>[];
    for (var j = 0; j < 4 && j < row.length; j++) {
      var v = row[j]?.value?.toString().trim() ?? '';
      if (v.isNotEmpty) parts.add(v);
    }
    var name = parts.join(' ');
    var grado = row.length > 4 ? row[4]?.value?.toString().trim() ?? '' : '';
    if (name.isNotEmpty && grado.isNotEmpty) {
      var nameEscaped = name.replaceAll("'", "''");
      var gradoEscaped = grado.replaceAll("'", "''");
      print("UPDATE students SET grade = '$gradoEscaped' WHERE name = '$nameEscaped';");
    }
  }
  print('COMMIT;');
  print('');
  print('-- Total students with grade: ${dataRows.where((r) => r.length > 4 && (r[4]?.value?.toString().trim() ?? '').isNotEmpty).length}');
}
