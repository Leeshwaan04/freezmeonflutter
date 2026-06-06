import 'dart:async';
import 'package:flutter/material.dart';
import '../../main.dart';
import '../../models/blinds.dart';
import '../../services/websocket_service.dart';
import '../design_system.dart';
import '../components/aurora_background.dart';
import '../components/premium_components.dart';

class BlindsPage extends StatefulWidget {
  const BlindsPage({super.key});

  @override
  State<BlindsPage> createState() => _BlindsPageState();
}

class _BlindsPageState extends State<BlindsPage> with TickerProviderStateMixin {
  late bool consented;
  bool revealAllowed = false;
  bool isSearching = false;
  String _selectedIntent = 'friends';
  String _selectedDistance = '10km';
  final List<(String, IconData)> prompts = const [
    ('What made you smile today?', Icons.sentiment_satisfied_alt),
    ('Share a small win from this week.', Icons.celebration),
    ('Describe your ideal slow Sunday.', Icons.weekend),
  ];

  late AnimationController _diceController;
  late AnimationController _cardController;
  StreamSubscription<Map<String, dynamic>>? _blindSessionSub;

  @override
  void initState() {
    super.initState();
    consented = AppFlowScope.of(context, listen: false).blindsConsent;

    // NOTE: don't auto-show the consent dialog here. Home uses an IndexedStack
    // that eagerly builds every tab, so initState runs on app launch — popping
    // the dialog over the Tonight screen before the user ever opens Blinds.
    // Consent is now requested on first dice tap (see _onDiceTap) and is also
    // settable via the Ground Rules checkbox below.

    _diceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();

    // Listen for server-matched blind sessions and open the chat automatically.
    _blindSessionSub = WebSocketService.instance.onBlindSession.listen(_onBlindSessionCreated);
  }

  @override
  void dispose() {
    _blindSessionSub?.cancel();
    _diceController.dispose();
    _cardController.dispose();
    super.dispose();
  }

  void _onBlindSessionCreated(Map<String, dynamic> data) {
    if (!mounted) return;
    try {
      // Server emits { session: { id, userA, userB, phase, expiresAt, ... } }
      // The nested object uses camelCase; normalise to snake_case for fromJson.
      final raw = (data['session'] as Map<String, dynamic>?) ?? data;
      final normalised = {
        'id':            raw['id'],
        'user_a':        raw['userA'] ?? raw['user_a'],
        'user_b':        raw['userB'] ?? raw['user_b'],
        'phase':         raw['phase'],
        'expires_at':    raw['expiresAt'] ?? raw['expires_at'],
        'reveal_a':      raw['revealA'] ?? raw['reveal_a'] ?? false,
        'reveal_b':      raw['revealB'] ?? raw['reveal_b'] ?? false,
        'reported':      raw['reported'] ?? false,
        'report_reason': raw['reportReason'] ?? raw['report_reason'],
      };
      final session = BlindSession.fromJson(normalised);
      final flow = AppFlowScope.of(context, listen: false);
      setState(() => isSearching = false);
      flow.openBlindChat(session);
    } catch (e) {
      debugPrint('[Blinds] failed to parse blind session: $e');
    }
  }

  Future<void> _showConsentDialog() async {
    final flow = AppFlowScope.of(context, listen: false);
    final agreed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Blinds Ground Rules'),
        content: const Text(
          '• Blinds are fully anonymous — no names, no photos.\n'
          '• Be kind and respectful in every chat.\n'
          '• Don\'t share personal contact details immediately.\n'
          '• Chats auto-close unless you both vibe.\n\n'
          'Do you agree to chat respectfully?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No thanks'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('I Agree'),
          ),
        ],
      ),
    );
    if (agreed == true && mounted) {
      setState(() => consented = true);
      flow.setBlindsConsent(true);
    }
  }

  Future<void> _onDiceTap(AppFlowController flow) async {
    // Request consent at the moment of engagement (not on app launch).
    if (!consented) {
      await _showConsentDialog();
      if (!consented) return; // user declined the ground rules
    }

    _diceController.forward(from: 0);
    setState(() => isSearching = true);
    
    // Simulate dice roll animation time
    await Future.delayed(const Duration(seconds: 1));
    
    try {
      if (!isSearching || !mounted) return;

      await flow.enqueueBlind(
        intent: _selectedIntent,
        distanceBucket: _selectedDistance,
        availableUntil: DateTime.now().add(const Duration(hours: 1)),
      );

      if (mounted) {
         PremiumSnackBar.show(context, 'You joined the Blind Queue! We\'ll notify you when a match is found.', type: SnackBarType.success);
         // Reset state or show in-queue UI
         setState(() {
           isSearching = false; 
         });
      }

    } catch (e) {
      if (mounted) {
        PremiumSnackBar.show(context, 'Unable to join queue at the moment. Please try again.', type: SnackBarType.error);
        setState(() => isSearching = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final flow = AppFlowScope.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AuroraBackground(
        isPremium: flow.isPremium,
        child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(FreezmeDesignSystem.spaceLg),
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Blinds', style: FreezmeDesignSystem.h1),
                    const SizedBox(height: FreezmeDesignSystem.spaceXl),
                    
                    // Hero Section: Roll the Dice
                    Center(
                      child: Column(
                        children: [
                          AnimatedBuilder(
                            animation: _diceController,
                            builder: (context, child) {
                              return Transform.rotate(
                                angle: _diceController.value * 6.28,
                                child: Transform.scale(
                                  scale: 1.0 + (0.05 * (1 - (_diceController.value - 0.5).abs() * 2)),
                                  child: child,
                                ),
                              );
                            },
                            child: GestureDetector(
                              onTap: () => _onDiceTap(flow),
                              child: Container(
                                width: MediaQuery.sizeOf(context).width * 0.37,
                                height: MediaQuery.sizeOf(context).width * 0.37,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: consented
                                      ? const LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            FreezmeDesignSystem.primary,
                                            FreezmeDesignSystem.secondary,
                                          ],
                                        )
                                      : LinearGradient(
                                          colors: [Colors.grey[300]!, Colors.grey[400]!],
                                        ),
                                  boxShadow: consented
                                      ? [
                                          BoxShadow(
                                            color: FreezmeDesignSystem.primary.withValues(alpha: 0.5),
                                            blurRadius: 30,
                                            spreadRadius: 2,
                                            offset: const Offset(0, 10),
                                          ),
                                          BoxShadow(
                                            color: FreezmeDesignSystem.secondary.withValues(alpha: 0.3),
                                            blurRadius: 40,
                                            spreadRadius: 5,
                                            offset: const Offset(0, 15),
                                          ),
                                        ]
                                      : [
                                          BoxShadow(
                                            color: Colors.grey.withValues(alpha: 0.3),
                                            blurRadius: 15,
                                            offset: const Offset(0, 8),
                                          ),
                                        ],
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Inner circle for depth
                                    Container(
                                      width: MediaQuery.sizeOf(context).width * 0.32,
                                      height: MediaQuery.sizeOf(context).width * 0.32,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: consented
                                              ? [
                                                  Colors.white.withValues(alpha: 0.2),
                                                  Colors.transparent,
                                                ]
                                              : [
                                                  Colors.white.withValues(alpha: 0.3),
                                                  Colors.transparent,
                                                ],
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      Icons.casino_rounded,
                                      size: 64,
                                      color: consented ? Colors.white : Colors.grey[600],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: FreezmeDesignSystem.spaceLg),
                          if (isSearching)
                            Column(
                              children: [
                                const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(FreezmeDesignSystem.primary),
                                  ),
                                ),
                                const SizedBox(height: FreezmeDesignSystem.spaceSm),
                                Text(
                                  'Finding someone special...',
                                  style: FreezmeDesignSystem.body.copyWith(
                                    color: FreezmeDesignSystem.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            )
                          else
                            Text(
                              consented ? 'Tap the dice to find a match!' : 'Agree to rules to play',
                              style: FreezmeDesignSystem.body.copyWith(
                                color: consented 
                                    ? FreezmeDesignSystem.textPrimary 
                                    : FreezmeDesignSystem.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: FreezmeDesignSystem.spaceXl),

                    if (flow.activeBlindSession != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: FreezmeDesignSystem.spaceXl),
                        child: PremiumActionCard(
                          title: 'Active Session',
                          subtitle: 'You have an ongoing blind chat.',
                          icon: Icons.chat_bubble_outline,
                          actionLabel: 'Rejoin',
                          onTap: () => flow.openBlindChat(flow.activeBlindSession!),
                          gradient: FreezmeGradients.premiumGloss,
                        ),
                      ),

                    const SizedBox(height: FreezmeDesignSystem.spaceXl),

                    // Ground Rules & Settings Card
                    PremiumCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: FreezmeDesignSystem.primary.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.verified_user_outlined, color: FreezmeDesignSystem.primary, size: 20),
                              ),
                              const SizedBox(width: 12),
                              const Text('Ground Rules', style: FreezmeDesignSystem.h3),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Blinds are anonymous. Be kind, don\'t share personal details immediately. Chats auto-end unless you both vibe.',
                            style: TextStyle(color: FreezmeDesignSystem.textSecondary, height: 1.4),
                          ),
                          const SizedBox(height: 16),
                          CheckboxListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                            activeColor: FreezmeDesignSystem.primary,
                            title: const Text('I agree to chat respectfully', style: TextStyle(fontWeight: FontWeight.w500)),
                            value: consented,
                            onChanged: (v) {
                               setState(() => consented = v ?? false);
                               flow.setBlindsConsent(v ?? false);
                            },
                          ),
                          const Divider(color: FreezmeDesignSystem.border),
                          SwitchListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                            activeTrackColor: FreezmeDesignSystem.primary,
                            title: const Text('Allow Reveal', style: TextStyle(fontWeight: FontWeight.w500)),
                            subtitle: const Text('Show profile after mutual thumbs up'),
                            value: revealAllowed,
                            onChanged: (v) {
                              setState(() => revealAllowed = v);
                              flow.updateBlindPreferences(allowReveal: v);
                            },
                          ),
                          const Divider(color: FreezmeDesignSystem.border),
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                            title: const Text('Intent', style: TextStyle(fontWeight: FontWeight.w500)),
                            trailing: DropdownButton<String>(
                              value: _selectedIntent,
                              underline: const SizedBox(),
                              isDense: true,
                              items: const [
                                DropdownMenuItem(value: 'friends', child: Text('Friends')),
                                DropdownMenuItem(value: 'dates', child: Text('Dates')),
                                DropdownMenuItem(value: 'either', child: Text('Either')),
                              ],
                              onChanged: (v) => setState(() => _selectedIntent = v ?? 'friends'),
                            ),
                          ),
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                            title: const Text('Distance', style: TextStyle(fontWeight: FontWeight.w500)),
                            trailing: DropdownButton<String>(
                              value: _selectedDistance,
                              underline: const SizedBox(),
                              isDense: true,
                              items: const [
                                DropdownMenuItem(value: '5km', child: Text('5 km')),
                                DropdownMenuItem(value: '10km', child: Text('10 km')),
                                DropdownMenuItem(value: '25km', child: Text('25 km')),
                                DropdownMenuItem(value: '50km', child: Text('50 km')),
                              ],
                              onChanged: (v) => setState(() => _selectedDistance = v ?? '10km'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: FreezmeDesignSystem.spaceXl),
                    
                    // Icebreakers
                    const Text('Icebreakers', style: FreezmeDesignSystem.h3),
                    const SizedBox(height: FreezmeDesignSystem.spaceMd),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: prompts.map((p) => PremiumChip(
                        label: p.$1,
                        icon: p.$2,
                        onTap: () {
                           PremiumSnackBar.show(context, 'Copied: "${p.$1}"', type: SnackBarType.success);
                        },
                      )).toList(),
                    ),
                    
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            );
          },
        ),
        ),
      ),
    );
  }
}
