import 'package:flutter/material.dart';
import '../../controllers/flow_controller.dart';
import '../../services/auth_service.dart';
import '../theme.dart';
import '../widgets/freezme_logo.dart';
import '../widgets/floating_orbs.dart';

class AuthGatePage extends StatefulWidget {
  const AuthGatePage({super.key});

  @override
  State<AuthGatePage> createState() => _AuthGatePageState();
}

class _AuthGatePageState extends State<AuthGatePage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late final AnimationController _bgController;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bgController.dispose();
    super.dispose();
  }

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

    return Scaffold(
      body: AnimatedBuilder(
        animation: _bgController,
        builder: (context, _) {
          final t = _bgController.value;
          final gradStart = Color.lerp(
            FreezmeColors.surface,
            FreezmeColors.surfaceAlt,
            t,
          )!;
          final gradEnd = Color.lerp(
            FreezmeColors.surfaceAlt,
            FreezmeColors.surface,
            t,
          )!;

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [gradStart, gradEnd],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                // Same floating orbs as splash
                FloatingOrbs(progress: t),
                SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: MediaQuery.of(context).size.height -
                            MediaQuery.of(context).padding.top -
                            MediaQuery.of(context).padding.bottom,
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          children: [
                            const SizedBox(height: 56),

                            // Logo — same as splash
                            const FreezmeLogo(size: LogoSize.lg),

                            const SizedBox(height: 20),

                            // FREEZME wordmark
                            Text(
                              'FREEZME',
                              style: FreezmeTypography.title.copyWith(
                                letterSpacing: 1.2,
                                color: FreezmeColors.primary,
                                fontSize: 28,
                              ),
                            ),

                            const SizedBox(height: 8),

                            // Tagline
                            Text(
                              'Where Compatibility Meets Real Connection',
                              textAlign: TextAlign.center,
                              style: FreezmeTypography.subtitle.copyWith(
                                fontSize: 14,
                              ),
                            ),

                            const SizedBox(height: 36),

                            // Feature highlights — pill chips in a row
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final item in _highlights)
                                  _HighlightChip(
                                    icon: item.icon,
                                    label: item.label,
                                  ),
                              ],
                            ),

                            const Spacer(),

                            const SizedBox(height: 40),

                            // Sign-in buttons
                            if (_isLoading)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 32),
                                child: CircularProgressIndicator(
                                  color: FreezmeColors.primary,
                                ),
                              )
                            else ...[
                              _AuthButton(
                                label: 'Continue with Apple',
                                icon: Icons.apple,
                                background: Colors.black,
                                foreground: Colors.white,
                                onTap: () => _signInWithApple(flow),
                              ),
                              const SizedBox(height: 12),
                              _AuthButton(
                                label: 'Continue with Google',
                                icon: Icons.g_mobiledata,
                                foreground: FreezmeColors.neutral,
                                background: Colors.white,
                                border: const BorderSide(
                                    color: FreezmeColors.border, width: 1.5),
                                onTap: () => _signInWithGoogle(flow),
                              ),
                              const SizedBox(height: 12),
                              _AuthButton(
                                label: 'Continue with Email',
                                icon: Icons.mail_outline,
                                gradient: FreezmeGradients.primary,
                                foreground: Colors.white,
                                onTap: () => _signInWithEmail(flow),
                              ),
                              const SizedBox(height: 12),
                              _AuthButton(
                                label: 'Open Developer Preview',
                                icon: Icons.developer_mode,
                                foreground: FreezmeColors.primary,
                                background: Colors.transparent,
                                border: const BorderSide(
                                    color: FreezmeColors.primary, width: 1.5),
                                onTap: () => flow.openDeveloperMenu(),
                              ),
                            ],

                            const SizedBox(height: 24),

                            // Legal
                            Text.rich(
                              TextSpan(
                                text: 'By continuing you agree to our ',
                                style: FreezmeTypography.bodyMuted
                                    .copyWith(fontSize: 12),
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

                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HighlightChip extends StatelessWidget {
  const _HighlightChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withValues(alpha: 0.7),
        border: Border.all(color: FreezmeColors.border),
        boxShadow: [
          BoxShadow(
            color: FreezmeColors.primary.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: FreezmeColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: FreezmeTypography.body
                .copyWith(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
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
            border: border != null ? Border.fromBorderSide(border!) : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
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
