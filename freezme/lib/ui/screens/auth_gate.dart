import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../../controllers/flow_controller.dart';
import '../../core/app_stage.dart';
import '../widgets/freezme_logo.dart';

class AuthGatePage extends StatelessWidget {
  const AuthGatePage({super.key});

  static const _highlights = [
    (icon: Icons.favorite_outline, label: 'Curated daily matches'),
    (icon: Icons.videocam_outlined, label: '1:1 video vibes'),
    (icon: Icons.spa_outlined, label: 'Mindful prompts & check-ins'),
  ];

  @override
  Widget build(BuildContext context) {
    final flow = AppFlowScope.of(context, listen: false);
    final cardShadow = FreezmeColors.primary.withValues(alpha: 0.08);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: FreezmeGradients.backgroundSoft,
        ),
        child: SafeArea(
          child: Stack(
            children: [
              const _AuthBackgroundDecor(),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: FreezmeInsets.pageGutter,
                    vertical: FreezmeInsets.sectionSpacing,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: FreezmeInsets.elementSpacing * 1.5,
                            vertical: FreezmeInsets.sectionSpacing * 1.4,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              FreezmeInsets.cardRadius,
                            ),
                            gradient: const LinearGradient(
                              colors: [
                                Colors.white,
                                FreezmeColors.surface,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(
                              color: FreezmeColors.border,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: cardShadow,
                                blurRadius: 36,
                                offset: const Offset(0, 18),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: FreezmeGradients.primary,
                                ),
                                child: const FreezmeLogo(
                                  size: LogoSize.md,
                                  variant: LogoVariant.white,
                                ),
                              ),
                              const SizedBox(
                                height: FreezmeInsets.sectionSpacing,
                              ),
                              Text(
                                'Intentional dating for soulful matches',
                                textAlign: TextAlign.center,
                                style: FreezmeTypography.title.copyWith(
                                  color: FreezmeColors.neutral,
                                ),
                              ),
                              const SizedBox(
                                height: FreezmeInsets.elementSpacing,
                              ),
                              const Text(
                                'Freezme pairs thoughtful prompts, science-backed compatibility, and mindful pacing so every connection feels like it’s meant to be.',
                                textAlign: TextAlign.center,
                                style: FreezmeTypography.bodyMuted,
                              ),
                              const SizedBox(
                                height: FreezmeInsets.sectionSpacing,
                              ),
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: FreezmeInsets.elementSpacing,
                                runSpacing: FreezmeInsets.elementSpacing,
                                children: [
                                  for (final item in _highlights)
                                    _AuthHighlightBadge(
                                      icon: item.icon,
                                      label: item.label,
                                    ),
                                ] ,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(
                            height: FreezmeInsets.sectionSpacing * 1.2),
                        _AuthButton(
                          label: 'Continue with Apple',
                          icon: Icons.apple,
                          background: Colors.black,
                          foreground: Colors.white,
                          onTap: flow.startOnboarding,
                        ),
                        const SizedBox(height: FreezmeInsets.elementSpacing),
                        _AuthButton(
                          label: 'Continue with Google',
                          icon: Icons.g_mobiledata,
                          foreground: FreezmeColors.neutral,
                          background: Colors.white,
                          border: const BorderSide(
                            color: FreezmeColors.border,
                            width: 2,
                          ),
                          onTap: flow.startOnboarding,
                        ),
                        const SizedBox(height: FreezmeInsets.elementSpacing),
                        _AuthButton(
                          label: 'Continue with Email',
                          icon: Icons.mail_outline,
                          gradient: FreezmeGradients.primary,
                          foreground: Colors.white,
                          onTap: flow.startOnboarding,
                        ),
                        const SizedBox(height: FreezmeInsets.sectionSpacing),
                        const Text(
                          'Your vibe begins with one tap 💫',
                          style: FreezmeTypography.bodyMuted,
                        ),
                        const SizedBox(height: FreezmeInsets.elementSpacing),
                        Text.rich(
                          TextSpan(
                            text: 'By continuing you agree to our ',
                            style: FreezmeTypography.bodyMuted.copyWith(
                              fontSize: 13,
                            ),
                            children: const [
                              TextSpan(
                                text: 'Terms',
                                style: TextStyle(
                                  color: FreezmeColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              TextSpan(text: ' and '),
                              TextSpan(
                                text: 'Privacy Policy',
                                style: TextStyle(
                                  color: FreezmeColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              TextSpan(text: '.'),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (kDebugMode) ...[
                          const SizedBox(height: FreezmeInsets.sectionSpacing),
                          const Text(
                            'Dev Verification Shortcuts:',
                            style: TextStyle(
                              color: FreezmeColors.muted,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: FreezmeInsets.elementSpacing),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final mission in LifestyleArchetype.values)
                                ActionChip(
                                  label: Text(mission.name),
                                  onPressed: () {
                                    flow.setLifestyleArchetype(mission);
                                    flow.replaceStack([AppStage.dailyPool]);
                                  },
                                ),
                            ],
                          ),
                          const SizedBox(height: FreezmeInsets.elementSpacing),
                          TextButton(
                            onPressed: flow.openDeveloperMenu,
                            child: const Text('Open Developer Preview'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthHighlightBadge extends StatelessWidget {
  const _AuthHighlightBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: FreezmeInsets.elementSpacing,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white,
        border: Border.all(color: FreezmeColors.border),
        boxShadow: [
          BoxShadow(
            color: FreezmeColors.primary.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: FreezmeColors.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: FreezmeTypography.body.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthBackgroundDecor extends StatelessWidget {
  const _AuthBackgroundDecor();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Positioned(
              top: -120,
              left: -80,
              child: Container(
                width: 240,
                height: 240,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: FreezmeGradients.primary,
                ),
              ),
            ),
            Positioned(
              bottom: -140,
              right: -60,
              child: Container(
                width: 260,
                height: 260,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: FreezmeGradients.accent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthButton extends StatelessWidget {
  const _AuthButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.background,
    this.foreground,
    this.gradient,
    this.border,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? background;
  final Color? foreground;
  final Gradient? gradient;
  final BorderSide? border;

  @override
  Widget build(BuildContext context) {
    final textColor = foreground ?? Colors.white;
    final borderSide = border;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          decoration: BoxDecoration(
            gradient: gradient,
            color: gradient == null ? background : null,
            borderRadius: BorderRadius.circular(999),
            border:
                borderSide != null ? Border.fromBorderSide(borderSide) : null,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: FreezmeInsets.elementSpacing,
            vertical: 18,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: textColor),
              const SizedBox(width: 12),
              Text(
                label,
                style: FreezmeTypography.button.copyWith(color: textColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
