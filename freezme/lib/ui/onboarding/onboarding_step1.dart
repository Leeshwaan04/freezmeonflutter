import 'package:flutter/material.dart';
import '../theme.dart';

class OnboardingStep1 extends StatelessWidget {
  const OnboardingStep1({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: FreezmeGradients.backgroundSoft,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(FreezmeInsets.pageGutter),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // Icon/Illustration
              Container(
                width: 200,
                height: 200,
                decoration: const BoxDecoration(
                  gradient: FreezmeGradients.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.bolt,
                  size: 100,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: FreezmeInsets.sectionSpacing),

              // Title
              const Text(
                'Spontaneous Connections',
                style: FreezmeTypography.display,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Description
              const Text(
                'Find people who are free tonight, not just someday.',
                style: FreezmeTypography.bodyMuted,
                textAlign: TextAlign.center,
              ),

              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}
