import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../controllers/flow_controller.dart';
import '../../services/auth_service.dart';
import '../theme.dart';
import '../widgets/freezme_logo.dart';

class AuthGatePage extends StatefulWidget {
  const AuthGatePage({super.key});

  @override
  State<AuthGatePage> createState() => _AuthGatePageState();
}

class _AuthGatePageState extends State<AuthGatePage> {
  bool _isLoading = false;

  Future<void> _signInWithGoogle(AppFlowController flow) async {
    setState(() => _isLoading = true);
    try {
      await AuthService.instance.signInWithGoogle();
      if (mounted) flow.startOnboarding();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google sign-in failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithApple(AppFlowController flow) async {
    setState(() => _isLoading = true);
    try {
      await AuthService.instance.signInWithApple();
      if (mounted) flow.startOnboarding();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Apple sign-in failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithEmail(AppFlowController flow) async {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    bool isSignUp = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(isSignUp ? 'Create Account' : 'Sign In'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () =>
                    setDialogState(() => isSignUp = !isSignUp),
                child: Text(isSignUp
                    ? 'Already have an account? Sign in'
                    : 'New here? Create account'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(isSignUp ? 'Sign Up' : 'Sign In')),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    setState(() => _isLoading = true);
    try {
      if (isSignUp) {
        await AuthService.instance.signUpWithEmail(
          email: emailCtrl.text.trim(),
          password: passCtrl.text,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Account created — welcome to Freezme!')),
          );
        }
      } else {
        await AuthService.instance.signInWithEmail(
          email: emailCtrl.text.trim(),
          password: passCtrl.text,
        );
      }
      if (mounted) flow.startOnboarding();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  static const _highlights = [
    (icon: Icons.favorite_outline, label: 'Curated daily matches'),
    (icon: Icons.videocam_outlined, label: '1:1 video vibes'),
    (icon: Icons.spa_outlined, label: 'Mindful prompts & check-ins'),
  ];

  @override
  Widget build(BuildContext context) {
    final flow = AppFlowScope.of(context, listen: false);
    final cardShadow = FreezmeColors.primary.withValues(alpha: 0.08);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: FreezmeGradients.backgroundSoft,
        ),
        child: SafeArea(
          child: Stack(
            children: [
              const _AuthBackgroundDecor(),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: FreezmeInsets.pageGutter,
                    vertical: FreezmeInsets.sectionSpacing,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: FreezmeInsets.elementSpacing * 1.5,
                            vertical: FreezmeInsets.sectionSpacing * 1.4,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              FreezmeInsets.cardRadius,
                            ),
                            gradient: const LinearGradient(
                              colors: [Colors.white, FreezmeColors.surface],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(color: FreezmeColors.border),
                            boxShadow: [
                              BoxShadow(
                                color: cardShadow,
                                blurRadius: 36,
                                offset: const Offset(0, 18),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: FreezmeGradients.primary,
                                ),
                                child: const FreezmeLogo(
                                  size: LogoSize.md,
                                  variant: LogoVariant.white,
                                ),
                              ),
                              const SizedBox(height: FreezmeInsets.sectionSpacing),
                              Text(
                                'Intentional dating for soulful matches',
                                textAlign: TextAlign.center,
                                style: FreezmeTypography.title.copyWith(
                                  color: FreezmeColors.neutral,
                                ),
                              ),
                              const SizedBox(height: FreezmeInsets.elementSpacing),
                              const Text(
                                'Freezme pairs thoughtful prompts, science-backed compatibility, and mindful pacing so every connection feels like it\'s meant to be.',
                                textAlign: TextAlign.center,
                                style: FreezmeTypography.bodyMuted,
                              ),
                              const SizedBox(height: FreezmeInsets.sectionSpacing),
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: FreezmeInsets.elementSpacing,
                                runSpacing: FreezmeInsets.elementSpacing,
                                children: [
                                  for (final item in _highlights)
                                    _AuthHighlightBadge(
                                      icon: item.icon,
                                      label: item.label,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: FreezmeInsets.sectionSpacing * 1.8),
                        if (_isLoading)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 28),
                            child: CircularProgressIndicator(),
                          )
                        else ...[
                          _AuthButton(
                            label: 'Continue with Apple',
                            icon: Icons.apple,
                            background: Colors.black,
                            foreground: Colors.white,
                            onTap: () => _signInWithApple(flow),
                          ),
                          const SizedBox(height: FreezmeInsets.elementSpacing),
                          _AuthButton(
                            label: 'Continue with Google',
                            icon: Icons.g_mobiledata,
                            foreground: FreezmeColors.neutral,
                            background: Colors.white,
                            border:
                                const BorderSide(color: FreezmeColors.border, width: 2),
                            onTap: () => _signInWithGoogle(flow),
                          ),
                          const SizedBox(height: FreezmeInsets.elementSpacing),
                          _AuthButton(
                            label: 'Continue with Email',
                            icon: Icons.mail_outline,
                            gradient: FreezmeGradients.primary,
                            foreground: Colors.white,
                            onTap: () => _signInWithEmail(flow),
                          ),
                        ],
                        const SizedBox(height: FreezmeInsets.sectionSpacing),
                        const Text(
                          'Your vibe begins with one tap 💫',
                          style: FreezmeTypography.bodyMuted,
                        ),
                        const SizedBox(height: FreezmeInsets.elementSpacing),
                        Text.rich(
                          TextSpan(
                            text: 'By continuing you agree to our ',
                            style: FreezmeTypography.bodyMuted
                                .copyWith(fontSize: 13),
                            children: const [
                              TextSpan(
                                text: 'Terms',
                                style: TextStyle(
                                  color: FreezmeColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              TextSpan(text: ' and '),
                              TextSpan(
                                text: 'Privacy Policy',
                                style: TextStyle(
                                  color: FreezmeColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              TextSpan(text: '.'),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthHighlightBadge extends StatelessWidget {
  const _AuthHighlightBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: FreezmeInsets.elementSpacing,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white,
        border: Border.all(color: FreezmeColors.border),
        boxShadow: [
          BoxShadow(
            color: FreezmeColors.primary.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: FreezmeColors.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: FreezmeTypography.body.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _AuthBackgroundDecor extends StatelessWidget {
  const _AuthBackgroundDecor();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Positioned(
              top: -120,
              left: -80,
              child: Container(
                width: 240,
                height: 240,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: FreezmeGradients.primary,
                ),
              ),
            ),
            Positioned(
              bottom: -140,
              right: -60,
              child: Container(
                width: 260,
                height: 260,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: FreezmeGradients.accent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthButton extends StatelessWidget {
  const _AuthButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.background,
    this.foreground,
    this.gradient,
    this.border,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? background;
  final Color? foreground;
  final Gradient? gradient;
  final BorderSide? border;

  @override
  Widget build(BuildContext context) {
    final textColor = foreground ?? Colors.white;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          decoration: BoxDecoration(
            gradient: gradient,
            color: gradient == null ? background : null,
            borderRadius: BorderRadius.circular(999),
            border:
                border != null ? Border.fromBorderSide(border!) : null,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: FreezmeInsets.elementSpacing,
            vertical: 18,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: textColor),
              const SizedBox(width: 12),
              Text(
                label,
                style: FreezmeTypography.button.copyWith(color: textColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
