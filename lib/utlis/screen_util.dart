import 'package:flutter/material.dart';

extension ScreenSizeExtension on BuildContext {
  double w(double percent) => MediaQuery.of(this).size.width * percent / 100;
  double h(double percent) => MediaQuery.of(this).size.height * percent / 100;
}

extension ScreenSize on BuildContext {
  double get width => MediaQuery.of(this).size.width;
  double get height => MediaQuery.of(this).size.height;
}
