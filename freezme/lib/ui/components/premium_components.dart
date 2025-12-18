import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../design_system.dart';

/// Premium Button Component
/// Consistent button styling with haptic feedback
class PremiumButton extends StatelessWidget {
  const PremiumButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = ButtonVariant.filled,
    this.size = ButtonSize.medium,
    this.icon,
    this.loading = false,
    this.fullWidth = false,
    this.backgroundColor,
    this.textColor,
    this.gradient,
  });

  final String label;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final ButtonSize size;
  final IconData? icon;
  final bool loading;
  final bool fullWidth;
  final Color? backgroundColor;
  final Color? textColor;
  final Gradient? gradient;

  void _handlePress() {
    HapticFeedback.lightImpact();
    onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final padding = size == ButtonSize.small
        ? const EdgeInsets.symmetric(horizontal: FreezmeDesignSystem.spaceMd, vertical: FreezmeDesignSystem.spaceSm)
        : const EdgeInsets.symmetric(horizontal: FreezmeDesignSystem.spaceLg, vertical: FreezmeDesignSystem.spaceMd);

    final textStyle = (size == ButtonSize.small
        ? FreezmeDesignSystem.buttonSmall
        : FreezmeDesignSystem.button).copyWith(color: textColor);

    Widget buttonChild = Row(
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                variant == ButtonVariant.filled
                    ? FreezmeDesignSystem.background
                    : FreezmeDesignSystem.primary,
              ),
            ),
          )
        else if (icon != null) ...[
          Icon(icon, size: 20),
          const SizedBox(width: FreezmeDesignSystem.spaceSm),
        ],
        Text(label, style: textStyle),
      ],
    );

    switch (variant) {
      case ButtonVariant.filled:
        final shouldUseGradient = gradient != null || backgroundColor == null;
        final effectiveGradient = gradient ?? (shouldUseGradient ? FreezmeGradients.buttonGradient : null);

        if (effectiveGradient != null) {
          return Container(
            width: fullWidth ? double.infinity : null,
            decoration: BoxDecoration(
              gradient: effectiveGradient,
              borderRadius: BorderRadius.circular(FreezmeDesignSystem.radiusFull),
              boxShadow: [
                BoxShadow(
                  color: FreezmeDesignSystem.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Glossy reflection overlay
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(FreezmeDesignSystem.radiusFull),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.15),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                        stops: const [0.0, 0.5],
                      ),
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: loading ? null : (onPressed != null ? _handlePress : null),
                  style: ElevatedButton.styleFrom(
                    padding: padding,
                    backgroundColor: Colors.transparent,
                    foregroundColor: textColor ?? Colors.white,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(FreezmeDesignSystem.radiusFull),
                    ),
                  ),
                  child: buttonChild,
                ),
              ],
            ),
          );
        }

        return SizedBox(
          width: fullWidth ? double.infinity : null,
          child: ElevatedButton(
            onPressed: loading ? null : (onPressed != null ? _handlePress : null),
            style: ElevatedButton.styleFrom(
              padding: padding,
              backgroundColor: backgroundColor,
              foregroundColor: textColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(FreezmeDesignSystem.radiusFull),
              ),
            ),
            child: buttonChild,
          ),
        );
      case ButtonVariant.outlined:
        return SizedBox(
          width: fullWidth ? double.infinity : null,
          child: OutlinedButton(
            onPressed: loading ? null : (onPressed != null ? _handlePress : null),
            style: OutlinedButton.styleFrom(padding: padding),
            child: buttonChild,
          ),
        );
      case ButtonVariant.text:
        return TextButton(
          onPressed: loading ? null : (onPressed != null ? _handlePress : null),
          style: TextButton.styleFrom(padding: padding),
          child: buttonChild,
        );
    }
  }
}

enum ButtonVariant { filled, outlined, text }
enum ButtonSize { small, medium }

/// Premium Card Component
class PremiumCard extends StatelessWidget {
  const PremiumCard({
    super.key,
    required this.child,
    this.variant = CardVariant.elevated,
    this.padding,
    this.onTap,
    this.gradient,
  });

  final Widget child;
  final CardVariant variant;
  final EdgeInsets? padding;
  final VoidCallback? onTap;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final decoration = variant == CardVariant.elevated
        ? FreezmeDesignSystem.cardDecoration
        : FreezmeDesignSystem.cardDecorationFlat;

    final finalDecoration = gradient != null 
        ? decoration.copyWith(gradient: gradient, color: null)
        : decoration;

    final cardPadding = padding ??
        const EdgeInsets.all(FreezmeDesignSystem.spaceMd);

    Widget card = Container(
      decoration: finalDecoration,
      padding: cardPadding,
      child: child,
    );

    if (onTap != null) {
      card = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(FreezmeDesignSystem.radiusLg),
        child: card,
      );
    }

    return card;
  }
}

enum CardVariant { elevated, flat }

/// Premium Text Field
class PremiumTextField extends StatelessWidget {
  const PremiumTextField({
    super.key,
    this.controller,
    this.hintText,
    this.labelText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType,
    this.validator,
    this.onChanged,
  });

  final TextEditingController? controller;
  final String? hintText;
  final String? labelText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final int maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hintText,
        labelText: labelText,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        suffixIcon: suffixIcon,
        counterText: maxLength != null ? null : '',
      ),
      obscureText: obscureText,
      maxLines: obscureText ? 1 : maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      style: FreezmeDesignSystem.body,
    );
  }
}

/// Empty State View - Clean, simple design
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(FreezmeDesignSystem.spaceXl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Simple icon container with soft background
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: FreezmeDesignSystem.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 36,
                color: FreezmeDesignSystem.primary,
              ),
            ),
            const SizedBox(height: FreezmeDesignSystem.spaceLg),
            Text(
              title,
              style: FreezmeDesignSystem.h3,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: FreezmeDesignSystem.spaceSm),
            Text(
              subtitle,
              style: FreezmeDesignSystem.body.copyWith(
                color: FreezmeDesignSystem.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: FreezmeDesignSystem.spaceLg),
              PremiumButton(
                label: actionLabel!,
                onPressed: onAction,
                variant: ButtonVariant.filled,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Error State View - Clean, simple design
class ErrorStateView extends StatelessWidget {
  const ErrorStateView({
    super.key,
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(FreezmeDesignSystem.spaceXl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Simple error icon container
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: FreezmeDesignSystem.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 36,
                color: FreezmeDesignSystem.error,
              ),
            ),
            const SizedBox(height: FreezmeDesignSystem.spaceLg),
            Text(
              'Oops!',
              style: FreezmeDesignSystem.h3,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: FreezmeDesignSystem.spaceSm),
            Text(
              message,
              style: FreezmeDesignSystem.body.copyWith(
                color: FreezmeDesignSystem.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: FreezmeDesignSystem.spaceLg),
              PremiumButton(
                label: 'Try Again',
                onPressed: onRetry,
                variant: ButtonVariant.outlined,
                icon: Icons.refresh_rounded,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Loading View
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: FreezmeDesignSystem.spaceMd),
            Text(
              message!,
              style: FreezmeDesignSystem.caption,
            ),
          ],
        ],
      ),
    );
  }
}

/// Premium Toggle Switch
class PremiumToggle extends StatelessWidget {
  const PremiumToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.subtitle,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String? label;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (label != null)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label!, style: FreezmeDesignSystem.bodyMedium),
                if (subtitle != null)
                  Text(subtitle!, style: FreezmeDesignSystem.caption),
              ],
            ),
          ),
        Switch(
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// Premium Chip
class PremiumChip extends StatelessWidget {
  const PremiumChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(FreezmeDesignSystem.radiusFull),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(
          horizontal: FreezmeDesignSystem.spaceMd,
          vertical: FreezmeDesignSystem.spaceSm,
        ),
        decoration: BoxDecoration(
          color: selected
              ? FreezmeDesignSystem.primary
              : FreezmeDesignSystem.surface,
          borderRadius: BorderRadius.circular(FreezmeDesignSystem.radiusFull),
          border: Border.all(
            color: selected
                ? FreezmeDesignSystem.primary
                : FreezmeDesignSystem.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  color: selected
                      ? FreezmeDesignSystem.background
                      : FreezmeDesignSystem.textPrimary,
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: selected
                      ? FreezmeDesignSystem.background
                      : FreezmeDesignSystem.textPrimary,
                ),
              ),
              const SizedBox(width: FreezmeDesignSystem.spaceSm),
            ],
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: FreezmeDesignSystem.captionMedium.copyWith(
                color: selected
                    ? FreezmeDesignSystem.background
                    : FreezmeDesignSystem.textPrimary,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

/// Premium SnackBar Helper
class PremiumSnackBar {
  static void show(
    BuildContext context,
    String message, {
    SnackBarType type = SnackBarType.info,
    Duration duration = const Duration(seconds: 4),
  }) {
    final backgroundColor = switch (type) {
      SnackBarType.success => FreezmeDesignSystem.success,
      SnackBarType.error => FreezmeDesignSystem.error,
      SnackBarType.info => FreezmeDesignSystem.surfaceContrast,
      SnackBarType.warning => FreezmeDesignSystem.warning,
    };

    final textColor = type == SnackBarType.info
        ? FreezmeDesignSystem.background
        : Colors.white;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: FreezmeDesignSystem.bodyMedium.copyWith(color: textColor),
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FreezmeDesignSystem.radiusMd)),
        duration: duration,
        margin: const EdgeInsets.all(FreezmeDesignSystem.spaceMd),
      ),
    );
  }
}

enum SnackBarType { success, error, info, warning }

/// Smooth Page Route with fade and slide animation
class SmoothPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  
  SmoothPageRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 250),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            
            return FadeTransition(
              opacity: curvedAnimation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.05, 0),
                  end: Offset.zero,
                ).animate(curvedAnimation),
                child: child,
              ),
            );
          },
        );
}

/// Shimmer Effect for skeleton loaders
class ShimmerEffect extends StatefulWidget {
  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;

  const ShimmerEffect({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
  });

  @override
  State<ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<ShimmerEffect> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.baseColor ?? FreezmeDesignSystem.shimmer;
    final highlightColor = widget.highlightColor ?? FreezmeDesignSystem.primaryLight;
    
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: [
                (_animation.value - 0.3).clamp(0.0, 1.0),
                _animation.value.clamp(0.0, 1.0),
                (_animation.value + 0.3).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Skeleton Box for loading placeholders
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final bool isCircle;

  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 8,
    this.isCircle = false,
  });

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: FreezmeDesignSystem.shimmer,
          borderRadius: isCircle ? null : BorderRadius.circular(borderRadius),
          shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
        ),
      ),
    );
  }
}

/// Tappable Card with haptic feedback
class TappableCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;

  const TappableCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap != null
            ? () {
                HapticFeedback.selectionClick();
                onTap?.call();
              }
            : null,
        borderRadius: borderRadius ?? BorderRadius.circular(FreezmeDesignSystem.radiusLg),
        child: Container(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

/// Verification Badge - Shows verified status
class VerificationBadge extends StatelessWidget {
  final double size;
  final bool showBackground;

  const VerificationBadge({
    super.key,
    this.size = 16,
    this.showBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      Icons.verified_rounded,
      size: size,
      color: Colors.blue,
    );

    if (showBackground) {
      return Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: icon,
      );
    }

    return icon;
  }
}

/// Online Status Indicator - Green dot for online users
class OnlineIndicator extends StatelessWidget {
  final double size;
  final bool showBorder;

  const OnlineIndicator({
    super.key,
    this.size = 12,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: FreezmeDesignSystem.success,
        shape: BoxShape.circle,
        border: showBorder
            ? Border.all(
                color: Colors.white,
                width: 2,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: FreezmeDesignSystem.success.withValues(alpha: 0.4),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }
}

/// Avatar with optional online status and verification
class UserAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? initials;
  final double size;
  final bool isOnline;
  final bool isVerified;
  final bool isPremium;

  const UserAvatar({
    super.key,
    this.imageUrl,
    this.initials,
    this.size = 48,
    this.isOnline = false,
    this.isVerified = false,
    this.isPremium = false,
  });

  @override
  Widget build(BuildContext context) {
    ImageProvider? imageProvider;
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      if (imageUrl!.startsWith('http')) {
        imageProvider = NetworkImage(imageUrl!);
      } else {
        imageProvider = FileImage(File(imageUrl!));
      }
    }

    return Stack(
      children: [
        // Avatar
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: FreezmeDesignSystem.primaryLight,
            image: imageProvider != null
                ? DecorationImage(
                    image: imageProvider,
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: imageUrl == null || imageUrl!.isEmpty
              ? Center(
                  child: Text(
                    initials ?? '?',
                    style: TextStyle(
                      color: FreezmeDesignSystem.primary,
                      fontSize: size * 0.4,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              : null,
        ),
        // Online indicator
        if (isOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: OnlineIndicator(size: size * 0.28),
          ),
        // Verification badge
        if (isVerified)
          Positioned(
            right: 0,
            top: 0,
            child: VerificationBadge(size: size * 0.35, showBackground: true),
          ),
        // Premium badge
        if (isPremium)
          Positioned(
            left: 0,
            top: 0,
            child: PremiumBadge(size: size * 0.3),
          ),
      ],
    );
  }
}

/// Match Percentage Badge
class MatchBadge extends StatelessWidget {
  final int percentage;
  
  const MatchBadge({
    super.key,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: FreezmeDesignSystem.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.flash_on, size: 12, color: Colors.white),
          const SizedBox(width: 2),
          Text(
            '$percentage%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Premium Badge for Freezme+ users
class PremiumBadge extends StatelessWidget {
  final double size;

  const PremiumBadge({
    super.key,
    this.size = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        gradient: FreezmeGradients.header,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.star_rounded,
        size: size,
        color: Colors.white,
      ),
    );
  }
}

/// Interest Tag Chip
class InterestTag extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  const InterestTag({
    super.key,
    required this.label,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (onTap != null) {
          HapticFeedback.selectionClick();
          onTap?.call();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? FreezmeDesignSystem.primary : FreezmeDesignSystem.primaryLight,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : FreezmeDesignSystem.primary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Activity Status Pill
class ActivityStatusPill extends StatelessWidget {
  final String activity;
  final IconData? icon;

  const ActivityStatusPill({
    super.key,
    required this.activity,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: FreezmeDesignSystem.shadowSm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: FreezmeDesignSystem.primary),
            const SizedBox(width: 4),
          ],
          Text(
            activity,
            style: FreezmeDesignSystem.small.copyWith(
              color: FreezmeDesignSystem.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Countdown Timer for limited offers or matches
class CountdownTimer extends StatefulWidget {
  final Duration duration;
  final VoidCallback? onComplete;
  final TextStyle? style;

  const CountdownTimer({
    super.key,
    required this.duration,
    this.onComplete,
    this.style,
  });

  @override
  State<CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<CountdownTimer> {
  late Duration _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = widget.duration;
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remaining.inSeconds > 0) {
        setState(() {
          _remaining = _remaining - const Duration(seconds: 1);
        });
      } else {
        timer.cancel();
        widget.onComplete?.call();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _formatDuration(_remaining),
      style: widget.style ?? FreezmeDesignSystem.bodyMedium.copyWith(
        color: FreezmeDesignSystem.primary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

/// Premium Action Card - For highlighted actions (e.g. Rejoin Blind)
class PremiumActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String actionLabel;
  final VoidCallback onTap;
  final Gradient? gradient;

  const PremiumActionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.actionLabel,
    required this.onTap,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient ?? FreezmeGradients.primary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: FreezmeDesignSystem.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    actionLabel,
                    style: const TextStyle(
                      color: FreezmeDesignSystem.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
