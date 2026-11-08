import 'dart:ui';

extension ColorHex on Color {
  String toHex() => value.toRadixString(16).padLeft(8, '0');
}

Color? colorFromHex(String? hex) {
  if (hex == null) return null;
  return Color(int.parse(hex, radix: 16));
}
