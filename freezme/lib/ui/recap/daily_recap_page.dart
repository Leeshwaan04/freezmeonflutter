import 'package:flutter/material.dart';
import '../../main.dart'; // For AppFlowScope
import '../design_system.dart';
import '../components/freezme_logo.dart';

class DailyRecapPage extends StatelessWidget {
  const DailyRecapPage({super.key});

  @override
  Widget build(BuildContext context) {
    final flow = AppFlowScope.of(context, listen: false);
    final stats = [
      (
        label: 'Vibes',
        value: flow.matches.length.toString(),
        icon: Icons.favorite,
        gradient: const LinearGradient(
          colors: [FreezmeDesignSystem.primary, FreezmeDesignSystem.secondary],
        ),
      ),
      (
        label: 'Freezes',
        value: '2', // Mock
        icon: Icons.ac_unit,
        gradient: const LinearGradient(
          colors: [FreezmeDesignSystem.secondary, FreezmeDesignSystem.accent],
        ),
      ),
      (
        label: 'Chats',
        value: '5', // Mock
        icon: Icons.chat_bubble,
        gradient: const LinearGradient(
          colors: [FreezmeDesignSystem.accent, FreezmeDesignSystem.success],
        ),
      ),
      (
        label: 'Score',
        value: '98', // Mock
        icon: Icons.show_chart,
        gradient: const LinearGradient(
          colors: [Color(0xFF8B5FBF), FreezmeDesignSystem.primary],
        ),
      ),
    ];

    return Scaffold(
      backgroundColor: FreezmeDesignSystem.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: FreezmeGradients.backgroundSoft,
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 24,
                  ),
                  child: Column(
                    children: [
                      const FreezmeLogo(size: LogoSize.sm, showText: true),
                      const SizedBox(height: 20),
                      const Text('✨', style: TextStyle(fontSize: 56)),
                      const SizedBox(height: 12),
                      Text(
                        'Your Daily Recap',
                        style: FreezmeDesignSystem.h2.copyWith(
                          color: FreezmeDesignSystem.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Here\'s how your vibe journey is going',
                        style: FreezmeDesignSystem.body.copyWith(color: FreezmeDesignSystem.textSecondary),
                      ),
                      const SizedBox(height: 24),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                        itemCount: stats.length,
                        itemBuilder: (context, index) {
                          final stat = stats[index];
                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  height: 56,
                                  width: 56,
                                  decoration: BoxDecoration(
                                    gradient: stat.gradient,
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Icon(
                                    stat.icon,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  stat.value,
                                  style: FreezmeDesignSystem.h2.copyWith(
                                    color: FreezmeDesignSystem.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  stat.label,
                                  style: FreezmeDesignSystem.caption,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Today\'s Highlights',
                              style: FreezmeDesignSystem.h3.copyWith(
                                color: FreezmeDesignSystem.primary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const _RecapBullet(
                              color: FreezmeDesignSystem.primary,
                              text:
                                  'You had a great vibe date that turned into a chat! 💜',
                            ),
                            const SizedBox(height: 8),
                            _RecapBullet(
                              color: FreezmeDesignSystem.secondary,
                              text:
                                  '${flow.matches.length} people viewed your profile today',
                            ),
                            const SizedBox(height: 8),
                            const _RecapBullet(
                              color: FreezmeDesignSystem.accent,
                              text:
                                  'You\'re in the top 10% most active users this week! 🎉',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              FreezmeDesignSystem.primary,
                              FreezmeDesignSystem.secondary,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: const [
                            Text('💫', style: TextStyle(fontSize: 32)),
                            SizedBox(height: 12),
                            Text(
                              'The best connections happen when you\'re your authentic self 💜',
                              style: TextStyle(
                                color: Colors.white,
                                fontStyle: FontStyle.italic,
                                height: 1.4,
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: FreezmeDesignSystem.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(56),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: () => flow.returnToPool(resetIndex: true),
                  icon: const Icon(Icons.chevron_right),
                  label: const Text('See Tomorrow\'s Vibes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecapBullet extends StatelessWidget {
  const _RecapBullet({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 8,
          width: 8,
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: FreezmeDesignSystem.body.copyWith(color: FreezmeDesignSystem.textPrimary),
          ),
        ),
      ],
    );
  }
}
