import 'package:flutter/material.dart';

class R {
  R._();

  static double _scale(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return (w / 430).clamp(0.85, 1.15);
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
