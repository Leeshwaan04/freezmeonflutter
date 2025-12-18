import 'package:flutter/material.dart';

/// Central design tokens for consistent styling across the app.
class FreezmeColors {
  FreezmeColors._();

  /// Global low-motion flag; set true to tone down heavy gradients/shadows.
  static const bool lowMotion = false;

  static const Color primary = Color(0xFF4D2C91); // Richer Deep Purple
  static const Color secondary = Color(0xFF4D2C91); 
  static const Color accent = Color(0xFF7C3AED);
  static const Color neutral = Color(0xFF1F2937);
  static const Color muted = Color(0xFF6B7280);
  static const Color border = Color(0xFFE5E7EB);
  static const Color surface = Color(0xFFFAF9FF);
  static const Color surfaceAlt = Color(0xFFF5F3FF);
  static const Color background = Color(0xFFFFFFFF);
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);

  // Aliases for consistency
  static const Color text = neutral;
  static const Color textMuted = muted;
}

class FreezmeGradients {
  FreezmeGradients._();

  static const LinearGradient primary = LinearGradient(
    colors: [Color(0xFF4D2C91), Color(0xFF2E1A47)],
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

  static const LinearGradient buttonGradient = LinearGradient(
    colors: [FreezmeColors.primary, FreezmeColors.secondary],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
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
