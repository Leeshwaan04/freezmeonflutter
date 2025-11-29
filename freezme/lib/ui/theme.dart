import 'package:flutter/material.dart';

/// Central design tokens for consistent styling across the app.
class FreezmeColors {
  FreezmeColors._();

  static const Color primary = Color(0xFF6C4B9C);
  static const Color secondary = Color(0xFFC471ED);
  static const Color accent = Color(0xFFF64F59);
  static const Color neutral = Color(0xFF2D2D2D);
  static const Color muted = Color(0xFF8B7A9A);
  static const Color border = Color(0xFFE5D9ED);
  static const Color surface = Color(0xFFFFF5F8);
  static const Color surfaceAlt = Color(0xFFF5E6F0);
  static const Color background = Color(0xFFF6F0FF);
  static const Color success = Color(0xFFFF9A56);
  static const Color error = Color(0xFFD93F5B);
}

class FreezmeGradients {
  FreezmeGradients._();

  static const LinearGradient primary = LinearGradient(
    colors: [Color(0xFF6C4B9C), Color(0xFFF64F59)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accent = LinearGradient(
    colors: [FreezmeColors.secondary, FreezmeColors.accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundSoft = LinearGradient(
    colors: [FreezmeColors.surface, FreezmeColors.surfaceAlt],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glow = LinearGradient(
    colors: [FreezmeColors.secondary, Color(0xFFE7E9FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class FreezmeTypography {
  FreezmeTypography._();

  static const TextStyle display = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w700,
    color: FreezmeColors.neutral,
  );

  static const TextStyle title = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: FreezmeColors.neutral,
  );

  static const TextStyle subtitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: FreezmeColors.muted,
  );

  static const TextStyle body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: FreezmeColors.neutral,
  );

  static const TextStyle bodyMuted = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: FreezmeColors.muted,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: FreezmeColors.muted,
  );

  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    letterSpacing: 0.3,
  );
}

class FreezmeInsets {
  FreezmeInsets._();

  static const double pageGutter = 24;
  static const double cardRadius = 28;
  static const double elementSpacing = 16;
  static const double sectionSpacing = 24;
}

class FreezmeButtons {
  FreezmeButtons._();

  static final ButtonStyle primaryFilled = FilledButton.styleFrom(
    backgroundColor: FreezmeColors.primary,
    foregroundColor: Colors.white,
    textStyle: FreezmeTypography.button,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    minimumSize: const Size.fromHeight(52),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
  );

  static final ButtonStyle secondaryOutlined = OutlinedButton.styleFrom(
    foregroundColor: FreezmeColors.primary,
    textStyle: FreezmeTypography.button.copyWith(color: FreezmeColors.primary),
    side: const BorderSide(color: FreezmeColors.border),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    minimumSize: const Size.fromHeight(52),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
  );
}

class FreezmeTheme {
  FreezmeTheme._();

  static ThemeData build() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: FreezmeColors.primary,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: FreezmeColors.background,
      textTheme: Typography.blackCupertino,
    );

    return base.copyWith(
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: FreezmeButtons.primaryFilled,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FreezmeButtons.primaryFilled,
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: FreezmeButtons.secondaryOutlined,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: FreezmeColors.surface,
        labelStyle: FreezmeTypography.body,
        side: const BorderSide(color: FreezmeColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: FreezmeTypography.title,
        foregroundColor: FreezmeColors.neutral,
      ),
      cardTheme: base.cardTheme.copyWith(
        color: FreezmeColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FreezmeInsets.cardRadius),
        ),
      ),
    );
  }
}
