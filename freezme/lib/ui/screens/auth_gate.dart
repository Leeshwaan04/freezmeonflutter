import 'dart:math' as math;
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
      final msg = e.toString();
      if (msg.contains('canceled') || msg.contains('cancelled') || msg.contains('cancel')) return;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google sign-in failed. Please try again.')),
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
      final msg = e.toString();
      if (msg.contains('canceled') || msg.contains('cancelled') || msg.contains('cancel') || msg.contains('1001') || msg.contains('not supported') || msg.contains('AuthorizationErrorCode.unknown')) return;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Apple sign-in failed. Please try again.')),
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

                            // FREEZME animated wordmark
                            const _FreezmeWordmark(),

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

                            // Animated feature highlights
                            const _AnimatedHighlights(highlights: _highlights),

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

// ── FREEZME wordmark ─────────────────────────────────────────────────────────

/// Typewriter letter-by-letter entrance, then an infinite shimmer sweep.
class _FreezmeWordmark extends StatefulWidget {
  const _FreezmeWordmark();

  @override
  State<_FreezmeWordmark> createState() => _FreezmeWordmarkState();
}

class _FreezmeWordmarkState extends State<_FreezmeWordmark>
    with TickerProviderStateMixin {
  static const _word = 'FREEZME';

  // One controller per letter for the typewriter entrance
  late final List<AnimationController> _letterControllers;
  late final List<Animation<double>> _letterFades;
  late final List<Animation<double>> _letterScales;

  // Continuous shimmer sweep across the full word
  late final AnimationController _shimmerController;

  // Frost particle burst per letter
  late final List<AnimationController> _frostControllers;

  @override
  void initState() {
    super.initState();

    _letterControllers = List.generate(
      _word.length,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 380),
      ),
    );

    _letterFades = _letterControllers.map((c) {
      return CurvedAnimation(parent: c, curve: Curves.easeOut);
    }).toList();

    _letterScales = _letterControllers.map((c) {
      return Tween<double>(begin: 1.4, end: 1.0)
          .animate(CurvedAnimation(parent: c, curve: Curves.easeOutBack));
    }).toList();

    _frostControllers = List.generate(
      _word.length,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 500),
      ),
    );

    // Stagger each letter by 90ms
    for (var i = 0; i < _word.length; i++) {
      Future.delayed(Duration(milliseconds: 200 + i * 90), () {
        if (!mounted) return;
        _letterControllers[i].forward();
        _frostControllers[i].forward();
      });
    }

    // Start shimmer after all letters have appeared
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    Future.delayed(
      const Duration(milliseconds: 200 + _word.length * 90 + 300),
      () { if (mounted) _shimmerController.repeat(); },
    );
  }

  @override
  void dispose() {
    for (final c in _letterControllers) { c.dispose(); }
    for (final c in _frostControllers) { c.dispose(); }
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, _) {
        // Shimmer gradient sweeps left → right
        final shimmerPos = _shimmerController.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(_word.length, (i) {
            // Per-letter shimmer brightness — peak when sweep passes this letter
            final letterFrac = i / (_word.length - 1);
            final dist = (shimmerPos - letterFrac).abs();
            final shimmerBright = math.max(0.0, 1.0 - dist * 4.0);

            final color = Color.lerp(
              FreezmeColors.primary,
              const Color(0xFFB39DDB), // light lavender highlight
              shimmerBright,
            )!;

            return AnimatedBuilder(
              animation: Listenable.merge(
                  [_letterControllers[i], _frostControllers[i]]),
              builder: (context, _) {
                final frost = _frostControllers[i].value;
                return Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // Frost particle ring — expands and fades on letter land
                    if (frost > 0 && frost < 1)
                      ...List.generate(6, (p) {
                        final angle = (p / 6) * math.pi * 2;
                        final radius = frost * 18.0;
                        final particleAlpha = (1.0 - frost).clamp(0.0, 1.0);
                        return Positioned(
                          left: math.cos(angle) * radius,
                          top: math.sin(angle) * radius - 4,
                          child: Opacity(
                            opacity: particleAlpha * 0.7,
                            child: Icon(
                              Icons.ac_unit,
                              size: 5 + frost * 2,
                              color: FreezmeColors.accent,
                            ),
                          ),
                        );
                      }),
                    // The letter itself
                    FadeTransition(
                      opacity: _letterFades[i],
                      child: ScaleTransition(
                        scale: _letterScales[i],
                        child: Text(
                          _word[i],
                          style: FreezmeTypography.title.copyWith(
                            letterSpacing: 2.0,
                            color: color,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            shadows: shimmerBright > 0.1
                                ? [
                                    Shadow(
                                      color: FreezmeColors.primary
                                          .withValues(alpha: shimmerBright * 0.4),
                                      blurRadius: 12 * shimmerBright,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          }),
        );
      },
    );
  }
}

// ── Animated highlights ──────────────────────────────────────────────────────

class _AnimatedHighlights extends StatefulWidget {
  const _AnimatedHighlights({required this.highlights});
  final List<({IconData icon, String label})> highlights;

  @override
  State<_AnimatedHighlights> createState() => _AnimatedHighlightsState();
}

class _AnimatedHighlightsState extends State<_AnimatedHighlights>
    with TickerProviderStateMixin {
  // Cascade entrance
  late final List<AnimationController> _entranceControllers;
  late final List<Animation<double>> _entranceFades;
  late final List<Animation<Offset>> _entranceSlides;

  // Continuous levitation
  late final AnimationController _levitateController;

  // Shimmer sweep on the border
  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    final count = widget.highlights.length;

    // Staggered entrance — each chip 180ms after the previous
    _entranceControllers = List.generate(
      count,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 550),
      ),
    );
    _entranceFades = _entranceControllers.map((c) {
      return CurvedAnimation(parent: c, curve: Curves.easeOut);
    }).toList();
    _entranceSlides = _entranceControllers.map((c) {
      return Tween<Offset>(
        begin: const Offset(0, 0.35),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: c, curve: Curves.easeOutCubic));
    }).toList();

    for (var i = 0; i < count; i++) {
      Future.delayed(Duration(milliseconds: 120 + i * 180), () {
        if (mounted) _entranceControllers[i].forward();
      });
    }

    // Slow levitation loop (different phase per chip handled at render time)
    _levitateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);

    // Shimmer sweep
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    for (final c in _entranceControllers) {
      c.dispose();
    }
    _levitateController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_levitateController, _shimmerController]),
      builder: (context, _) {
        return Column(
          children: List.generate(widget.highlights.length, (i) {
            // Each chip bobs at a different phase offset
            final phase = i * (math.pi * 2 / widget.highlights.length);
            final levitate =
                math.sin(_levitateController.value * math.pi + phase) * 5.0;

            return FadeTransition(
              opacity: _entranceFades[i],
              child: SlideTransition(
                position: _entranceSlides[i],
                child: Transform.translate(
                  offset: Offset(0, levitate),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: _ShimmerChip(
                      icon: widget.highlights[i].icon,
                      label: widget.highlights[i].label,
                      shimmerProgress: (_shimmerController.value + i * 0.33) % 1.0,
                      iconIndex: i,
                      levitate: levitate,
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _ShimmerChip extends StatelessWidget {
  const _ShimmerChip({
    required this.icon,
    required this.label,
    required this.shimmerProgress,
    required this.iconIndex,
    required this.levitate,
  });

  final IconData icon;
  final String label;
  final double shimmerProgress; // 0..1 cyclic
  final int iconIndex;
  final double levitate;

  @override
  Widget build(BuildContext context) {
    // Shimmer angle sweeps around the pill border
    final shimmerAngle = shimmerProgress * math.pi * 2;
    final shimmerX = math.cos(shimmerAngle);
    final shimmerY = math.sin(shimmerAngle);

    // Glow intensity pulses with shimmer
    final glowAlpha = 0.06 + shimmerProgress * 0.14;

    // Icon micro-animation values derived from shimmerProgress
    final double iconScale;
    final double iconRotation;
    switch (iconIndex) {
      case 0: // Heart — subtle pulse beat
        iconScale = 1.0 + math.sin(shimmerProgress * math.pi * 2) * 0.18;
        iconRotation = 0;
      case 1: // Camera — blink/zoom
        iconScale = 1.0 + math.sin(shimmerProgress * math.pi * 4) * 0.1;
        iconRotation = 0;
      case 2: // Leaf — gentle sway
        iconScale = 1.0;
        iconRotation = math.sin(shimmerProgress * math.pi * 2) * 0.18;
      default:
        iconScale = 1.0;
        iconRotation = 0;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withValues(alpha: 0.75),
        gradient: LinearGradient(
          begin: Alignment(shimmerX * 0.6, shimmerY * 0.6),
          end: Alignment(-shimmerX * 0.6, -shimmerY * 0.6),
          colors: [
            Colors.white.withValues(alpha: 0.95),
            FreezmeColors.surfaceAlt.withValues(alpha: 0.85),
            Colors.white.withValues(alpha: 0.95),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
        border: Border.all(
          color: FreezmeColors.primary.withValues(
            alpha: 0.15 + shimmerProgress * 0.25,
          ),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: FreezmeColors.primary.withValues(alpha: glowAlpha),
            blurRadius: 16 + shimmerProgress * 8,
            offset: Offset(shimmerX * 2, shimmerY * 2 + levitate * 0.3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.rotate(
            angle: iconRotation,
            child: Transform.scale(
              scale: iconScale,
              child: Icon(icon, size: 17, color: FreezmeColors.primary),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: FreezmeTypography.body.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 13.5,
              color: FreezmeColors.neutral,
            ),
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
