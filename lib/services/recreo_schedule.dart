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
      final lock = w.getLockTimeToday(now);
      if (!now.isAfter(lock)) return w;
      if (w.isOpen(now) || w.isLocked(now)) continue;
      return w;
    }
    return null;
  }

  static bool canOrderNow(DateTime now) {
    for (final w in windows) {
      if (w.isOpen(now)) return true;
      if (w.isLocked(now)) return false;
    }
    return true;
  }

  static List<RecreoWindow> getAvailableWindows(DateTime now) {
    final available = <RecreoWindow>[];
    for (final w in windows) {
      if (w.isOpen(now)) {
        available.add(w);
      } else if (!w.isLocked(now)) {
        available.add(w);
      }
    }
    return available;
  }

  static List<RecreoWindow> getOpenWindows(DateTime now) {
    return windows.where((w) => w.isOpen(now)).toList();
  }
}
