import 'package:flutter/material.dart';
import '../theme.dart';
import '../../main.dart';
import '../components/freezme_logo.dart';

import 'package:go_router/go_router.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();

    // Auto-navigate after 2 seconds
    Future.delayed(const Duration(seconds: 2), _handleNavigation);
  }

  void _handleNavigation() {
    if (!mounted || _navigated) return;
    _navigated = true;
    
    final flow = AppFlowScope.of(context);
    flow.completeSplash();
    
    // Explicitly navigate using go_router based on the new flow state
    switch (flow.current) {
      case AppStage.dailyPool:
        context.go('/daily-pool');
        break;
      case AppStage.onboarding:
        context.go('/onboarding');
        break;
      default:
        context.go('/auth');
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: _handleNavigation,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFFF5F8), // Surface - light pink
                Color(0xFFF5E6F0), // Surface Alt - lavender pink
                Color(0xFFEDE4F5), // Subtle purple
              ],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
          child: SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated Logo - matching Auth page style
                    ScaleTransition(
                      scale: _pulseAnimation,
                      child: const FreezmeLogo(
                        size: LogoSize.hero, 
                        variant: LogoVariant.primary,
                        showText: false,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // App Name with gradient
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [FreezmeColors.primary, Color(0xFF8B5CF6)],
                      ).createShader(bounds),
                      child: const Text(
                        'FREEZME',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 6,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Tagline
                    Text(
                      'Tonight. Not someday.',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade600,
                        letterSpacing: 0.5,
                      ),
                    ),

                    const SizedBox(height: 80),

                    // Tap to continue hint
                    Text(
                      'Tap anywhere to continue',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
