class RecreoWindow {
  final String name;
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;

  const RecreoWindow({
    required this.name,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
  });

  DateTime getStartToday(DateTime now) => DateTime(now.year, now.month, now.day, startHour, startMinute);
  DateTime getEndToday(DateTime now) => DateTime(now.year, now.month, now.day, endHour, endMinute);
  DateTime getLockTimeToday(DateTime now) => getStartToday(now).subtract(const Duration(minutes: 20));

  /// Franja general en la que el kiosco recibe pedidos. Es un limite
  /// externo: fuera de estas horas no se toma ningun pedido, aunque la
  /// ventana todavia no haya empezado.
  static const int orderOpenHour = 6;
  static const int orderOpenMinute = 0;
  static const int orderCloseHour = 13;
  static const int orderCloseMinute = 40;

  static String get orderHoursLabel =>
      '$orderOpenHour:${orderOpenMinute.toString().padLeft(2, '0')} a '
      '$orderCloseHour:${orderCloseMinute.toString().padLeft(2, '0')}';

  static bool isWithinOrderHours(DateTime now) {
    final open = DateTime(now.year, now.month, now.day, orderOpenHour, orderOpenMinute);
    final close = DateTime(now.year, now.month, now.day, orderCloseHour, orderCloseMinute);
    return !now.isBefore(open) && now.isBefore(close);
  }

  bool isOpen(DateTime now) {
    final start = getStartToday(now);
    final end = getEndToday(now);
    return !now.isBefore(start) && now.isBefore(end);
  }

  bool isLocked(DateTime now) {
    final lock = getLockTimeToday(now);
    final end = getEndToday(now);
    return !now.isBefore(lock) && now.isBefore(end);
  }

  /// La ventana ya cerro: pedir para ella no tiene sentido porque el
  /// kiosco no llega a prepararlo.
  bool hasEnded(DateTime now) => !now.isBefore(getEndToday(now));

  /// Se puede pedir para esta ventana: estamos dentro del horario general
  /// de pedidos, no cerro todavia y no se bloquearon los pedidos
  /// (el bloqueo arranca 20 min antes).
  bool isAvailable(DateTime now) =>
      isWithinOrderHours(now) && !hasEnded(now) && !isLocked(now);

  Duration timeUntilOpen(DateTime now) {
    final start = getStartToday(now);
    return start.difference(now);
  }
}

class RecreoSchedule {
  RecreoSchedule._();

  static final instance = RecreoSchedule._();

  static const int lockoutMinutes = 20;

  static const List<RecreoWindow> windows = [
    RecreoWindow(name: 'Recreo 1', startHour: 10, startMinute: 0, endHour: 10, endMinute: 20),
    RecreoWindow(name: 'Recreo 2', startHour: 12, startMinute: 20, endHour: 12, endMinute: 40),
    RecreoWindow(name: 'Salida', startHour: 14, startMinute: 0, endHour: 15, endMinute: 0),
  ];

  static RecreoWindow? getActiveWindow(DateTime now) {
    for (final w in windows) {
      if (w.isOpen(now)) return w;
    }
    return null;
  }

  static String getCurrentRecreo(DateTime now) {
    final active = getActiveWindow(now);
    if (active != null) return active.name;
    return 'Fuera de recreo';
  }

  static RecreoWindow? getNextAvailable(DateTime now) {
    for (final w in windows) {
      if (w.isAvailable(now)) return w;
    }
    return null;
  }

  /// Verdadero si queda al menos una ventana para la que se pueda
  /// pedir. Una ventana que ya paso no cuenta.
  static bool canOrderNow(DateTime now) {
    return windows.any((w) => w.isAvailable(now));
  }

  static List<RecreoWindow> getAvailableWindows(DateTime now) {
    return windows.where((w) => w.isAvailable(now)).toList();
  }

  static List<RecreoWindow> getOpenWindows(DateTime now) {
    return windows.where((w) => w.isOpen(now)).toList();
  }
}
