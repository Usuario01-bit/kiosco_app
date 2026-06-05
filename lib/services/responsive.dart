import 'package:flutter/material.dart';

String formatTime(String? time) {
  if (time == null || time.isEmpty) return '';
  final parts = time.split(':');
  if (parts.length < 2) return time;
  final h = int.tryParse(parts[0]) ?? 0;
  final m = parts[1];
  final period = h >= 12 ? 'PM' : 'AM';
  final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
  return '$h12:$m $period';
}

class R {
  R._();

  static double _scale(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w / 430;
  }

  static double fs(BuildContext context, double size) {
    return size * _scale(context);
  }

  static double sp(BuildContext context, double value) {
    return value * _scale(context);
  }

  static double sw(BuildContext context, double fraction) {
    return MediaQuery.sizeOf(context).width * fraction;
  }

  static double sh(BuildContext context, double fraction) {
    return MediaQuery.sizeOf(context).height * fraction;
  }
}
