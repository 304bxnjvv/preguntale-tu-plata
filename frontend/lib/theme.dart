import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Sistema de diseño "confidente premium que habla en chileno" (ver DESIGN.md).
/// Dark cálido por defecto. Display = Clash Display (asset). Texto = Plus Jakarta Sans.
class AppColors {
  static const bg = Color(0xFF15131F); // tinta nocturna (violeta/cálido, NO dev-dark)
  static const surface = Color(0xFF1E1B2B); // cards
  static const primary = Color(0xFF6C5CE7); // índigo conversación / IA / CTA
  static const accent = Color(0xFFF4B860); // ámbar confianza
  static const positive = Color(0xFF7FB496); // verde salvia (montos OK, apagado)
  static const negative = Color(0xFFE8836B); // salmón (gastos, NUNCA rojo)
  static const text = Color(0xFFF5F2EC); // blanco roto (cálido)
  static const textMuted = Color(0xFFA59FB5); // lila grisáceo
  static const border = Color(0x1AFFFFFF); // white 10%
  static const glass = Color(0x0DFFFFFF); // white 5%
  static const onPrimary = Color(0xFFF5F2EC);
}

const _tabular = [FontFeature.tabularFigures()];

class AppText {
  /// Display / títulos — Clash Display.
  static TextStyle display(double size, {FontWeight weight = FontWeight.w600, Color? color}) =>
      TextStyle(
        fontFamily: 'ClashDisplay',
        fontSize: size,
        fontWeight: weight,
        color: color ?? AppColors.text,
        height: 1.05,
      );

  /// Montos — Clash Display con cifras tabulares.
  static TextStyle amount(double size, {FontWeight weight = FontWeight.w700, Color? color}) =>
      TextStyle(
        fontFamily: 'ClashDisplay',
        fontSize: size,
        fontWeight: weight,
        color: color ?? AppColors.text,
        fontFeatures: _tabular,
        height: 1.0,
      );

  /// Texto / chat / UI — Plus Jakarta Sans.
  static TextStyle body(double size, {FontWeight weight = FontWeight.w400, Color? color}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: size,
        fontWeight: weight,
        color: color ?? AppColors.text,
        height: 1.45,
        fontFeatures: _tabular,
      );

  /// Label de categoría — mayúsculas, tracking.
  static TextStyle label(Color? color) => GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.6,
        color: color ?? AppColors.textMuted,
      );
}

/// Formato de monto chileno: 1234567 -> "$1.234.567" (punto de miles, sin decimales).
String formatCLP(num monto, {bool conSigno = false}) {
  final neg = monto < 0;
  final abs = monto.abs().round().toString();
  final buf = StringBuffer();
  for (var i = 0; i < abs.length; i++) {
    if (i > 0 && (abs.length - i) % 3 == 0) buf.write('.');
    buf.write(abs[i]);
  }
  final signo = conSigno ? (neg ? '-' : '+') : (neg ? '-' : '');
  return '$signo\$${buf.toString()}';
}

ThemeData buildAppTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: const ColorScheme.dark(
      surface: AppColors.surface,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      secondary: AppColors.accent,
      error: AppColors.negative,
      onSurface: AppColors.text,
    ),
    textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      elevation: 0,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      hintStyle: AppText.body(15, color: AppColors.textMuted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 16),
        padding: const EdgeInsets.symmetric(vertical: 16),
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );
}
