import 'dart:async';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../../controllers/flow_controller.dart';
import '../widgets/freezme_logo.dart';
import '../widgets/floating_orbs.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _introController;
  late final AnimationController _rotationController;
  late final AnimationController _textController;
  late final AnimationController _backgroundController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;
  late final Animation<Offset> _textOffsetAnimation;
  late final Animation<double> _textOpacityAnimation;
  late final Animation<Color?> _gradientStart;
  late final Animation<Color?> _gradientEnd;
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _introController,
      curve: Curves.easeOut,
    );

    _opacityAnimation = CurvedAnimation(
      parent: _introController,
      curve: Curves.easeOut,
    );

    _textOpacityAnimation = CurvedAnimation(
      parent: _textController,
      curve: Curves.easeOut,
    );

    _textOffsetAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _textController,
        curve: Curves.easeOut,
      ),
    );

    _introController.forward();
    _rotationController.repeat();
    _backgroundController.repeat(reverse: true);

    _gradientStart = ColorTween(
      begin: FreezmeColors.surface,
      end: FreezmeColors.surfaceAlt,
    ).animate(
      CurvedAnimation(
        parent: _backgroundController,
        curve: Curves.easeInOut,
      ),
    );

    _gradientEnd = ColorTween(
      begin: FreezmeColors.surfaceAlt,
      end: FreezmeColors.surface,
    ).animate(
      CurvedAnimation(
        parent: _backgroundController,
        curve: Curves.easeInOut,
      ),
    );

    Future<void>.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _textController.forward();
      }
    });

    _timer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        AppFlowScope.of(context, listen: false).completeSplash();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _introController.dispose();
    _rotationController.dispose();
    _textController.dispose();
    _backgroundController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _backgroundController,
        builder: (context, _) {
          final gradientStart = _gradientStart.value ?? FreezmeColors.surface;
          final gradientEnd = _gradientEnd.value ?? FreezmeColors.surfaceAlt;
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [gradientStart, gradientEnd],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                FloatingOrbs(progress: _backgroundController.value),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FadeTransition(
                        opacity: _opacityAnimation,
                        child: ScaleTransition(
                          scale: _scaleAnimation,
                          child: RotationTransition(
                            turns: Tween<double>(begin: 0, end: 1).animate(
                              CurvedAnimation(
                                parent: _rotationController,
                                curve: Curves.linear,
                              ),
                            ),
                            child: const SizedBox(
                              height: 120,
                              width: 120,
                              child: Center(
                                child: FreezmeLogo(size: LogoSize.lg),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      FadeTransition(
                        opacity: _textOpacityAnimation,
                        child: SlideTransition(
                          position: _textOffsetAnimation,
                          child: Column(
                            children: [
                              Text(
                                'FREEZME',
                                style: FreezmeTypography.title.copyWith(
                                  letterSpacing: 1.2,
                                  color: FreezmeColors.primary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Where Compatibility Meets Real Connection 💜',
                                textAlign: TextAlign.center,
                                style: FreezmeTypography.subtitle,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
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
