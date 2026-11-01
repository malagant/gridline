import 'package:flutter/material.dart';

/// Eigenes Farbschema von Gridline: dunkles Tintenblau mit Mint-Akzent.
abstract final class GridTheme {
  static const background = Color(0xFF121419);
  static const panel = Color(0xFF1A1C24);
  static const beatRow = Color(0xFF1F212B);
  static const barRow = Color(0xFF262936);
  static const accent = Color(0xFF5CE0B5);
  static const cursor = Color(0xFFFABB4A);
  static const text = Color(0xFFDBDBDB);
  static const dim = Color(0xFF616161);
  static const playhead = Color(0x385CE0B5);

  static const mono = TextStyle(fontFamily: 'monospace', fontSize: 13, color: text, height: 1.0);
  static final monoBold = mono.copyWith(fontWeight: FontWeight.w600);

  static ThemeData material() {
    final base = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.dark,
        primary: accent,
        surface: panel,
      ),
      scaffoldBackgroundColor: background,
    );
    return base.copyWith(
      sliderTheme: base.sliderTheme.copyWith(trackHeight: 3),
      dividerTheme: const DividerThemeData(color: Color(0xFF2A2D38), space: 1, thickness: 1),
    );
  }
}
