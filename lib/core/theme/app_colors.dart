import 'package:flutter/material.dart';

/// Brand and semantic color tokens.
///
/// UI code should prefer [Theme.of(context).colorScheme] and the semantic
/// colors exposed by `context.appColors`. These constants are intended for
/// feature identity, charts, and seeded theme creation.
abstract final class AppColors {
  static const primary = Color(0xFF4F46E5);
  static const secondary = Color(0xFF7C3AED);

  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFD97706);
  static const danger = Color(0xFFDC2626);
  static const info = Color(0xFF0284C7);

  static const expense = Color(0xFF6366F1);
  static const bills = Color(0xFF0EA5E9);
  static const grocery = Color(0xFF16A34A);
  static const loan = Color(0xFFEA580C);
  static const task = Color(0xFF7C3AED);
  static const habit = Color(0xFF059669);
  static const mood = Color(0xFFDB2777);
  static const invoice = Color(0xFF0369A1);
  static const pills = Color(0xFFDC2626);
}
