import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../design_system.dart';

/// The five core features that have a "how it works" DIY journey.
enum FreezmeFeature { tonight, likes, chats, paths, blinds }

/// A single step in a feature's DIY journey.
typedef GuideStep = ({IconData icon, String text});

/// Content for one feature's guide — what it is, how to use it, and a pro tip.
class FeatureGuide {
  const FeatureGuide({
    required this.icon,
    required this.accent,
    required this.title,
    required this.tagline,
    required this.what,
    required this.steps,
    required this.tip,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String tagline;
  final String what;
  final List<GuideStep> steps;
  final String tip;
}

/// Canonical copy for every feature. Keep it warm, concrete, and honest about
/// how each feature actually behaves (expiry, location, anonymity, limits).
const Map<FreezmeFeature, FeatureGuide> kFeatureGuides = {
  FreezmeFeature.tonight: FeatureGuide(
    icon: Icons.explore_rounded,
    accent: Color(0xFF4D2C91),
    title: 'Tonight',
    tagline: 'Your daily handpicked matches',
    what:
        'Every evening we curate a small set of genuinely compatible people near you. '
        'No endless swiping — just a few quality intros, chosen for your vibe.',
    steps: [
      (icon: Icons.lock_clock_rounded, text: 'Open Tonight when the pool unlocks — the timer shows when.'),
      (icon: Icons.auto_awesome_rounded, text: 'Read each person\'s vibe and your compatibility score.'),
      (icon: Icons.favorite_rounded, text: 'Tap the heart to like, or pass to see the next.'),
      (icon: Icons.chat_bubble_rounded, text: 'If you both like each other, it\'s a match — a chat opens.'),
    ],
    tip: 'The pool refreshes once a day. Check back each evening so you don\'t miss anyone.',
  ),
  FreezmeFeature.likes: FeatureGuide(
    icon: Icons.favorite_rounded,
    accent: Color(0xFFDB2777),
    title: 'Likes',
    tagline: 'See who\'s already into you',
    what:
        'People who liked you show up here. Like them back and you match instantly — '
        'no waiting for the daily pool.',
    steps: [
      (icon: Icons.visibility_rounded, text: 'Browse the people who liked your profile.'),
      (icon: Icons.person_rounded, text: 'Tap anyone to view their full profile.'),
      (icon: Icons.favorite_rounded, text: 'Like back to match and start chatting right away.'),
    ],
    tip: 'Freezme+ reveals everyone who liked you at a glance.',
  ),
  FreezmeFeature.chats: FeatureGuide(
    icon: Icons.chat_bubble_rounded,
    accent: Color(0xFF7C3AED),
    title: 'Chats',
    tagline: 'Where connections grow',
    what:
        'All your matches and conversations live here. New matches "melt" (expire) if no one '
        'says hello — so make the first move while the spark is fresh.',
    steps: [
      (icon: Icons.touch_app_rounded, text: 'Tap a match to open the conversation.'),
      (icon: Icons.send_rounded, text: 'Send the first message before the match melts.'),
      (icon: Icons.timer_rounded, text: 'The colored timer shows how long a new match has left.'),
      (icon: Icons.ac_unit_rounded, text: 'Frozen Connections are secret admirers — accept to reveal them.'),
    ],
    tip: 'Once you both start talking, the match stops melting and stays for good.',
  ),
  FreezmeFeature.paths: FeatureGuide(
    icon: Icons.route_rounded,
    accent: Color(0xFF2563EB),
    title: 'Paths',
    tagline: 'Cross paths with people nearby, right now',
    what:
        'Go live to discover people near you who are up for the same thing — coffee, gym, a walk. '
        'Your location is only shared while you\'re visible, and it auto-expires.',
    steps: [
      (icon: Icons.local_activity_rounded, text: 'Pick what you\'re up for (coffee, hiking, food…).'),
      (icon: Icons.location_on_rounded, text: 'Toggle "Show me on Paths" to go live.'),
      (icon: Icons.waving_hand_rounded, text: 'Wave or invite someone nearby who matches your vibe.'),
      (icon: Icons.chat_bubble_rounded, text: 'When they accept, a chat opens so you can plan to meet.'),
    ],
    tip: 'You get 5 waves a day, and your presence disappears automatically after an hour.',
  ),
  FreezmeFeature.blinds: FeatureGuide(
    icon: Icons.bolt_rounded,
    accent: Color(0xFF059669),
    title: 'Blinds',
    tagline: 'Feel the vibe before the face',
    what:
        'Get matched anonymously — no names, no photos. You chat first and only reveal '
        'yourselves if you both choose to. Connection over first impressions.',
    steps: [
      (icon: Icons.verified_user_rounded, text: 'Agree to the ground rules — kindness first.'),
      (icon: Icons.tune_rounded, text: 'Choose your intent and distance.'),
      (icon: Icons.casino_rounded, text: 'Tap the dice to enter the queue.'),
      (icon: Icons.chat_bubble_outline_rounded, text: 'We match you and open an anonymous chat.'),
      (icon: Icons.visibility_rounded, text: 'Both tap "reveal" to finally see each other.'),
    ],
    tip: 'Anonymity isn\'t an excuse to be unkind. Chats auto-close unless you both vibe.',
  ),
};

/// Tracks which feature guides a user has already seen (so first-run auto-show
/// happens exactly once), and shows the guide sheet.
class FeatureGuideService {
  static String _key(FreezmeFeature f) => 'feature_guide_seen_${f.name}';

  static Future<bool> hasSeen(FreezmeFeature f) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_key(f)) ?? false;
    } catch (_) {
      return true; // fail safe: don't nag if prefs unavailable
    }
  }

  static Future<void> markSeen(FreezmeFeature f) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key(f), true);
    } catch (_) {/* best-effort */}
  }

  /// Show the guide if it hasn't been seen yet. Returns true if it was shown.
  static Future<bool> maybeAutoShow(BuildContext context, FreezmeFeature f) async {
    if (await hasSeen(f)) return false;
    await markSeen(f);
    if (!context.mounted) return false;
    await showFeatureGuide(context, f);
    return true;
  }
}

/// Opens the DIY journey sheet for [feature]. Always shows (used for re-open
/// from a help menu). Use [FeatureGuideService.maybeAutoShow] for first-run.
Future<void> showFeatureGuide(BuildContext context, FreezmeFeature feature) {
  final guide = kFeatureGuides[feature]!;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    builder: (_) => _FeatureGuideSheet(guide: guide),
  );
}

/// A menu of every feature's DIY guide. Wired from Profile → "How Freezme Works"
/// so users can revisit any explanation at any time.
Future<void> showFeatureGuideHub(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    builder: (_) => const _FeatureGuideHubSheet(),
  );
}

class _FeatureGuideHubSheet extends StatelessWidget {
  const _FeatureGuideHubSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
      decoration: const BoxDecoration(
        color: FreezmeDesignSystem.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: FreezmeDesignSystem.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              FreezmeDesignSystem.spaceLg, FreezmeDesignSystem.spaceSm,
              FreezmeDesignSystem.spaceLg, FreezmeDesignSystem.spaceSm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('How Freezme Works', style: FreezmeDesignSystem.h2.copyWith(fontSize: 22)),
                const SizedBox(height: 4),
                Text(
                  'Tap any feature for a quick walkthrough.',
                  style: FreezmeDesignSystem.caption,
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(
                FreezmeDesignSystem.spaceMd, 0,
                FreezmeDesignSystem.spaceMd, FreezmeDesignSystem.spaceLg,
              ),
              children: FreezmeFeature.values.map((f) {
                final g = kFeatureGuides[f]!;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(FreezmeDesignSystem.radiusMd),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(FreezmeDesignSystem.radiusMd),
                      onTap: () {
                        Navigator.of(context).maybePop();
                        showFeatureGuide(context, f);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(FreezmeDesignSystem.spaceMd),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(FreezmeDesignSystem.radiusMd),
                          border: Border.all(color: FreezmeDesignSystem.border.withValues(alpha: 0.6)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: g.accent.withValues(alpha: 0.12),
                              ),
                              child: Icon(g.icon, color: g.accent, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(g.title, style: FreezmeDesignSystem.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 2),
                                  Text(g.tagline, style: FreezmeDesignSystem.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, color: FreezmeDesignSystem.textTertiary),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureGuideSheet extends StatelessWidget {
  const _FeatureGuideSheet({required this.guide});
  final FeatureGuide guide;

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.85;
    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: const BoxDecoration(
        color: FreezmeDesignSystem.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Grabber
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: FreezmeDesignSystem.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                FreezmeDesignSystem.spaceLg, FreezmeDesignSystem.spaceSm,
                FreezmeDesignSystem.spaceLg, FreezmeDesignSystem.spaceLg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: icon orb + title + tagline
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [guide.accent, guide.accent.withValues(alpha: 0.65)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: guide.accent.withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Icon(guide.icon, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(guide.title, style: FreezmeDesignSystem.h2.copyWith(fontSize: 22)),
                            const SizedBox(height: 2),
                            Text(
                              guide.tagline,
                              style: FreezmeDesignSystem.caption.copyWith(
                                color: guide.accent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: FreezmeDesignSystem.spaceLg),

                  // What it is
                  Container(
                    padding: const EdgeInsets.all(FreezmeDesignSystem.spaceMd),
                    decoration: BoxDecoration(
                      color: guide.accent.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(FreezmeDesignSystem.radiusMd),
                      border: Border.all(color: guide.accent.withValues(alpha: 0.15)),
                    ),
                    child: Text(
                      guide.what,
                      style: FreezmeDesignSystem.body.copyWith(height: 1.5),
                    ),
                  ),
                  const SizedBox(height: FreezmeDesignSystem.spaceLg),

                  // How it works
                  Text('How it works', style: FreezmeDesignSystem.h3),
                  const SizedBox(height: FreezmeDesignSystem.spaceMd),
                  ...List.generate(guide.steps.length, (i) {
                    final step = guide.steps[i];
                    final isLast = i == guide.steps.length - 1;
                    return _StepRow(
                      index: i + 1,
                      icon: step.icon,
                      text: step.text,
                      accent: guide.accent,
                      isLast: isLast,
                    );
                  }),
                  const SizedBox(height: FreezmeDesignSystem.spaceSm),

                  // Pro tip
                  Container(
                    padding: const EdgeInsets.all(FreezmeDesignSystem.spaceMd),
                    decoration: BoxDecoration(
                      color: FreezmeDesignSystem.surfaceAlt,
                      borderRadius: BorderRadius.circular(FreezmeDesignSystem.radiusMd),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.lightbulb_rounded, color: Color(0xFFF59E0B), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                const TextSpan(
                                  text: 'Pro tip  ',
                                  style: TextStyle(fontWeight: FontWeight.w800, color: FreezmeDesignSystem.textPrimary),
                                ),
                                TextSpan(
                                  text: guide.tip,
                                  style: FreezmeDesignSystem.caption.copyWith(height: 1.45),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: FreezmeDesignSystem.spaceLg),

                  // CTA
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: guide.accent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(FreezmeDesignSystem.radiusLg),
                        ),
                      ),
                      child: const Text(
                        'Got it',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.index,
    required this.icon,
    required this.text,
    required this.accent,
    required this.isLast,
  });

  final int index;
  final IconData icon;
  final String text;
  final Color accent;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Numbered node + connector line
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.12),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$index',
                  style: TextStyle(color: accent, fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: accent.withValues(alpha: 0.15),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 4, bottom: isLast ? 0 : FreezmeDesignSystem.spaceMd),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 18, color: accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      text,
                      style: FreezmeDesignSystem.body.copyWith(height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
