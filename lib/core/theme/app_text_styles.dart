import 'package:flutter/material.dart';

/// Color-free typography presets. Colors come from the active ThemeData.
abstract final class AppTextStyles {
  static const pageTitle = TextStyle(
    fontSize: 24,
    height: 1.2,
    fontWeight: FontWeight.w800,
    letterSpacing: -.3,
  );

  static const sectionTitle = TextStyle(
    fontSize: 16,
    height: 1.3,
    fontWeight: FontWeight.w800,
  );

  static const cardTitle = TextStyle(
    fontSize: 15,
    height: 1.3,
    fontWeight: FontWeight.w700,
  );

  static const body = TextStyle(fontSize: 14, height: 1.45);
  static const caption = TextStyle(fontSize: 12, height: 1.35);
  static const button = TextStyle(fontSize: 14, fontWeight: FontWeight.w800);
}
