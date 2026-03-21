import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../theme.dart';
import '../../main.dart';
import '../components/freezme_logo.dart';
import '../components/aurora_background.dart';
import '../components/premium_components.dart';

class AuthGatePage extends StatefulWidget {
  const AuthGatePage({super.key});

  @override
  State<AuthGatePage> createState() => _AuthGatePageState();
}

class _AuthGatePageState extends State<AuthGatePage>
    with TickerProviderStateMixin {
  bool _isLoading = false;
  bool _showSuccess = false;

  // Animations
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late AnimationController _floatController;
  late AnimationController _successController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _floatAnimation;
  late Animation<double> _successScaleAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _floatAnimation = Tween<double>(begin: -10, end: 10).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
    _floatController.repeat(reverse: true);

    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _successScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _successController, curve: Curves.elasticOut),
    );

    Future.delayed(const Duration(milliseconds: 200), () {
      _fadeController.forward();
      _slideController.forward();
    });
  }


  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _pulseController.dispose();
    _floatController.dispose();
    _successController.dispose();
    super.dispose();
  }

  void _hapticFeedback() {
    HapticFeedback.lightImpact();
  }

  void _heavyHaptic() {
    HapticFeedback.heavyImpact();
  }

  Future<void> _showSuccessAndNavigate() async {
    _heavyHaptic();
    setState(() => _showSuccess = true);
    await _successController.forward();
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      AppFlowScope.of(context).startOnboarding();
    }
  }

  Future<void> _signInWithApple() async {
    _hapticFeedback();
    setState(() => _isLoading = true);
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oAuthProvider = OAuthProvider('apple.com');
      final authCredential = oAuthProvider.credential(
        idToken: credential.identityToken,
        accessToken: credential.authorizationCode,
      );

      await FirebaseAuth.instance.signInWithCredential(authCredential);

      if (mounted) {
        await _showSuccessAndNavigate();
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Apple Sign-in failed');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    _hapticFeedback();
    setState(() => _isLoading = true);
    try {
      final google = GoogleSignIn.instance;
      await google.initialize();

      final googleUser = await google.authenticate(); // cancelled

      final googleAuth = googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      if (mounted) {
        await _showSuccessAndNavigate();
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Google Sign-in failed');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }


  Future<void> _signInWithEmail() async {
    _hapticFeedback();
    final result = await _showEmailDialog();
    if (result == null || !mounted) return;

    setState(() => _isLoading = true);
    try {
      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: result['email']!,
          password: result['password']!,
        );
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found') {
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: result['email']!,
            password: result['password']!,
          );
        } else {
          rethrow;
        }
      }

      if (mounted) {
        await _showSuccessAndNavigate();
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Sign-in failed. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInAnonymously() async {
    _hapticFeedback();
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInAnonymously();

      if (mounted) {
        await _showSuccessAndNavigate();
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Guest sign-in failed');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    HapticFeedback.vibrate();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }





  Future<Map<String, String>?> _showEmailDialog() async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool isPasswordVisible = false;

    return showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: FreezmeColors.primary.withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.email_rounded,
                        color: FreezmeColors.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Email Login',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Sign in or create account',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: FreezmeColors.primary,
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: !isPasswordVisible,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        isPasswordVisible
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setModalState(() {
                          isPasswordVisible = !isPasswordVisible;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: FreezmeColors.primary,
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: () {
                      if (emailController.text.isNotEmpty &&
                          passwordController.text.length >= 6) {
                        Navigator.pop(context, {
                          'email': emailController.text.trim(),
                          'password': passwordController.text,
                        });
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: FreezmeColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: const Text(
                      'Continue',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: AuroraBackground(
        isPremium: false, // Default look for login
        child: Stack(
          children: [
            // Animated gradient background - Frozen Creamy Theme
            // Static background removed to show AuroraBackground
            const SizedBox.expand(),


          AnimatedBuilder(
            animation: _floatAnimation,
            builder: (context, child) => Stack(
              children: [
                Positioned(
                  top: size.height * 0.1 + _floatAnimation.value,
                  right: -30,
                  child: _buildDecorativeCircle(120, 0.1),
                ),
                Positioned(
                  top: size.height * 0.3 - _floatAnimation.value,
                  left: -40,
                  child: _buildDecorativeCircle(80, 0.08),
                ),
                Positioned(
                  bottom: size.height * 0.15 + _floatAnimation.value * 0.5,
                  right: 20,
                  child: _buildDecorativeCircle(60, 0.06),
                ),
              ],
            ),
          ),

          // Main content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    SizedBox(height: size.height * 0.06),

                    // Animated Logo
                    ScaleTransition(
                      scale: _pulseAnimation,
                      child: const Hero(
                        tag: 'freezme_logo_auth',
                        child: FreezmeLogo(
                          size: LogoSize.hero,
                          variant: LogoVariant.primary,
                        ),
                      ),
                    ),

                    // Brand Text
                    const Text(
                      'FREEZME',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4.0,
                        color: FreezmeColors.primary,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Big Headline - Intentional dating
                    const Text(
                      'Intentional dating\nfor soulful matches',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                        height: 1.15,
                        letterSpacing: -1.0,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Subtitle
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        'Daily pools, mindful pacing, and authentic connections that keep it real.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                          height: 1.5,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Feature pills - Refined Alignment to match original vertical stack but with better style
                    Column(
                      children: [
                        _buildFeaturePill(Icons.favorite_rounded, 'Curated daily matches'),
                        const SizedBox(height: 12),
                        _buildFeaturePill(Icons.chat_bubble_rounded, 'Real conversations'),
                        const SizedBox(height: 12),
                        _buildFeaturePill(Icons.security_rounded, 'Accountability-first safety'),
                      ],
                    ),

                   const SizedBox(height: 48),

                    // Sign-in buttons
                    SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        children: [
                          // Continue with Apple
                          PremiumButton(
                            icon: Icons.apple,
                            label: 'Continue with Apple',
                            onPressed: _isLoading ? null : _signInWithApple,
                            fullWidth: true,
                            variant: ButtonVariant.filled, 
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Continue with Google
                          PremiumButton(
                            variant: ButtonVariant.outlined,
                            icon: Icons.g_mobiledata_rounded,
                            label: 'Continue with Google',
                            onPressed: _isLoading ? null : _signInWithGoogle,
                            fullWidth: true,
                            textColor: const Color(0xFF4B5563),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Continue with Email
                          PremiumButton(
                            icon: Icons.email_rounded,
                            label: 'Continue with Email',
                            onPressed: _isLoading ? null : _signInWithEmail,
                            fullWidth: true,
                            variant: ButtonVariant.filled,
                          ),
                          
                          const SizedBox(height: 32),
                          
                          // Guest mode
                          TextButton(
                            onPressed: _isLoading ? null : _signInAnonymously,
                            child: Text(
                              'Your vibe begins with one tap 👆',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Loading indicator
                    if (_isLoading)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(25),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: FreezmeColors.primary,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('Signing in...'),
                          ],
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Terms
                    Text(
                      'By continuing, you agree to our Terms & Privacy Policy',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),

          // Success overlay
          if (_showSuccess)
            Container(
              color: Colors.white,
              child: Center(
                child: ScaleTransition(
                  scale: _successScaleAnimation,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4ADE80), Color(0xFF22C55E)],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF22C55E).withAlpha(102),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 50,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Welcome! 🎉',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF22C55E),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Setting up your profile...',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
  }

  Widget _buildDecorativeCircle(double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: FreezmeColors.primary.withAlpha((opacity * 255).round()),
      ),
    );
  }

  Widget _buildFeaturePill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(204),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: FreezmeColors.primary),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
        ],
      ),
    );
  }

}
