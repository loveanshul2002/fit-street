import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFFFF6B6B); // coral
  static const Color secondary = Color(0xFF5F27CD); // purple

  static Gradient primaryGradient = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [primary, secondary],
  );
}
