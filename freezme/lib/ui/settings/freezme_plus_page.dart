import 'package:flutter/material.dart';
import '../../main.dart'; // For AppFlowScope
import '../design_system.dart';
import '../components/freezme_logo.dart';
import '../components/premium_components.dart';

class FreezmePlusPage extends StatelessWidget {
  const FreezmePlusPage({super.key});

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
          colors: [FreezmeDesignSystem.primary, FreezmeDesignSystem.secondary],
        ),
      ),
      (
        icon: Icons.favorite,
        title: 'Extra Vibes',
        description: 'Get 6 daily matches instead of 3 for more connections',
        gradient: const LinearGradient(
          colors: [FreezmeDesignSystem.secondary, FreezmeDesignSystem.accent],
        ),
      ),
      (
        icon: Icons.public,
        title: 'Global Visibility',
        description: 'Connect with people beyond your local area',
        gradient: const LinearGradient(
          colors: [FreezmeDesignSystem.accent, FreezmeDesignSystem.success],
        ),
      ),
      (
        icon: Icons.auto_awesome,
        title: 'Priority Match',
        description: 'Your profile gets shown first to your top matches',
        gradient: const LinearGradient(
          colors: [FreezmeDesignSystem.primary, Color(0xFF8B5FBF)],
        ),
      ),
    ];

    return Scaffold(
      backgroundColor: FreezmeDesignSystem.background,
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
                const Text('✨', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 12),
                Text(
                  'Level up your vibe',
                  style: FreezmeDesignSystem.h2.copyWith(
                    color: FreezmeDesignSystem.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Get premium features to enhance your dating experience',
                  style: FreezmeDesignSystem.body.copyWith(color: FreezmeDesignSystem.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                for (final feature in features) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: FreezmeDesignSystem.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
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
                          child: Icon(
                            feature.icon,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                feature.title,
                                style: FreezmeDesignSystem.bodySemiBold,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                feature.description,
                                style: FreezmeDesignSystem.small,
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.check, color: FreezmeDesignSystem.primary),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [FreezmeDesignSystem.primary, FreezmeDesignSystem.secondary],
                    ),
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Monthly Subscription',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: const [
                          Text(
                            '₹499',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            '/month',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Cancel anytime • No commitment',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: FreezmeDesignSystem.primary,
                          minimumSize: const Size.fromHeight(56),
                          shape: const StadiumBorder(),
                        ),
                        onPressed: () {},
                        child: const Text('Unlock Freezme+ ✨'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Join 10,000+ premium members finding meaningful connections',
                  style: FreezmeDesignSystem.caption,
                  textAlign: TextAlign.center,
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text('Terms & Conditions'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
