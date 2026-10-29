import 'package:flutter_test/flutter_test.dart';
import 'package:kiosco_app/services/recreo_schedule.dart';

DateTime at(int hour, int minute) => DateTime(2026, 10, 29, hour, minute);

void main() {
  group('configuracion de ventanas', () {
    test('hay tres ventanas en orden', () {
      expect(
        RecreoSchedule.windows.map((w) => w.name).toList(),
        ['Recreo 1', 'Recreo 2', 'Salida'],
      );
    });

    test('los horarios coinciden con el kiosco', () {
      final r1 = RecreoSchedule.windows[0];
      expect([r1.startHour, r1.startMinute, r1.endHour, r1.endMinute], [10, 0, 10, 20]);

      final r2 = RecreoSchedule.windows[1];
      expect([r2.startHour, r2.startMinute, r2.endHour, r2.endMinute], [12, 20, 12, 40]);

      final salida = RecreoSchedule.windows[2];
      expect([salida.startHour, salida.startMinute, salida.endHour, salida.endMinute], [14, 0, 15, 0]);
    });
  });

  group('isOpen', () {
    final r1 = RecreoSchedule.windows[0];

    test('abre en el minuto exacto de inicio', () {
      expect(r1.isOpen(at(10, 0)), isTrue);
    });

    test('sigue abierto un minuto antes del cierre', () {
      expect(r1.isOpen(at(10, 19)), isTrue);
    });

    test('cerrado en el minuto de cierre', () {
      expect(r1.isOpen(at(10, 20)), isFalse);
    });

    test('cerrado antes de abrir', () {
      expect(r1.isOpen(at(9, 0)), isFalse);
    });
  });

  group('isLocked (no se reciben pedidos 20 min antes)', () {
    final r1 = RecreoSchedule.windows[0];

    test('no bloqueado antes de las 09:40', () {
      expect(r1.isLocked(at(9, 39)), isFalse);
    });

    test('bloqueado desde las 09:40', () {
      expect(r1.isLocked(at(9, 40)), isTrue);
    });

    test('bloqueado durante la ventana', () {
      expect(r1.isLocked(at(10, 10)), isTrue);
    });

    test('deja de estar bloqueado cuando la ventana termina', () {
      expect(r1.isLocked(at(10, 30)), isFalse);
    });
  });

  group('hasEnded / isAvailable', () {
    final r1 = RecreoSchedule.windows[0];
    final r2 = RecreoSchedule.windows[1];

    test('una ventana pasada ya termino', () {
      expect(r1.hasEnded(at(11, 17)), isTrue);
    });

    test('una ventana futura no termino', () {
      expect(r2.hasEnded(at(11, 17)), isFalse);
    });

    test('una ventana pasada no esta disponible', () {
      expect(r1.isAvailable(at(11, 17)), isFalse);
    });

    test('la proxima ventana si esta disponible', () {
      expect(r2.isAvailable(at(11, 17)), isTrue);
    });

    test('no disponible si ya se bloquearon los pedidos', () {
      expect(r1.isAvailable(at(9, 45)), isFalse);
    });

    test('disponible antes del bloqueo', () {
      expect(r1.isAvailable(at(9, 0)), isTrue);
    });
  });

  group('estado del kiosco', () {
    test('getCurrentRecreo dentro de una ventana', () {
      expect(RecreoSchedule.getCurrentRecreo(at(10, 5)), 'Recreo 1');
      expect(RecreoSchedule.getCurrentRecreo(at(12, 25)), 'Recreo 2');
    });

    test('getCurrentRecreo fuera de ventana', () {
      expect(RecreoSchedule.getCurrentRecreo(at(11, 17)), 'Fuera de recreo');
    });

    test('getNextAvailable salta la ventana que ya paso', () {
      expect(RecreoSchedule.getNextAvailable(at(11, 17))?.name, 'Recreo 2');
    });

    test('getAvailableWindows no ofrece ventanas pasadas', () {
      final disponibles =
          RecreoSchedule.getAvailableWindows(at(11, 17)).map((w) => w.name).toList();
      expect(disponibles, ['Recreo 2', 'Salida']);
    });

    test('canOrderNow es falso cuando todas las ventanas pasaron', () {
      expect(RecreoSchedule.canOrderNow(at(16, 0)), isFalse);
    });

    test('canOrderNow es verdadero durante una ventana abierta', () {
      expect(RecreoSchedule.canOrderNow(at(10, 5)), isTrue);
    });
  });
}
