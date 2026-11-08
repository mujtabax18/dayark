import 'package:flutter/material.dart';

abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
}

abstract final class AppRadius {
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 24;
  static const double sheet = 28;

  static BorderRadius get small => BorderRadius.circular(sm);
  static BorderRadius get medium => BorderRadius.circular(md);
  static BorderRadius get large => BorderRadius.circular(lg);
  static BorderRadius get extraLarge => BorderRadius.circular(xl);
}

abstract final class AppDuration {
  static const fast = Duration(milliseconds: 160);
  static const normal = Duration(milliseconds: 240);
  static const slow = Duration(milliseconds: 360);
}

abstract final class AppConstraints {
  // Kept for existing narrow forms/dialogs.
  static const double maxContentWidth = 760;

  // Main dashboard/section width on tablet and desktop.
  static const double maxDesktopContentWidth = 1280;
  static const double minTapTarget = 48;
}
