import 'package:flutter/material.dart';
import '../design_system.dart';

enum LogoSize { sm, md, lg, xl, hero }

enum LogoVariant { primary, white, gradient }

class FreezmeLogo extends StatelessWidget {
  const FreezmeLogo({
    super.key,
    this.size = LogoSize.md,
    this.variant = LogoVariant.primary,
    this.showText = false,
  });

  final LogoSize size;
  final LogoVariant variant;
  final bool showText;

  static const _sizeMap = {
    LogoSize.sm: (heart: 24.0, snowflake: 12.0, text: 16.0),
    LogoSize.md: (heart: 32.0, snowflake: 16.0, text: 20.0),
    LogoSize.lg: (heart: 48.0, snowflake: 24.0, text: 28.0),
    LogoSize.xl: (heart: 96.0, snowflake: 36.0, text: 40.0),
    LogoSize.hero: (heart: 128.0, snowflake: 48.0, text: 56.0),
  };

  static final _colorMap = {
    LogoVariant.primary: (
      heart: FreezmeDesignSystem.primary,
      snowflake: Colors.white,
      text: FreezmeDesignSystem.primary,
    ),
    LogoVariant.white: (
      heart: Colors.white,
      snowflake: FreezmeDesignSystem.primary,
      text: Colors.white,
    ),
    LogoVariant.gradient: (
      heart: FreezmeDesignSystem.primary,
      snowflake: Colors.white,
      text: FreezmeDesignSystem.primary,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final metrics = _sizeMap[size]!;
    final colors = _colorMap[variant]!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: metrics.heart,
          height: metrics.heart,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Heart shape
              Icon(
                Icons.favorite_rounded,
                size: metrics.heart,
                color: variant == LogoVariant.white 
                    ? Colors.white 
                    : colors.heart,
              ),
              // Snowflake
              // Slight offset might be needed for perfect optical centering, but center is usually fine
              Icon(
                Icons.ac_unit_rounded,
                size: metrics.snowflake,
                color: variant == LogoVariant.white 
                    ? FreezmeDesignSystem.primary 
                    : colors.snowflake,
              ),
            ],
          ),
        ),
        if (showText) ...[
          const SizedBox(width: 12),
          Text(
            'FREEZME',
            style: TextStyle(
              color: colors.text,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              fontSize: metrics.text,
            ),
          ),
        ],
      ],
    );
  }
}
