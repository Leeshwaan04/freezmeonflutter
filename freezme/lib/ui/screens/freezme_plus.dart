import 'package:flutter/material.dart';
import '../theme.dart';
import '../../controllers/flow_controller.dart';
import '../widgets/freezme_logo.dart';

class FreezeMePlusPage extends StatelessWidget {
  const FreezeMePlusPage({super.key});

  @override
  Widget build(BuildContext context) {
    final flow = AppFlowScope.of(context, listen: false);
    final features = [
      (
        icon: Icons.access_time,
        title: 'Extend Freeze',
        description:
            'Pause your profile for up to 7 days without losing matches',
        gradient: const LinearGradient(
          colors: [FreezmeColors.primary, FreezmeColors.secondary],
        )
      ),
      (
        icon: Icons.favorite,
        title: 'Extra Vibes',
        description: 'Get 6 daily matches instead of 3 for more connections',
        gradient: const LinearGradient(
          colors: [FreezmeColors.secondary, FreezmeColors.accent],
        )
      ),
      (
        icon: Icons.public,
        title: 'Global Visibility',
        description: 'Connect with people beyond your local area',
        gradient: const LinearGradient(
          colors: [FreezmeColors.accent, FreezmeColors.success],
        )
      ),
      (
        icon: Icons.auto_awesome,
        title: 'Priority Match',
        description: 'Your profile gets shown first to your top matches',
        gradient: const LinearGradient(
          colors: [FreezmeColors.primary, Color(0xFF8B5FBF)],
        )
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: flow.pop,
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: FreezmeGradients.backgroundSoft,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                const FreezmeLogo(size: LogoSize.sm, showText: true),
                const SizedBox(height: 24),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: FreezmeColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'FREEZME+',
                    style: TextStyle(
                      color: FreezmeColors.primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Elevate Your Vibe',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: FreezmeColors.neutral,
                        fontWeight: FontWeight.w700,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Unlock premium features and find your\nperfect connection faster',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: FreezmeColors.muted, height: 1.5),
                ),
                const SizedBox(height: 40),
                for (final feature in features) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          height: 56,
                          width: 56,
                          decoration: BoxDecoration(
                            gradient: feature.gradient,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child:
                              Icon(feature.icon, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                feature.title,
                                style: const TextStyle(
                                  color: FreezmeColors.neutral,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                feature.description,
                                style: const TextStyle(
                                  color: FreezmeColors.muted,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                // Vibe Boosts section
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Quick Vibe Boosts',
                    style: TextStyle(
                      color: FreezmeColors.neutral,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _VibeBoostCard(
                        amount: 5,
                        price: '₹99',
                        onTap: () async {
                          _trackEvent('purchase_credits_started', {'amount': 5});
                          await flow.buyCredits(5);
                          if (context.mounted) _showPurchaseSuccess(context, '5 Vibez Added!');
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _VibeBoostCard(
                        amount: 15,
                        price: '₹199',
                        onTap: () async {
                          _trackEvent('purchase_credits_started', {'amount': 15});
                          await flow.buyCredits(15);
                          if (context.mounted) _showPurchaseSuccess(context, '15 Vibez Added!');
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: flow.isPremium ? FreezmeGradients.premium : FreezmeGradients.primary,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: FreezmeColors.primary.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        flow.isPremium ? 'Active Subscription' : 'Most Popular Plan',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        flow.isPremium ? 'FREEZME+ PRO' : '₹499 / Month',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (!flow.isPremium)
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: FreezmeColors.primary,
                            minimumSize: const Size.fromHeight(56),
                            shape: const StadiumBorder(),
                          ),
                          onPressed: () async {
                            _trackEvent('subscription_started', {'plan': 'monthly_499'});
                            await flow.purchasePremium();
                            if (context.mounted) _showPurchaseSuccess(context, 'Welcome to Freezme+!');
                          },
                          child: const Text(
                            'Get Freezme+ Now',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        )
                      else
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'Premium Active',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 16),
                      const Text(
                        'Recurring billing. Cancel anytime.',
                        style: TextStyle(color: Colors.white60, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPurchaseSuccess(BuildContext context, String message) {
    // Show premium overlay animation
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        Future.delayed(const Duration(seconds: 2), () {
          if (context.mounted) Navigator.pop(context);
        });
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: FreezmeColors.secondary.withValues(alpha: 0.4),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: FreezmeColors.secondary,
                  size: 64,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        );
      },
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.star, color: Colors.white),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
        backgroundColor: FreezmeColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _trackEvent(String name, Map<String, dynamic> props) {
    // Mock Analytics integration (Mixpanel)
    debugPrint('ANALYTICS [EVENT]: $name | PROPS: $props');
  }
}

class _VibeBoostCard extends StatelessWidget {
  final int amount;
  final String price;
  final VoidCallback onTap;

  const _VibeBoostCard({
    required this.amount,
    required this.price,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: FreezmeColors.border),
        ),
        child: Column(
          children: [
            Text(
              '+$amount',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: FreezmeColors.secondary,
              ),
            ),
            const Text(
              'Vibez',
              style: TextStyle(
                fontSize: 12,
                color: FreezmeColors.muted,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: FreezmeColors.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                price,
                style: const TextStyle(
                  color: FreezmeColors.secondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
