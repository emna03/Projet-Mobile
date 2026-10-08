import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Jetons de la charte StudyMate.
class SM {
  static const bg = Color(0xFFF4F2FF);
  static const card = Colors.white;
  static const primary = Color(0xFF4F46E5);
  static const ai = Color(0xFF6D28D9);
  static const aiSoft = Color(0xFFEDE7FB);
  static const accent = Color(0xFFF59E0B);
  static const success = Color(0xFF10B981);
  static const danger = Color(0xFFDC2626);
  static const text = Color(0xFF1E1B3A);
  static const muted = Color(0xFF5B5880);
  static const primarySoft = Color(0xFFE8E7FC);
  static const surface = Colors.white;
  static const border = Color(0xFFE5E7EB);

  static const rCard = 24.0;
  static const rButton = 16.0;
  static const rBadge = 12.0;
  static const anim = Duration(milliseconds: 200);

  static List<BoxShadow> shadow = [
    BoxShadow(color: primary.withValues(alpha: 0.10), blurRadius: 24, offset: const Offset(0, 8)),
  ];

  static TextStyle h(double size) =>
      GoogleFonts.poppins(fontSize: size, fontWeight: FontWeight.w600, color: text);
  static TextStyle b(double size, {Color color = text, FontWeight w = FontWeight.w400}) =>
      GoogleFonts.dmSans(fontSize: size, color: color, fontWeight: w);
}

ThemeData buildTheme() {
  final base = ThemeData(useMaterial3: true, colorSchemeSeed: SM.primary);
  return base.copyWith(
    scaffoldBackgroundColor: SM.bg,
    textTheme: GoogleFonts.dmSansTextTheme(base.textTheme)
        .apply(bodyColor: SM.text, displayColor: SM.text),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: SM.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SM.rButton)),
        textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w600, fontSize: 16),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: SM.text,
        minimumSize: const Size(44, 48),
        side: const BorderSide(color: SM.primarySoft, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SM.rButton)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SM.rButton), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SM.rButton),
          borderSide: const BorderSide(color: SM.primary, width: 2)),
    ),
  );
}
