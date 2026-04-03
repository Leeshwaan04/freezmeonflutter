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
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EmailAuthSheet(
        onSuccess: () {
          Navigator.of(ctx).pop();
          flow.startOnboarding();
        },
      ),
    );
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

// ── Email Auth Bottom Sheet ──────────────────────────────────────────────────

class _EmailAuthSheet extends StatefulWidget {
  const _EmailAuthSheet({required this.onSuccess});
  final VoidCallback onSuccess;

  @override
  State<_EmailAuthSheet> createState() => _EmailAuthSheetState();
}

class _EmailAuthSheetState extends State<_EmailAuthSheet> {
  bool _isSignUp = true;
  bool _loading = false;
  bool _obscurePass = true;
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Please fill in all fields.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      if (_isSignUp) {
        await AuthService.instance.signUpWithEmail(email: email, password: pass);
      } else {
        await AuthService.instance.signInWithEmail(email: email, password: pass);
      }
      widget.onSuccess();
    } catch (e) {
      final msg = e.toString();
      setState(() {
        _error = msg.contains('already') ? 'Email already in use. Try signing in.'
            : msg.contains('password') || msg.contains('credential') ? 'Wrong email or password.'
            : msg.contains('invalid') ? 'Please enter a valid email.'
            : 'Something went wrong. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: FreezmeColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: FreezmeGradients.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.mail_outline, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isSignUp ? 'Create Account' : 'Welcome Back',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      _isSignUp ? 'Join Freezme today' : 'Sign in to continue',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Toggle tabs
          Container(
            decoration: BoxDecoration(
              color: FreezmeColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                _Tab(label: 'Create Account', selected: _isSignUp, onTap: () => setState(() => _isSignUp = true)),
                _Tab(label: 'Sign In', selected: !_isSignUp, onTap: () => setState(() => _isSignUp = false)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Email field
          _AuthField(
            controller: _emailCtrl,
            label: 'Email',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 14),

          // Password field
          _AuthField(
            controller: _passCtrl,
            label: 'Password',
            icon: Icons.lock_outline,
            obscureText: _obscurePass,
            suffixIcon: IconButton(
              icon: Icon(_obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: FreezmeColors.muted, size: 20),
              onPressed: () => setState(() => _obscurePass = !_obscurePass),
            ),
          ),

          // Error
          if (_error != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),

          // Submit button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _loading ? null : _submit,
              borderRadius: BorderRadius.circular(999),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: FreezmeGradients.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                padding: const EdgeInsets.symmetric(vertical: 17),
                child: Center(
                  child: _loading
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : Text(
                          _isSignUp ? 'Create Account' : 'Sign In',
                          style: FreezmeTypography.button.copyWith(color: Colors.white),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)] : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? FreezmeColors.primary : FreezmeColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
  });
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: const TextStyle(color: FreezmeColors.neutral, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: FreezmeColors.muted),
        prefixIcon: Icon(icon, color: FreezmeColors.primary, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: FreezmeColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: FreezmeColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: FreezmeColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: FreezmeColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}
