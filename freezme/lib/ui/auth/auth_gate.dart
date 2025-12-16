import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../theme.dart';
import '../../main.dart';
import '../components/freezme_logo.dart';
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

  // Typewriter effect
  final String _tagline = "Tonight. Not someday.";
  String _displayedTagline = "";
  int _taglineIndex = 0;
  Timer? _typewriterTimer;

  // User count animation
  int _displayedUserCount = 0;
  final int _targetUserCount = 12847;
  Timer? _countTimer;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _startTypewriter();
    _startUserCountAnimation();
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

  void _startTypewriter() {
    _typewriterTimer = Timer.periodic(const Duration(milliseconds: 80), (timer) {
      if (_taglineIndex < _tagline.length) {
        setState(() {
          _displayedTagline = _tagline.substring(0, _taglineIndex + 1);
          _taglineIndex++;
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _startUserCountAnimation() {
    const duration = Duration(milliseconds: 2000);
    const steps = 60;
    final increment = _targetUserCount / steps;
    var current = 0.0;

    _countTimer = Timer.periodic(
      Duration(milliseconds: duration.inMilliseconds ~/ steps),
      (timer) {
        current += increment;
        if (current >= _targetUserCount) {
          setState(() => _displayedUserCount = _targetUserCount);
          timer.cancel();
        } else {
          setState(() => _displayedUserCount = current.toInt());
        }
      },
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _pulseController.dispose();
    _floatController.dispose();
    _successController.dispose();
    _typewriterTimer?.cancel();
    _countTimer?.cancel();
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

      final googleUser = await google.authenticate();
      if (googleUser == null) return; // cancelled

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

  Future<void> _signInWithPhone() async {
    _hapticFeedback();
    final result = await _showPhoneAuthDialog();
    if (result == null || !mounted) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: result,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await FirebaseAuth.instance.signInWithCredential(credential);
          if (mounted) {
            await _showSuccessAndNavigate();
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          if (mounted) {
            setState(() => _isLoading = false);
            _showErrorSnackBar('Verification failed: ${e.message}');
          }
        },
        codeSent: (String verificationId, int? resendToken) async {
          if (mounted) {
            setState(() => _isLoading = false);
            final code = await _showOtpDialog();
            if (code != null && code.length == 6) {
              setState(() => _isLoading = true);
              try {
                final credential = PhoneAuthProvider.credential(
                  verificationId: verificationId,
                  smsCode: code,
                );
                await FirebaseAuth.instance.signInWithCredential(credential);
                if (mounted) {
                  await _showSuccessAndNavigate();
                }
              } catch (e) {
                if (mounted) {
                  _showErrorSnackBar('Invalid OTP');
                }
              } finally {
                if (mounted) {
                  setState(() => _isLoading = false);
                }
              }
            }
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Phone sign-in failed');
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithWhatsApp() async {
    _hapticFeedback();
    
    // WhatsApp login flow - uses phone verification
    final phone = await _showPhoneAuthDialog(isWhatsApp: true);
    if (phone == null || !mounted) return;

    // Open WhatsApp with a deep link for verification
    // In production, you'd use WhatsApp Business API
    final whatsappUrl = Uri.parse('https://wa.me/$phone');
    
    // Show info dialog
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF25D366).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.chat, color: Color(0xFF25D366)),
            ),
            const SizedBox(width: 12),
            const Text('WhatsApp Verification'),
          ],
        ),
        content: const Text(
          'We\'ll send you a verification code via WhatsApp. '
          'Make sure WhatsApp is installed on your device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (proceed != true) return;

    // Use phone auth with the provided number
    await _signInWithPhoneNumber(phone);
  }

  Future<void> _signInWithPhoneNumber(String phone) async {
    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await FirebaseAuth.instance.signInWithCredential(credential);
          if (mounted) {
            await _showSuccessAndNavigate();
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          if (mounted) {
            setState(() => _isLoading = false);
            _showErrorSnackBar('Verification failed');
          }
        },
        codeSent: (String verificationId, int? resendToken) async {
          if (mounted) {
            setState(() => _isLoading = false);
            final code = await _showOtpDialog(isWhatsApp: true);
            if (code != null && code.length == 6) {
              setState(() => _isLoading = true);
              try {
                final credential = PhoneAuthProvider.credential(
                  verificationId: verificationId,
                  smsCode: code,
                );
                await FirebaseAuth.instance.signInWithCredential(credential);
                if (mounted) {
                  await _showSuccessAndNavigate();
                }
              } catch (e) {
                if (mounted) {
                  _showErrorSnackBar('Invalid OTP');
                }
              } finally {
                if (mounted) {
                  setState(() => _isLoading = false);
                }
              }
            }
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Verification failed');
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

  Future<String?> _showPhoneAuthDialog({bool isWhatsApp = false}) async {
    final phoneController = TextEditingController();
    String countryCode = '+91';

    return showModalBottomSheet<String>(
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
                        color: isWhatsApp
                            ? const Color(0xFF25D366).withValues(alpha: 0.1)
                            : FreezmeColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isWhatsApp ? Icons.chat : Icons.phone,
                        color: isWhatsApp
                            ? const Color(0xFF25D366)
                            : FreezmeColors.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isWhatsApp ? 'WhatsApp Login' : 'Phone Login',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            isWhatsApp
                                ? 'Get OTP via WhatsApp'
                                : 'Get OTP via SMS',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButton<String>(
                        value: countryCode,
                        underline: const SizedBox(),
                        isDense: true,
                        items: const [
                          DropdownMenuItem(value: '+91', child: Text('🇮🇳 +91')),
                          DropdownMenuItem(value: '+1', child: Text('🇺🇸 +1')),
                          DropdownMenuItem(value: '+44', child: Text('🇬🇧 +44')),
                          DropdownMenuItem(value: '+971', child: Text('🇦🇪 +971')),
                        ],
                        onChanged: (value) {
                          setModalState(() => countryCode = value!);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          hintText: 'Phone number',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isWhatsApp
                                  ? const Color(0xFF25D366)
                                  : FreezmeColors.primary,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: () {
                      if (phoneController.text.length >= 10) {
                        Navigator.pop(
                          context,
                          '$countryCode${phoneController.text.trim()}',
                        );
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: isWhatsApp
                          ? const Color(0xFF25D366)
                          : FreezmeColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: Text(
                      isWhatsApp ? 'Send WhatsApp OTP' : 'Send SMS OTP',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
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

  Future<String?> _showOtpDialog({bool isWhatsApp = false}) async {
    final otpController = TextEditingController();

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
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
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 32),
              Icon(
                isWhatsApp ? Icons.chat : Icons.sms,
                size: 48,
                color: isWhatsApp
                    ? const Color(0xFF25D366)
                    : FreezmeColors.primary,
              ),
              const SizedBox(height: 16),
              const Text(
                'Enter Verification Code',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isWhatsApp
                    ? 'Check your WhatsApp for the 6-digit code'
                    : 'Check your SMS for the 6-digit code',
                style: TextStyle(color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: otpController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '• • • • • •',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isWhatsApp
                          ? const Color(0xFF25D366)
                          : FreezmeColors.primary,
                      width: 2,
                    ),
                  ),
                ),
                onChanged: (value) {
                  if (value.length == 6) {
                    Navigator.pop(context, value);
                  }
                },
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () {},
                child: Text(
                  'Resend Code',
                  style: TextStyle(
                    color: isWhatsApp
                        ? const Color(0xFF25D366)
                        : FreezmeColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
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
                        color: FreezmeColors.primary.withValues(alpha: 0.1),
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
      body: Stack(
        children: [
          // Animated gradient background - Frozen Creamy Theme
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFAF9FF), // creamy white with purple tint
                  Color(0xFFEDE9FE), // soft lavender
                  Color(0xFFF3E8FF), // very soft purple
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // Floating decorative circles
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
                          size: LogoSize.xl,
                          variant: LogoVariant.primary,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Big Headline - Intentional dating
                    const Text(
                      'Intentional dating\nfor soulful\nmatches',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                        height: 1.2,
                        letterSpacing: -0.5,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Subtitle
                    Text(
                      'Daily pools, mindful pacing, and authentic\nconnections that keep it real.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey.shade600,
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Feature pills
                    Column(
                      children: [
                        _buildFeaturePill(Icons.favorite_border_rounded, 'Curated daily matches'),
                        const SizedBox(height: 10),
                        _buildFeaturePill(Icons.chat_bubble_outline_rounded, 'Real conversations'),
                        const SizedBox(height: 10),
                        _buildFeaturePill(Icons.security_rounded, 'Accountability-first safety'),
                      ],
                    ),

                   const SizedBox(height: 32),

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
                            // Uses default gradient
                          ),
                          
                          const SizedBox(height: 12),
                          
                          // Continue with Google
                          PremiumButton(
                            variant: ButtonVariant.outlined,
                            icon: Icons.g_mobiledata_rounded,
                            label: 'Continue with Google',
                            onPressed: _isLoading ? null : _signInWithGoogle,
                            fullWidth: true,
                            textColor: const Color(0xFF6B7280), // Grey text for Google
                          ),
                          
                          const SizedBox(height: 12),
                          
                          // Continue with Email
                          PremiumButton(
                            icon: Icons.email_rounded,
                            label: 'Continue with Email',
                            onPressed: _isLoading ? null : _signInWithEmail,
                            fullWidth: true,
                            // Uses default gradient
                          ),
                          
                          const SizedBox(height: 20),
                          
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
                              color: Colors.black.withValues(alpha: 0.1),
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
                              color: const Color(0xFF22C55E).withValues(alpha: 0.4),
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
    );
  }

  Widget _buildDecorativeCircle(double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: FreezmeColors.primary.withValues(alpha: opacity),
      ),
    );
  }

  Widget _buildFeaturePill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: FreezmeColors.primary),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF374151),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactFeature(IconData icon, String label) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
              ),
            ],
          ),
          child: Icon(icon, color: FreezmeColors.primary, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required bool isPrimary,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [FreezmeColors.primary, Color(0xFF8B5CF6)],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: FreezmeColors.primary.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FilledButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 22),
          label: Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 56,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: FreezmeColors.primary,
          backgroundColor: Colors.white,
          side: BorderSide(color: FreezmeColors.primary.withValues(alpha: 0.3), width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
      ),
    );
  }

  Widget _buildSmallButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    Color? color,
  }) {
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20, color: color),
        label: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: color ?? Colors.black87,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: color ?? Colors.black87,
          backgroundColor: Colors.white,
          side: BorderSide(color: color ?? Colors.grey.shade300),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required Color backgroundColor,
    required Color textColor,
    Color? borderColor,
    bool useGradientText = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton(
        onPressed: () {
          HapticFeedback.lightImpact();
          onPressed?.call();
        },
        style: FilledButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: borderColor != null 
                ? BorderSide(color: borderColor, width: 1.5)
                : BorderSide.none,
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: useGradientText ? FreezmeColors.primary : textColor),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: useGradientText ? FreezmeColors.primary : textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
