import 'package:flutter_test/flutter_test.dart';
import 'package:kiosco_app/services/date_utils.dart';

void main() {
  group('toISODate', () {
    test('formatea como yyyy-MM-dd', () {
      expect(toISODate(DateTime(2026, 10, 29)), '2026-10-29');
    });

    test('rellena mes y dia con cero', () {
      expect(toISODate(DateTime(2026, 1, 5)), '2026-01-05');
    });

    test('no incluye la hora aunque el DateTime la tenga', () {
      expect(toISODate(DateTime(2026, 10, 29, 23, 59, 59)), '2026-10-29');
    });

    test('maneja el 31 de diciembre', () {
      expect(toISODate(DateTime(2026, 12, 31)), '2026-12-31');
    });

    test('coincide con el formato que espera el servidor', () {
      // student_checkout compara p_date contra to_char(...::date, 'YYYY-MM-DD').
      final hoy = DateTime(2026, 3, 7);
      expect(RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(toISODate(hoy)), isTrue);
    });
  });
}
