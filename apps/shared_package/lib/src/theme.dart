import 'package:flutter/material.dart';

/// Neev's original palette. Ink and deep green carry the brand; amber is used
/// only for fare and attention moments, never for safety-critical actions.
class NeevColors {
  static const ink = Color(0xFF10201D);
  static const inkSoft = Color(0xFF2A3D38);
  static const green = Color(0xFF0E4F45);
  static const greenDeep = Color(0xFF083A33);
  static const greenSoft = Color(0xFFDDEBE6);
  static const amber = Color(0xFFF2B544);
  static const amberSoft = Color(0xFFFDF0D2);
  static const cream = Color(0xFFF7F5EF);
  static const surface = Color(0xFFFFFFFF);
  static const line = Color(0xFFE2E0D8);
  static const muted = Color(0xFF6B7A75);
  static const success = Color(0xFF167A5B);
  static const danger = Color(0xFFB3261E);
  static const dangerSoft = Color(0xFFF9E3E1);
  static const info = Color(0xFF22577A);
  static const infoSoft = Color(0xFFE3EEF5);
}

class NeevTheme {
  static ThemeData build() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: 'Roboto',
    );
    final scheme = ColorScheme.fromSeed(
      seedColor: NeevColors.green,
      brightness: Brightness.light,
    ).copyWith(
      primary: NeevColors.green,
      onPrimary: Colors.white,
      secondary: NeevColors.amber,
      onSecondary: NeevColors.ink,
      surface: NeevColors.surface,
      onSurface: NeevColors.ink,
      error: NeevColors.danger,
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: NeevColors.cream,
      textTheme: base.textTheme
          .apply(bodyColor: NeevColors.ink, displayColor: NeevColors.ink)
          .copyWith(
            displaySmall: const TextStyle(
              fontSize: 32,
              height: 1.1,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
              color: NeevColors.ink,
            ),
            headlineMedium: const TextStyle(
              fontSize: 24,
              height: 1.2,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: NeevColors.ink,
            ),
            titleLarge: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: NeevColors.ink,
            ),
            titleMedium: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: NeevColors.ink,
            ),
            bodyMedium: const TextStyle(
              fontSize: 14,
              height: 1.45,
              color: NeevColors.inkSoft,
            ),
            labelLarge: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
          ),
      appBarTheme: const AppBarTheme(
        backgroundColor: NeevColors.cream,
        foregroundColor: NeevColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w800,
          color: NeevColors.ink,
        ),
      ),
      cardTheme: CardThemeData(
        color: NeevColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: NeevColors.line),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: NeevColors.line,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: NeevColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: const TextStyle(color: NeevColors.muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: NeevColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: NeevColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: NeevColors.green, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: NeevColors.danger),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: NeevColors.green,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: NeevColors.green,
          minimumSize: const Size(0, 50),
          side: const BorderSide(color: NeevColors.green),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: NeevColors.green,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: NeevColors.greenSoft,
        labelStyle: const TextStyle(
          color: NeevColors.greenDeep,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: NeevColors.surface,
        indicatorColor: NeevColors.greenSoft,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.all(const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: NeevColors.inkSoft,
        )),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              size: 23,
              color: states.contains(WidgetState.selected)
                  ? NeevColors.green
                  : NeevColors.muted,
            )),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: NeevColors.ink,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: NeevColors.green),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: NeevColors.cream,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: NeevColors.cream,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
    );
  }
}
