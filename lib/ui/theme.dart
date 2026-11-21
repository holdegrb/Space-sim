import 'package:flutter/material.dart';

/// All colours in one place.
abstract final class SpaceColors {
  static const bg = Color(0xFF070B16);
  static const panel = Color(0xFF111A2E);
  static const panelHigh = Color(0xFF1A2642);
  static const text = Color(0xFFE6ECFF);
  static const muted = Color(0xFF8C9BC4);
  static const accent = Color(0xFF4FD1FF); // player, lasers, buttons
  static const shield = Color(0xFF7AA8FF);
  static const hull = Color(0xFF5BE38F);
  static const enemy = Color(0xFFFF5A5A);
  static const boss = Color(0xFFFF9F1C);
  static const credits = Color(0xFFFFD166);
}

ThemeData buildTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: SpaceColors.accent,
        brightness: Brightness.dark,
      ).copyWith(
        surface: SpaceColors.panel,
        primary: SpaceColors.accent,
        onPrimary: Colors.black,
      );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: SpaceColors.bg,
    useMaterial3: true,
  );
}
