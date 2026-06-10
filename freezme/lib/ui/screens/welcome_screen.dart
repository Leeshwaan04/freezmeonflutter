import 'package:flutter/material.dart';
import '../theme.dart';
import '../../controllers/flow_controller.dart';
import '../widgets/freezme_logo.dart';

/// 3-slide welcome carousel shown before sign-in (first launch / logged-out).
/// Sells the core value props so users understand "why" before committing an
/// Apple ID — reduces sign-in drop-off.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  static const _slides = [
    (
      icon: Icons.favorite_rounded,
      title: 'One match. Every day.',
      body:
          'A curated daily match scored on values, energy and pace — not endless swiping.',
    ),
    (
      icon: Icons.visibility_off_rounded,
      title: 'Talk before you see.',
      body:
          'Anonymous-first dating. Names and photos reveal only when you both choose to.',
    ),
    (
      icon: Icons.explore_rounded,
      title: 'Meet people nearby.',
      body:
          'See who\'s around and what they\'re up for — and connect in real life, intentionally.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isLast => _page == _slides.length - 1;

  void _next(AppFlowController flow) {
    if (_isLast) {
      flow.completeWelcome();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final flow = AppFlowScope.of(context, listen: false);
    return Scaffold(
      backgroundColor: FreezmeColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar: logo + Skip
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const FreezmeLogo(size: LogoSize.sm, showText: true),
                  TextButton(
                    onPressed: flow.completeWelcome,
                    child: const Text('Skip',
                        style: TextStyle(
                            color: FreezmeColors.muted,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) {
                  final s = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: FreezmeColors.primary.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(26),
                          ),
                          child: Icon(s.icon,
                              size: 44, color: FreezmeColors.primary),
                        ),
                        const SizedBox(height: 36),
                        Text(s.title,
                            style: const TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w800,
                                height: 1.12,
                                color: FreezmeColors.neutral)),
                        const SizedBox(height: 16),
                        Text(s.body,
                            style: const TextStyle(
                                fontSize: 17,
                                height: 1.5,
                                color: FreezmeColors.muted)),
                      ],
                    ),
                  );
                },
              ),
            ),
            // Page indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_slides.length, (i) {
                final active = i == _page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active
                        ? FreezmeColors.primary
                        : FreezmeColors.primary.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            const SizedBox(height: 28),
            // CTA
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: () => _next(flow),
                  style: FilledButton.styleFrom(
                    backgroundColor: FreezmeColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(_isLast ? 'Get Started' : 'Next',
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
