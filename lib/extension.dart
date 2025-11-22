import 'package:flutter/material.dart';

extension HexColor on Color {
  /// Prefixes a hash sign if [leadingHashSign] is set to `true` (default is `true`).
  String toHex({bool leadingHashSign = true}) {
    // Ensure the alpha component is included for a full ARGB hex string
    String red = (r * 255.0).round().toRadixString(16).padLeft(2, '0');
    String green = (g * 255.0).round().toRadixString(16).padLeft(2, '0');
    String blue = (b * 255.0).round().toRadixString(16).padLeft(2, '0');

    return '${leadingHashSign ? '#' : ''}'
        '$red'
        '$green'
        '$blue';
  }
}
