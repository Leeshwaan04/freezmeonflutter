import 'package:flutter/material.dart';
import '../theme.dart';

enum LogoSize { sm, md, lg }

enum LogoVariant { primary, white }

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
    LogoSize.sm: (heart: 32.0, snowflake: 16.0, text: 14.0),
    LogoSize.md: (heart: 48.0, snowflake: 24.0, text: 18.0),
    LogoSize.lg: (heart: 72.0, snowflake: 36.0, text: 22.0),
  };

  static final _colorMap = {
    LogoVariant.primary: (
      heart: FreezmeColors.primary,
      snowflake: Colors.white,
      text: FreezmeColors.primary,
    ),
    LogoVariant.white: (
      heart: Colors.white,
      snowflake: FreezmeColors.primary,
      text: Colors.white,
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
              Icon(Icons.favorite, size: metrics.heart, color: colors.heart),
              Icon(Icons.ac_unit,
                  size: metrics.snowflake, color: colors.snowflake),
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
