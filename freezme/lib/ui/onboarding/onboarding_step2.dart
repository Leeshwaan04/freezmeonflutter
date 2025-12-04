import 'package:flutter/material.dart';
import '../theme.dart';

class OnboardingStep2 extends StatelessWidget {
  const OnboardingStep2({super.key});

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
                decoration: BoxDecoration(
                  gradient: FreezmeGradients.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.favorite,
                  size: 100,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: FreezmeInsets.sectionSpacing),

              // Title
              const Text(
                'Vibe Check',
                style: FreezmeTypography.display,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Description
              const Text(
                'See who matches your energy right now.',
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
