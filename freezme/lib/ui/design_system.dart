import 'package:flutter/material.dart';

/// Freezme Design System
/// Clean, frozen creamy theme - soft and consistent across all pages

class FreezmeDesignSystem {
  FreezmeDesignSystem._();

  // ============================================================================
  // COLOR PALETTE - Frozen Creamy Theme (Soft, Consistent)
  // ============================================================================
  
  // Primary - Soft purple (main brand color)
  static const Color primary = Color(0xFF6C4B9C); // Deeper Purple (Logo Match)
  static const Color primaryLight = Color(0xFFF0EBF8); // Lighter tint
  static const Color primaryDark = Color(0xFF4A306D); // Darker shade
  
  // Secondary - Soft pink (accent)
  static const Color secondary = Color(0xFFEC4899);
  static const Color secondaryLight = Color(0xFFFCE7F3); // Very soft pink
  static const Color secondaryDark = Color(0xFFBE185D);
  
  // Accent - Warm tone
  static const Color accent = Color(0xFFF59E0B);
  static const Color accentLight = Color(0xFFFEF3C7);
  static const Color accentDark = Color(0xFFD97706);
  
  // Semantic colors (kept simple)
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);
  
  // Surfaces - Cream/soft whites
  static const Color surface = Color(0xFFFAF9FF); // Creamy white with slight purple tint
  static const Color surfaceAlt = Color(0xFFF5F3FF); // Slightly more purple
  static const Color surfaceContrast = Color(0xFF1F2937);
  static const Color background = Color(0xFFFFFFFF);
  static const Color backgroundDark = Color(0xFF1F2937);
  
  // Text - Clean grays
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color textDisabled = Color(0xFFD1D5DB);
  
  // Borders - Very subtle
  static const Color border = Color(0xFFE5E7EB);
  static const Color borderLight = Color(0xFFF3F4F6);
  static const Color borderDark = Color(0xFF9CA3AF);
  
  static const Color overlay = Color(0x80000000);
  static const Color shimmer = Color(0xFFE5E7EB);

  // ============================================================================
  // TYPOGRAPHY
  // ============================================================================
  
  static const String fontFamily = 'Inter';
  
  static const TextStyle display = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.5,
    color: textPrimary,
  );
  
  static const TextStyle h1 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.3,
    letterSpacing: -0.3,
    color: textPrimary,
  );
  
  static const TextStyle h2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: -0.2,
    color: textPrimary,
  );
  
  static const TextStyle h3 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: textPrimary,
  );
  
  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: textPrimary,
  );
  
  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.5,
    color: textPrimary,
  );
  
  static const TextStyle bodySemiBold = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.5,
    color: textPrimary,
  );
  
  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: textSecondary,
  );
  
  static const TextStyle captionMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: textSecondary,
  );
  
  static const TextStyle small = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.3,
    color: textSecondary,
  );
  
  static const TextStyle smallMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.3,
    color: textSecondary,
  );
  
  static const TextStyle button = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.2,
  );
  
  static const TextStyle buttonSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.2,
  );

  // ============================================================================
  // SPACING
  // ============================================================================
  
  static const double spaceXs = 4.0;
  static const double spaceSm = 8.0;
  static const double spaceMd = 16.0;
  static const double spaceLg = 24.0;
  static const double spaceXl = 32.0;
  static const double spaceXxl = 48.0;

  // ============================================================================
  // BORDER RADIUS
  // ============================================================================
  
  static const double radiusXs = 4.0;
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 20.0;
  static const double radiusXxl = 24.0;
  static const double radiusFull = 9999.0;

  // ============================================================================
  // ELEVATION (SHADOWS)
  // ============================================================================
  
  static List<BoxShadow> get shadowSm => [
    BoxShadow(
      color: textPrimary.withValues(alpha: 0.03),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];
  
  static List<BoxShadow> get shadowMd => [
    BoxShadow(
      color: textPrimary.withValues(alpha: 0.05),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];
  
  static List<BoxShadow> get shadowLg => [
    BoxShadow(
      color: textPrimary.withValues(alpha: 0.08),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ];
  
  static List<BoxShadow> get shadowXl => [
    BoxShadow(
      color: textPrimary.withValues(alpha: 0.1),
      blurRadius: 24,
      offset: const Offset(0, 12),
    ),
  ];

  // ============================================================================
  // DURATIONS (ANIMATIONS)
  // ============================================================================
  
  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationNormal = Duration(milliseconds: 300);
  static const Duration durationSlow = Duration(milliseconds: 500);

  // ============================================================================
  // Z-INDEX (LAYERING)
  // ============================================================================
  
  static const int zBase = 0;
  static const int zOverlay = 10;
  static const int zModal = 20;
  static const int zPopup = 30;
  static const int zTooltip = 40;
  static const int zNotification = 50;

  // ============================================================================
  // COMMON DECORATIONS - Simple, consistent styling
  // ============================================================================
  
  /// Standard card - clean with subtle border and light shadow
  static BoxDecoration get cardDecoration => BoxDecoration(
    color: background,
    borderRadius: BorderRadius.circular(radiusLg),
    border: Border.all(color: border, width: 1),
    boxShadow: shadowSm,
  );
  
  /// Flat card - no shadow
  static BoxDecoration get cardDecorationFlat => BoxDecoration(
    color: background,
    borderRadius: BorderRadius.circular(radiusLg),
    border: Border.all(color: border, width: 1),
  );
  
  /// Soft card - creamy background
  static BoxDecoration get cardDecorationSoft => BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(radiusLg),
  );
  
  /// Pill decoration for tags/badges
  static BoxDecoration get pillDecoration => BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(radiusFull),
    border: Border.all(color: border, width: 1),
  );
  
  /// Pill with primary accent
  static BoxDecoration get pillDecorationPrimary => BoxDecoration(
    color: primaryLight,
    borderRadius: BorderRadius.circular(radiusFull),
  );
  
  static BoxDecoration inputDecoration({bool focused = false}) => BoxDecoration(
    color: background,
    borderRadius: BorderRadius.circular(radiusMd),
    border: Border.all(
      color: focused ? primary : border,
      width: focused ? 2 : 1,
    ),
  );

  // ============================================================================
  // THEME DATA
  // ============================================================================
  
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: fontFamily,
    
    colorScheme: const ColorScheme.light(
      primary: primary,
      secondary: secondary,
      tertiary: accent,
      error: error,
      surface: surface,
      onPrimary: background,
      onSecondary: background,
      onSurface: textPrimary,
      onError: background,
    ),
    
    scaffoldBackgroundColor: background,
    
    appBarTheme: const AppBarTheme(
      backgroundColor: background,
      foregroundColor: textPrimary,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: h2,
    ),
    
    cardTheme: CardThemeData(
      color: background,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusLg),
        side: const BorderSide(color: border, width: 1),
      ),
    ),
    
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: background,
        elevation: 0,
        padding: const EdgeInsets.symmetric(
          horizontal: spaceLg,
          vertical: spaceMd,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        textStyle: button,
      ),
    ),
    
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        side: const BorderSide(color: primary, width: 1.5),
        padding: const EdgeInsets.symmetric(
          horizontal: spaceLg,
          vertical: spaceMd,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        textStyle: button,
      ),
    ),
    
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primary,
        padding: const EdgeInsets.symmetric(
          horizontal: spaceMd,
          vertical: spaceSm,
        ),
        textStyle: button,
      ),
    ),
    
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: background,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: spaceMd,
        vertical: spaceMd,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: border, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: border, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: error, width: 1),
      ),
      hintStyle: caption.copyWith(color: textTertiary),
      labelStyle: caption,
      errorStyle: small.copyWith(color: error),
    ),
    
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return background;
        }
        return textTertiary;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primary;
        }
        return border;
      }),
    ),
    
    chipTheme: ChipThemeData(
      backgroundColor: surface,
      selectedColor: primary,
      labelStyle: captionMedium,
      padding: const EdgeInsets.symmetric(
        horizontal: spaceMd,
        vertical: spaceSm,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusFull),
        side: const BorderSide(color: border, width: 1),
      ),
    ),
    
    dividerTheme: const DividerThemeData(
      color: border,
      thickness: 1,
      space: 1,
    ),
    
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: background,
      selectedItemColor: primary,
      unselectedItemColor: textSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: small,
      unselectedLabelStyle: small,
    ),
  );
}

class FreezmeGradients {
  /// Primary gradient - uses only purple shades for consistency
  static const LinearGradient primary = LinearGradient(
    colors: [FreezmeDesignSystem.primary, FreezmeDesignSystem.primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  /// Soft background gradient
  static const LinearGradient backgroundSoft = LinearGradient(
    colors: [FreezmeDesignSystem.background, FreezmeDesignSystem.surface],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  
  /// Subtle purple gradient for headers
  static const LinearGradient header = LinearGradient(
    colors: [FreezmeDesignSystem.primary, Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Main Action Gradient (Purple -> Pink/Red)
  static const LinearGradient buttonGradient = LinearGradient(
    colors: [FreezmeDesignSystem.primary, FreezmeDesignSystem.secondary],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}
