import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../main.dart';
import '../design_system.dart';
import '../components/freezme_logo.dart';
import '../components/premium_components.dart';

class FreezmePlusPage extends StatefulWidget {
  const FreezmePlusPage({super.key});

  @override
  State<FreezmePlusPage> createState() => _FreezmePlusPageState();
}

class _FreezmePlusPageState extends State<FreezmePlusPage> with TickerProviderStateMixin {
  int _selectedPlan = 0; // 0 = weekly, 1 = monthly
  late AnimationController _shimmerController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final flow = AppFlowScope.of(context, listen: false);
    
    final features = [
      (
        icon: Icons.bolt_rounded,
        title: 'Unlimited Vibes',
        description: 'Send unlimited likes every day',
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
        ),
      ),
      (
        icon: Icons.favorite_rounded,
        title: 'Extra Vibes',
        description: 'Get 6 daily matches instead of 3 for more connections',
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFD93D), Color(0xFFFF6B6B)],
        ),
      ),
      (
        icon: Icons.public_rounded,
        title: 'Global Visibility',
        description: 'Connect with people beyond your local area',
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6BCB77), Color(0xFF4D96FF)],
        ),
      ),
      (
        icon: Icons.auto_awesome_rounded,
        title: 'Priority Match',
        description: 'Your profile gets shown first to your top matches',
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [FreezmeDesignSystem.primary, Color(0xFFB721FF)],
        ),
      ),
      (
        icon: Icons.visibility_rounded,
        title: 'See Who Likes You',
        description: 'View all profiles that liked you before matching',
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
        ),
      ),
      (
        icon: Icons.undo_rounded,
        title: 'Rewind',
        description: 'Accidentally swiped left? Undo your last action',
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF11998E), Color(0xFF38EF7D)],
        ),
      ),
    ];

    return Scaffold(
      backgroundColor: FreezmeDesignSystem.background,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              FreezmeDesignSystem.primary.withValues(alpha: 0.05),
              FreezmeDesignSystem.background,
            ],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              // App Bar
              SliverAppBar(
                backgroundColor: Colors.transparent,
                leading: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.chevron_left, color: FreezmeDesignSystem.textPrimary),
                  ),
                  onPressed: flow.pop,
                ),
                pinned: false,
                floating: true,
              ),
              
              // Content
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      // Hero Section with animated sparkles
                      _buildHeroSection(),
                      
                      const SizedBox(height: 32),
                      
                      // Features List
                      ...features.asMap().entries.map((entry) => 
                        _buildFeatureCard(entry.value, entry.key)
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Pricing Section
                      _buildPricingSection(),
                      
                      const SizedBox(height: 24),
                      
                      // Social Proof
                      _buildSocialProof(),
                      
                      const SizedBox(height: 16),
                      
                      // Terms
                      TextButton(
                        onPressed: () {},
                        child: Text(
                          'Terms & Conditions',
                          style: FreezmeDesignSystem.caption.copyWith(
                            color: FreezmeDesignSystem.textTertiary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    return Column(
      children: [
        // Animated Logo
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: child,
            );
          },
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [FreezmeDesignSystem.primary, FreezmeDesignSystem.secondary],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: FreezmeDesignSystem.primary.withValues(alpha: 0.4),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Center(
              child: Text(
                '✨',
                style: TextStyle(fontSize: 48),
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Title with gradient
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [FreezmeDesignSystem.primary, FreezmeDesignSystem.secondary],
          ).createShader(bounds),
          child: Text(
            'Freezme+',
            style: FreezmeDesignSystem.display.copyWith(
              color: Colors.white,
              fontSize: 36,
            ),
          ),
        ),
        
        const SizedBox(height: 8),
        
        Text(
          'Unlock premium features to find\nyour perfect match faster',
          style: FreezmeDesignSystem.body.copyWith(
            color: FreezmeDesignSystem.textSecondary,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFeatureCard(dynamic feature, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 100)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: FreezmeDesignSystem.border.withValues(alpha: 0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon Container
            Container(
              height: 52,
              width: 52,
              decoration: BoxDecoration(
                gradient: feature.gradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: (feature.gradient as LinearGradient).colors.first.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                feature.icon,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    feature.title,
                    style: FreezmeDesignSystem.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    feature.description,
                    style: FreezmeDesignSystem.caption.copyWith(
                      color: FreezmeDesignSystem.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            // Check
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: FreezmeDesignSystem.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: FreezmeDesignSystem.success,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPricingSection() {
    return Column(
      children: [
        // Plan Toggle
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: FreezmeDesignSystem.surfaceAlt,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedPlan = 0);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _selectedPlan == 0 ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: _selectedPlan == 0
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Weekly',
                          style: FreezmeDesignSystem.bodyMedium.copyWith(
                            fontWeight: _selectedPlan == 0 ? FontWeight.w600 : FontWeight.normal,
                            color: _selectedPlan == 0 
                                ? FreezmeDesignSystem.textPrimary 
                                : FreezmeDesignSystem.textSecondary,
                          ),
                        ),
                        if (_selectedPlan == 0)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [FreezmeDesignSystem.success, Color(0xFF38EF7D)],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'BEST VALUE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedPlan = 1);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _selectedPlan == 1 ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: _selectedPlan == 1
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      'Monthly',
                      textAlign: TextAlign.center,
                      style: FreezmeDesignSystem.bodyMedium.copyWith(
                        fontWeight: _selectedPlan == 1 ? FontWeight.w600 : FontWeight.normal,
                        color: _selectedPlan == 1 
                            ? FreezmeDesignSystem.textPrimary 
                            : FreezmeDesignSystem.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Pricing Card
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    FreezmeDesignSystem.primary,
                    Color(0xFFB721FF),
                    FreezmeDesignSystem.secondary,
                  ],
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: FreezmeDesignSystem.primary.withValues(alpha: 0.4),
                    blurRadius: 25,
                    spreadRadius: 0,
                    offset: const Offset(0, 12),
                  ),
                  BoxShadow(
                    color: FreezmeDesignSystem.secondary.withValues(alpha: 0.3),
                    blurRadius: 40,
                    spreadRadius: 0,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: child,
            );
          },
          child: Column(
            children: [
              // Plan type
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _selectedPlan == 0 ? 'Weekly Subscription' : 'Monthly Subscription',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Price
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '₹',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _selectedPlan == 0 ? '149' : '499',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 56,
                      fontWeight: FontWeight.bold,
                      height: 1,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _selectedPlan == 0 ? '/week' : '/month',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              
              if (_selectedPlan == 0) ...[
                const SizedBox(height: 8),
                Text(
                  'Save 25% compared to monthly',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              
              const SizedBox(height: 16),
              
              // Benefits
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildPricingBenefit(Icons.check_circle, 'Cancel anytime'),
                  const SizedBox(width: 16),
                  _buildPricingBenefit(Icons.check_circle, 'No commitment'),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // CTA Button
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    PremiumSnackBar.show(
                      context, 
                      '🎉 Coming soon! Payments will be enabled shortly.',
                      type: SnackBarType.info,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: FreezmeDesignSystem.primary,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Unlock Freezme+',
                        style: FreezmeDesignSystem.button.copyWith(
                          color: FreezmeDesignSystem.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('✨', style: TextStyle(fontSize: 20)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPricingBenefit(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 16),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildSocialProof() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FreezmeDesignSystem.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          // Avatars Stack
          SizedBox(
            height: 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                for (int i = 0; i < 5; i++)
                  Positioned(
                    left: i * 24.0 + 40,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            FreezmeDesignSystem.primary.withValues(alpha: 0.3 + (i * 0.15)),
                            FreezmeDesignSystem.secondary.withValues(alpha: 0.3 + (i * 0.15)),
                          ],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.person, color: Colors.white, size: 18),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ...List.generate(5, (i) => Icon(
                Icons.star_rounded,
                color: const Color(0xFFFFD700),
                size: 20,
              )),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Join 10,000+ premium members',
            style: FreezmeDesignSystem.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Finding meaningful connections every day',
            style: FreezmeDesignSystem.caption.copyWith(
              color: FreezmeDesignSystem.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
