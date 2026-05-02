import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../controllers/flow_controller.dart';
import '../../core/app_stage.dart';
import '../../services/auth_service.dart';
import '../theme.dart';
import '../widgets/freezme_logo.dart';
import '../widgets/floating_orbs.dart';

const _kTermsUrl = 'https://api.freezme.in/terms';
const _kPrivacyUrl = 'https://api.freezme.in/privacy';

Future<void> _openUrl(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

enum _AuthMethod { apple, google, email }

class AuthGatePage extends StatefulWidget {
  const AuthGatePage({super.key});

  @override
  State<AuthGatePage> createState() => _AuthGatePageState();
}

class _AuthGatePageState extends State<AuthGatePage>
    with SingleTickerProviderStateMixin {
  // Per-button loading so other buttons stay visible while one is in progress
  _AuthMethod? _loadingMethod;
  late final AnimationController _bgController;

  bool get _isLoading => _loadingMethod != null;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
    // Pre-warm Google SDK so there's zero delay when user taps the button
    AuthService.initGoogleSignIn();
  }

  @override
  void dispose() {
    _bgController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle(AppFlowController flow) async {
    if (_isLoading) return;
    setState(() => _loadingMethod = _AuthMethod.google);
    try {
      await AuthService.instance.signInWithGoogle();
      // Navigation handled by _listenToAuth in flow_controller:
      //   new user  → onboarding
      //   returning → dailyPool
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMethod = null);
      if (AuthService.isGoogleCancelError(e)) return;
      _showAuthError('Google sign-in failed. Please try again.');
    } finally {
      if (mounted && _loadingMethod == _AuthMethod.google) {
        setState(() => _loadingMethod = null);
      }
    }
  }

  Future<void> _signInWithApple(AppFlowController flow) async {
    if (_isLoading) return;
    setState(() => _loadingMethod = _AuthMethod.apple);
    try {
      await AuthService.instance.signInWithApple();
      // Navigation handled by _listenToAuth in flow_controller
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMethod = null);
      if (AuthService.isAppleCancelError(e)) return;
      _showAuthError('Apple sign-in failed. Please try again.');
    } finally {
      if (mounted && _loadingMethod == _AuthMethod.apple) {
        setState(() => _loadingMethod = null);
      }
    }
  }

  Future<void> _signInWithEmail(AppFlowController flow) async {
    if (_isLoading) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (ctx) => _EmailAuthSheet(
        onSuccess: () {
          Navigator.of(ctx).pop();
          // Navigation handled by _listenToAuth in flow_controller
        },
      ),
    );
  }

  void _showAuthError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  static const _highlights = [
    (
      icon: Icons.favorite_outline,
      label: 'Daily Matches',
      sub: 'Meet someone who actually gets you',
    ),
    (
      icon: Icons.explore_outlined,
      label: 'Paths',
      sub: 'Cross paths with people around you',
    ),
    (
      icon: Icons.visibility_off_outlined,
      label: 'Blinds',
      sub: 'Feel the vibe before the face',
    ),
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
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: MediaQuery.of(context).size.height -
                            MediaQuery.of(context).padding.top -
                            MediaQuery.of(context).padding.bottom,
                      ),
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 56),

                            // Logo — same as splash
                            const FreezmeLogo(size: LogoSize.lg),

                            const SizedBox(height: 20),

                            // FREEZME animated wordmark — SizedBox constrains width so
                            // FittedBox can scale down on narrow screens (SE = 375px).
                            SizedBox(
                              width: double.infinity,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: const _FreezmeWordmark(),
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

                            // Animated feature highlights — ClipRect prevents
                            // SlideTransition entrance from overflowing horizontally.
                            ClipRect(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: const _AnimatedHighlights(highlights: _highlights),
                              ),
                            ),

                            const SizedBox(height: 40),

                            // Social proof
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.people_outline, size: 15, color: FreezmeColors.primary),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'Join thousands finding real connections',
                                    style: FreezmeTypography.bodyMuted.copyWith(fontSize: 12.5),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 32),

                            // Sign-in buttons — always visible; spinner per button
                            ...[
                              _AuthButton(
                                label: 'Continue with Apple',
                                icon: Icons.apple,
                                variant: _AuthButtonVariant.apple,
                                foreground: Colors.white,
                                isLoading: _loadingMethod == _AuthMethod.apple,
                                disabled: _isLoading && _loadingMethod != _AuthMethod.apple,
                                onTap: () => _signInWithApple(flow),
                              ),
                              const SizedBox(height: 10),
                              _AuthButton(
                                label: 'Continue with Google',
                                icon: Icons.g_mobiledata,
                                variant: _AuthButtonVariant.google,
                                foreground: FreezmeColors.neutral,
                                isLoading: _loadingMethod == _AuthMethod.google,
                                disabled: _isLoading && _loadingMethod != _AuthMethod.google,
                                onTap: () => _signInWithGoogle(flow),
                              ),
                              const SizedBox(height: 10),
                              _AuthButton(
                                label: 'Continue with Email',
                                icon: Icons.mail_outline,
                                variant: _AuthButtonVariant.email,
                                foreground: Colors.white,
                                isLoading: _loadingMethod == _AuthMethod.email,
                                disabled: _isLoading && _loadingMethod != _AuthMethod.email,
                                onTap: () => _signInWithEmail(flow),
                              ),
                              // Dev-only skip button — debug/profile builds only
                              if (!kReleaseMode) ...[
                                const SizedBox(height: 16),
                                GestureDetector(
                                  onTap: () => flow.replaceStack([AppStage.onboarding]),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.developer_mode, size: 16, color: Colors.grey),
                                        SizedBox(width: 8),
                                        Text(
                                          'Skip (Dev only)',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],

                            const SizedBox(height: 24),

                            // Legal — tappable Terms and Privacy Policy
                            Text.rich(
                              TextSpan(
                                text: 'By continuing you agree to our ',
                                style: FreezmeTypography.bodyMuted
                                    .copyWith(fontSize: 12),
                                children: [
                                  TextSpan(
                                    text: 'Terms',
                                    style: const TextStyle(
                                      color: FreezmeColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () => _openUrl(_kTermsUrl),
                                  ),
                                  const TextSpan(text: ' and '),
                                  TextSpan(
                                    text: 'Privacy Policy',
                                    style: const TextStyle(
                                      color: FreezmeColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () => _openUrl(_kPrivacyUrl),
                                  ),
                                  const TextSpan(text: '.'),
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
  // Single driver for staggered entrance — tracked as field so dispose() can clean it up
  late final AnimationController _staggerDriver;

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

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // Stagger via a single AnimationController so fake-time in tests works correctly.
    // All timers are ticker-driven — no Future.delayed so tests can pump them cleanly.
    const staggerTotal = 200 + _word.length * 90 + 300;
    _staggerDriver = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: staggerTotal),
    );
    for (var i = 0; i < _word.length; i++) {
      final threshold = (200 + i * 90) / staggerTotal;
      _staggerDriver.addListener(() {
        if (_staggerDriver.value >= threshold &&
            _letterControllers[i].status == AnimationStatus.dismissed) {
          _letterControllers[i].forward();
          _frostControllers[i].forward();
        }
      });
    }
    _staggerDriver.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        _shimmerController.repeat();
      }
    });
    _staggerDriver.forward();
  }

  @override
  void dispose() {
    _staggerDriver.dispose();
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
                  clipBehavior: Clip.hardEdge,
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

// Per-feature accent colours
const _kFeatureColors = [
  Color(0xFF4D2C91), // deep purple — Daily Matches
  Color(0xFF2563EB), // blue    — Paths
  Color(0xFFDB2777), // pink    — Blinds
];

class _AnimatedHighlights extends StatefulWidget {
  const _AnimatedHighlights({required this.highlights});
  final List<({IconData icon, String label, String sub})> highlights;

  @override
  State<_AnimatedHighlights> createState() => _AnimatedHighlightsState();
}

class _AnimatedHighlightsState extends State<_AnimatedHighlights>
    with TickerProviderStateMixin {
  // Entrance per card
  late final List<AnimationController> _entranceControllers;
  late final List<Animation<double>> _entranceFades;
  late final List<Animation<Offset>> _entranceSlides;

  // Shared continuous ticker
  late final AnimationController _loopController;

  // Stagger driver — purely ticker-based (no Future.delayed, safe in tests)
  late final AnimationController _staggerDriver;

  @override
  void initState() {
    super.initState();
    final count = widget.highlights.length;

    _entranceControllers = List.generate(
      count,
      (_) => AnimationController(vsync: this, duration: const Duration(milliseconds: 600)),
    );
    _entranceFades = _entranceControllers
        .map((c) => CurvedAnimation(parent: c, curve: Curves.easeOut))
        .toList();
    _entranceSlides = _entranceControllers
        .map((c) => Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
            .animate(CurvedAnimation(parent: c, curve: Curves.easeOutBack)))
        .toList();

    final staggerTotal = 200 + count * 220;
    _staggerDriver = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: staggerTotal),
    );
    for (var i = 0; i < count; i++) {
      final threshold = (200 + i * 220) / staggerTotal;
      _staggerDriver.addListener(() {
        if (_staggerDriver.value >= threshold &&
            _entranceControllers[i].status == AnimationStatus.dismissed) {
          _entranceControllers[i].forward();
        }
      });
    }
    _staggerDriver.forward();

    _loopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();
  }

  @override
  void dispose() {
    _staggerDriver.dispose();
    for (final c in _entranceControllers) c.dispose();
    _loopController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _loopController,
      builder: (context, _) {
        final t = _loopController.value; // 0..1 looping
        return Column(
          children: List.generate(widget.highlights.length, (i) {
            final color = _kFeatureColors[i % _kFeatureColors.length];
            final phaseOffset = i / widget.highlights.length;
            final loopT = (t + phaseOffset) % 1.0;

            // Orb pulse — breathes in and out
            final orbScale = 1.0 + math.sin(loopT * math.pi * 2) * 0.08;
            // Levitate — gentle vertical float
            final levitate = math.sin(loopT * math.pi * 2) * 6.0;
            // Particle orbit angle
            final particleAngle = loopT * math.pi * 2;

            return FadeTransition(
              opacity: _entranceFades[i],
              child: SlideTransition(
                position: _entranceSlides[i],
                child: Transform.translate(
                  offset: Offset(0, levitate),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: _FeatureOrb(
                      icon: widget.highlights[i].icon,
                      label: widget.highlights[i].label,
                      sub: widget.highlights[i].sub,
                      color: color,
                      orbScale: orbScale,
                      particleAngle: particleAngle,
                      iconIndex: i,
                      loopT: loopT,
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

class _FeatureOrb extends StatelessWidget {
  const _FeatureOrb({
    required this.icon,
    required this.label,
    required this.sub,
    required this.color,
    required this.orbScale,
    required this.particleAngle,
    required this.iconIndex,
    required this.loopT,
  });

  final IconData icon;
  final String label;
  final String sub;
  final Color color;
  final double orbScale;
  final double particleAngle;
  final int iconIndex;
  final double loopT;

  @override
  Widget build(BuildContext context) {
    // Icon-specific micro-motion
    final double iconScale;
    final double iconRotation;
    switch (iconIndex) {
      case 0: // Heart — heartbeat double-pulse
        final beat = math.sin(loopT * math.pi * 4);
        iconScale = 1.0 + beat.clamp(0.0, 1.0) * 0.22;
        iconRotation = 0;
      case 1: // Compass — slow spin
        iconScale = 1.0;
        iconRotation = loopT * math.pi * 2;
      case 2: // Eye — scale blink
        iconScale = 1.0 + math.sin(loopT * math.pi * 2) * 0.14;
        iconRotation = 0;
      default:
        iconScale = 1.0;
        iconRotation = 0;
    }

    // 3 orbiting particles at 120° apart
    final particles = List.generate(3, (p) {
      final angle = particleAngle + p * (math.pi * 2 / 3);
      final r = 32.0;
      return Offset(math.cos(angle) * r, math.sin(angle) * r);
    });

    const orbSize = 64.0;

    return Row(
      children: [
        // Orb with particles
        SizedBox(
          width: orbSize + 24,
          height: orbSize + 24,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer glow ring
              Transform.scale(
                scale: orbScale * 1.35,
                child: Container(
                  width: orbSize,
                  height: orbSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.10),
                  ),
                ),
              ),
              // Orb body
              Transform.scale(
                scale: orbScale,
                child: Container(
                  width: orbSize,
                  height: orbSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        color.withValues(alpha: 0.28),
                        color.withValues(alpha: 0.10),
                      ],
                    ),
                    border: Border.all(
                      color: color.withValues(alpha: 0.35),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.25 + orbScale * 0.08),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Transform.rotate(
                      angle: iconRotation,
                      child: Transform.scale(
                        scale: iconScale,
                        child: Icon(icon, size: 26, color: color),
                      ),
                    ),
                  ),
                ),
              ),
              // Orbiting particles
              ...particles.map((offset) => Positioned(
                left: orbSize / 2 + 12 + offset.dx - 3,
                top: orbSize / 2 + 12 + offset.dy - 3,
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.55),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              )),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Text
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: FreezmeTypography.body.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: FreezmeColors.neutral,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                sub,
                style: FreezmeTypography.body.copyWith(
                  fontWeight: FontWeight.w400,
                  fontSize: 12.5,
                  color: FreezmeColors.neutral.withValues(alpha: 0.5),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        // Accent dot
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.4 + orbScale * 0.2),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 6),
            ],
          ),
        ),
      ],
    );
  }
}

enum _AuthButtonVariant { apple, google, email }

class _AuthButton extends StatefulWidget {
  const _AuthButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.variant,
    this.foreground,
    this.isLoading = false,
    this.disabled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final _AuthButtonVariant variant;
  final Color? foreground;
  final bool isLoading;
  final bool disabled;

  @override
  State<_AuthButton> createState() => _AuthButtonState();
}

class _AuthButtonState extends State<_AuthButton> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.foreground ?? Colors.white;

    return GestureDetector(
      onTap: (widget.isLoading || widget.disabled) ? null : widget.onTap,
      onTapDown: (widget.isLoading || widget.disabled) ? null : (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedOpacity(
        opacity: widget.disabled ? 0.45 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) {
              final t = _ctrl.value;
              return _buildButton(context, t, textColor);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildButton(BuildContext context, double t, Color textColor) {
    switch (widget.variant) {
      case _AuthButtonVariant.apple:
        // Dark frosted glass with a soft shimmer sweep
        final shimmerX = math.cos(t * math.pi * 2);
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment(shimmerX - 1, -0.5),
              end: Alignment(shimmerX + 1, 0.5),
              colors: const [
                Color(0xFF1A1A1A),
                Color(0xFF2D2D2D),
                Color(0xFF1A1A1A),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.isLoading)
                SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: textColor))
              else
                Icon(widget.icon, color: textColor, size: 20),
              const SizedBox(width: 12),
              Flexible(child: Text(widget.label, style: FreezmeTypography.button.copyWith(color: textColor, fontSize: 15), overflow: TextOverflow.ellipsis)),
            ],
          ),
        );

      case _AuthButtonVariant.google:
        // White card with subtle animated Google-colour dots
        const gColors = [Color(0xFF4285F4), Color(0xFFEA4335), Color(0xFFFBBC04), Color(0xFF34A853)];
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE5E5E5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated 4-dot Google logo or spinner
              if (widget.isLoading)
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4285F4)))
              else SizedBox(
                width: 20, height: 20,
                child: Stack(
                  children: List.generate(4, (i) {
                    final angle = (i / 4) * math.pi * 2 + t * math.pi * 2;
                    final dx = math.cos(angle) * 6 + 6;
                    final dy = math.sin(angle) * 6 + 6;
                    return Positioned(
                      left: dx, top: dy,
                      child: Container(
                        width: 5, height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: gColors[i],
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(child: Text(widget.label,
                style: FreezmeTypography.button.copyWith(
                  color: const Color(0xFF1A1A1A), fontSize: 15),
                overflow: TextOverflow.ellipsis)),
            ],
          ),
        );

      case _AuthButtonVariant.email:
        // Aurora gradient with moving shimmer + sliding arrow
        final auroraAngle = t * math.pi * 2;
        final arrowSlide = _pressed ? 6.0 : 0.0;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment(math.cos(auroraAngle) * 0.8, -1),
              end: Alignment(-math.cos(auroraAngle) * 0.8, 1),
              colors: const [
                Color(0xFF4D2C91),
                Color(0xFF5E35A8),
                Color(0xFF3D2070),
                Color(0xFF4D2C91),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4D2C91).withValues(alpha: 0.45),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.isLoading)
                SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: textColor))
              else
                Icon(widget.icon, color: textColor, size: 20),
              const SizedBox(width: 12),
              Flexible(child: Text(widget.label,
                style: FreezmeTypography.button.copyWith(color: textColor, fontSize: 15),
                overflow: TextOverflow.ellipsis)),
              const Spacer(),
              if (!widget.isLoading)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  transform: Matrix4.translationValues(arrowSlide, 0, 0),
                  child: Icon(Icons.arrow_forward_rounded, color: textColor.withValues(alpha: 0.8), size: 18),
                ),
            ],
          ),
        );
    }
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
        // Send verification email in background — don't block the flow
        AuthService.instance.sendEmailVerification().catchError((_) {});
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

  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();
    final emailToUse = email.isNotEmpty ? email : null;

    final enteredEmail = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController(text: emailToUse);
        return AlertDialog(
          title: const Text('Reset Password'),
          content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(hintText: 'Enter your email'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Send Reset Link'),
            ),
          ],
        );
      },
    );

    if (enteredEmail == null || enteredEmail.isEmpty || !mounted) return;

    try {
      await AuthService.instance.sendPasswordReset(email: enteredEmail);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('If that email exists, a reset link has been sent.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send reset email. Please try again.')),
        );
      }
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

          // Forgot password link (sign-in mode only)
          if (!_isSignUp) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _forgotPassword,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Forgot Password?', style: TextStyle(fontSize: 13)),
              ),
            ),
          ],

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
