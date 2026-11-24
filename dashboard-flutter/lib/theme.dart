import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta tomada de la imagen de referencia: fondo cálido, tarjetas blancas
/// y un único acento rojo coral.
class C {
  C._();

  static const bg = Color(0xFFE7E6E2);
  static const frame = Color(0xFFF3F2EF);
  static const card = Colors.white;
  static const accent = Color(0xFFF0453B);
  static const accentSoft = Color(0xFFFDE8E5);
  static const ink = Color(0xFF1B1B1D);
  static const muted = Color(0xFF8C8C92);
  static const line = Color(0xFFE9E7E3);
  static const ok = Color(0xFF2EA36A);
  static const warn = Color(0xFFE9A21B);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: C.accent).copyWith(
      primary: C.accent,
      surface: Colors.white,
    ),
    scaffoldBackgroundColor: C.bg,
  );
  return base.copyWith(
    textTheme: GoogleFonts.manropeTextTheme(base.textTheme).apply(
      bodyColor: C.ink,
      displayColor: C.ink,
    ),
  );
}
