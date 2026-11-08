import 'package:flutter/widgets.dart';

extension GapExtensions on num {
  // Horizontal gap
  SizedBox get h => SizedBox(width: toDouble());

  // Vertical gap
  SizedBox get v => SizedBox(height: toDouble());
}
