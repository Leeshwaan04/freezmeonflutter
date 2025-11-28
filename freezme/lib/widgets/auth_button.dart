import 'package:flutter/material.dart';

class AuthButton extends StatelessWidget {
  const AuthButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.background,
    this.foreground,
    this.gradient,
    this.border,
    this.loading = false,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? background;
  final Color? foreground;
  final Gradient? gradient;
  final BorderSide? border;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final textColor = foreground ?? Colors.white;
    final borderSide = border;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(999),
        child: Opacity(
          opacity: loading ? 0.7 : 1,
          child: Ink(
            decoration: BoxDecoration(
              gradient: gradient,
              color: gradient == null ? background : null,
              borderRadius: BorderRadius.circular(999),
              border:
                  borderSide != null ? Border.fromBorderSide(borderSide) : null,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 18,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (loading) ...[
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(textColor),
                    ),
                  ),
                ] else ...[
                  Icon(icon, color: textColor),
                ],
                const SizedBox(width: 12),
                Text(
                  loading ? 'Connecting...' : label,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
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
