import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'firestore_service.dart';

Future<void> exportPendingToExcel(BuildContext context) async {
  final data = await FirestoreService.instance.getAllPendingSales();

  if (data.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay deudas pendientes para exportar')),
      );
    }
    return;
  }

  final excel = Excel.createExcel();
  final sheet = excel['Deudores'];

  // ── STYLES ──
  final titleStyle = CellStyle(
    bold: true,
    fontSize: 16,
    fontColorHex: ExcelColor.fromHexString('1A1A2E'),
  );
  final headerStyle = CellStyle(
    bold: true,
    fontSize: 11,
    fontColorHex: ExcelColor.white,
    backgroundColorHex: ExcelColor.fromHexString('4A90E2'),
  );
  final groupStyle = CellStyle(
    bold: true,
    fontSize: 12,
    fontColorHex: ExcelColor.fromHexString('1A1A2E'),
    backgroundColorHex: ExcelColor.fromHexString('E8F0FE'),
  );
  final subtotalStyle = CellStyle(
    bold: true,
    fontSize: 11,
    fontColorHex: ExcelColor.fromHexString('2563EB'),
  );
  final grandTotalStyle = CellStyle(
    bold: true,
    fontSize: 13,
    fontColorHex: ExcelColor.white,
    backgroundColorHex: ExcelColor.fromHexString('1A1A2E'),
  );

  void setCell(String cell, dynamic value, [CellStyle? style]) {
    final c = sheet.cell(CellIndex.indexByString(cell));
    if (value is String) {
      c.value = TextCellValue(value);
    } else if (value is double) {
      c.value = TextCellValue('\$${value.toStringAsFixed(2)}');
    } else if (value is int) {
      c.value = IntCellValue(value);
    }
    if (style != null) c.cellStyle = style;
  }

  // ── ROW 1: TITLE ──
  setCell('A1', 'REPORTE DE DEUDORES', titleStyle);
  sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('G1'));

  // ── ROW 2: DATE ──
  final now = DateTime.now();
  final dateStr = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
  setCell('A2', 'Generado: $dateStr', CellStyle(fontSize: 10, fontColorHex: ExcelColor.fromHexString('666666')));
  sheet.merge(CellIndex.indexByString('A2'), CellIndex.indexByString('G2'));

  // ── ROW 4: HEADERS ──
  setCell('A4', 'Estudiante', headerStyle);
  setCell('B4', 'Producto', headerStyle);
  setCell('C4', 'Cant.', headerStyle);
  setCell('D4', 'Precio', headerStyle);
  setCell('E4', 'Total', headerStyle);
  setCell('F4', 'Fecha', headerStyle);
  setCell('G4', 'Hora', headerStyle);

  // ── SET COLUMN WIDTHS ──
  sheet.setColumnWidth(1, 20);
  sheet.setColumnWidth(2, 25);
  sheet.setColumnWidth(3, 8);
  sheet.setColumnWidth(4, 12);
  sheet.setColumnWidth(5, 12);
  sheet.setColumnWidth(6, 14);
  sheet.setColumnWidth(7, 10);

  // ── DATA ──
  int row = 5;
  String? currentStudent;
  double studentSubtotal = 0;
  double grandTotal = 0;


  for (int i = 0; i < data.length; i++) {
    final sale = data[i];
    final student = sale['student'] as String? ?? '';
    final product = sale['product'] as String? ?? '';
    final quantity = (sale['quantity'] as num?)?.toInt() ?? 1;
    final total = (sale['total'] as num?)?.toDouble() ?? 0;
    final date = sale['date'] as String? ?? '';
    final time = sale['time'] as String? ?? '';
    final unitPrice = quantity > 0 ? total / quantity : total;

    if (student != currentStudent) {
      if (currentStudent != null) {
        // Subtotal row for previous student
        setCell('D$row', '', subtotalStyle);
        setCell('E$row', studentSubtotal, subtotalStyle);
        row++;
      }
      studentSubtotal = 0;

      // Student name row
      setCell('A$row', student.toUpperCase(), groupStyle);
      sheet.merge(CellIndex.indexByString('A$row'), CellIndex.indexByString('G$row'));
      row++;
      currentStudent = student;
    }

    // Product row
    setCell('A$row', '');
    setCell('B$row', product);
    setCell('C$row', quantity);
    setCell('D$row', unitPrice);
    setCell('E$row', total);
    setCell('F$row', date);
    setCell('G$row', time);

    studentSubtotal += total;
    grandTotal += total;
    row++;
  }

  // Last student subtotal
  setCell('D$row', '', subtotalStyle);
  setCell('E$row', studentSubtotal, subtotalStyle);
  row++;

  // ── GRAND TOTAL ──
  row++;
  setCell('A$row', 'TOTAL GENERAL', grandTotalStyle);
  sheet.merge(CellIndex.indexByString('A$row'), CellIndex.indexByString('D$row'));
  setCell('E$row', grandTotal, grandTotalStyle);

  // ── SAVE & SHARE ──
  final fileBytes = excel.save();
  if (fileBytes == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al generar el archivo')),
      );
    }
    return;
  }

  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/Deudores_${now.day}_${now.month}_$now.xlsx');
  await file.writeAsBytes(fileBytes);

  if (context.mounted) {
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Reporte de Deudores - Kiosco Escolar',
    );
  }
}
