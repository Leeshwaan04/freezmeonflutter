import 'package:flutter/material.dart';
import '../design_system.dart';

/// Premium Button Component
/// Consistent button styling across the app
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
        return SizedBox(
          width: fullWidth ? double.infinity : null,
          child: ElevatedButton(
            onPressed: loading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              padding: padding,
              backgroundColor: backgroundColor,
              foregroundColor: textColor,
            ),
            child: buttonChild,
          ),
        );
      case ButtonVariant.outlined:
        return SizedBox(
          width: fullWidth ? double.infinity : null,
          child: OutlinedButton(
            onPressed: loading ? null : onPressed,
            style: OutlinedButton.styleFrom(padding: padding),
            child: buttonChild,
          ),
        );
      case ButtonVariant.text:
        return TextButton(
          onPressed: loading ? null : onPressed,
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

/// Empty State View
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
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: FreezmeDesignSystem.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: FreezmeDesignSystem.border,
                  width: 1,
                ),
              ),
              child: Icon(
                icon,
                size: 40,
                color: FreezmeDesignSystem.textSecondary,
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
              style: FreezmeDesignSystem.caption,
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: FreezmeDesignSystem.spaceLg),
              PremiumButton(
                label: actionLabel!,
                onPressed: onAction,
                variant: ButtonVariant.outlined,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Error State View
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
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: FreezmeDesignSystem.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 40,
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
              style: FreezmeDesignSystem.caption,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: FreezmeDesignSystem.spaceLg),
              PremiumButton(
                label: 'Try Again',
                onPressed: onRetry,
                variant: ButtonVariant.outlined,
                icon: Icons.refresh,
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
      child: Container(
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
              Icon(
                icon,
                size: 16,
                color: selected
                    ? FreezmeDesignSystem.background
                    : FreezmeDesignSystem.textPrimary,
              ),
              const SizedBox(width: FreezmeDesignSystem.spaceSm),
            ],
            Text(
              label,
              style: FreezmeDesignSystem.captionMedium.copyWith(
                color: selected
                    ? FreezmeDesignSystem.background
                    : FreezmeDesignSystem.textPrimary,
              ),
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
