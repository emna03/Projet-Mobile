import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Jetons graphiques locaux au module Quiz (charte StudyMate).
/// Conservés ici pour ne pas modifier `lib/core/`.
class QuizTokens {
  static const bg = Color(0xFFF4F2FF);
  static const card = Color(0xFFFFFFFF);
  static const primary = Color(0xFF4F46E5);
  static const ai = Color(0xFF6D28D9);
  static const aiSoft = Color(0xFFEDE7FB);
  static const accent = Color(0xFFF59E0B);
  static const success = Color(0xFF10B981);
  static const danger = Color(0xFFDC2626);
  static const text = Color(0xFF1E1B3A);
  static const muted = Color(0xFF5B5880);
  static const primarySoft = Color(0xFFE8E7FC);
  static const border = Color(0xFFE5E7EB);

  static const rCard = 24.0;
  static const rButton = 16.0;
  static const rBadge = 12.0;
  static const anim = Duration(milliseconds: 200);

  static List<BoxShadow> get shadow => [
        BoxShadow(
          color: primary.withValues(alpha: 0.10),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];

  static TextStyle heading(double size) => TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: text,
        height: 1.25,
      );

  static TextStyle body(
    double size, {
    Color? color,
    FontWeight weight = FontWeight.w400,
  }) =>
      TextStyle(
        fontSize: size,
        fontWeight: weight,
        color: color ?? text,
        height: 1.4,
      );
}

ThemeData buildQuizTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: QuizTokens.primary,
      primary: QuizTokens.primary,
    ),
  );
  return base.copyWith(
    scaffoldBackgroundColor: QuizTokens.bg,
    appBarTheme: AppBarTheme(
      backgroundColor: QuizTokens.bg,
      foregroundColor: QuizTokens.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: QuizTokens.heading(18),
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    ),
    textTheme: base.textTheme.apply(
      bodyColor: QuizTokens.text,
      displayColor: QuizTokens.text,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: QuizTokens.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(QuizTokens.rButton),
        ),
        textStyle: QuizTokens.body(16, weight: FontWeight.w600, color: Colors.white),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: QuizTokens.text,
        minimumSize: const Size(44, 48),
        side: const BorderSide(color: QuizTokens.primarySoft, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(QuizTokens.rButton),
        ),
      ),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: QuizTokens.ai,
      thumbColor: QuizTokens.ai,
      inactiveTrackColor: QuizTokens.aiSoft,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      hintStyle: QuizTokens.body(14, color: QuizTokens.muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(QuizTokens.rButton),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(QuizTokens.rButton),
        borderSide: const BorderSide(color: QuizTokens.primary, width: 2),
      ),
    ),
  );
}
