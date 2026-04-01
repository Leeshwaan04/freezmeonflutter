import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../main.dart';
import '../../models/paths.dart';
import '../design_system.dart';
import '../components/aurora_background.dart';
import '../components/premium_components.dart';
import '../shared/bottom_nav_bar.dart';

class PathsPage extends StatefulWidget {
  const PathsPage({super.key});

  @override
  State<PathsPage> createState() => _PathsPageState();
}

class _PathsPageState extends State<PathsPage> with SingleTickerProviderStateMixin {
  bool visible = true;
  double radius = 10;
  final Set<String> intents = {'Friends', 'Dates'};
  bool todayOnly = true;
  int wavesLeft = 5;
  bool notifyWhenNearby = true;
  final Map<String, String> inviteStatusByUser = {};
  final Map<String, StreamSubscription<PathsInvite>> _inviteSubs = {};
  late final AnimationController _radarController;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final flow = AppFlowScope.of(context, listen: false);
      _refresh(flow);
    });
  }

  @override
  void dispose() {
    _radarController.dispose();
    for (final sub in _inviteSubs.values) {
      sub.cancel();
    }
    _inviteSubs.clear();
    super.dispose();
  }

  void _openChat(AppFlowController flow) {
    final targetProfile = flow.activeProfile ??
        (flow.matches.isNotEmpty
            ? flow.matches.first.profile
            : flow.dailyProfiles.isNotEmpty
                ? flow.dailyProfiles.first
                : null);
    if (targetProfile != null) {
      flow.openChatDetail(targetProfile);
    } else {
      PremiumSnackBar.show(context, 'No one nearby right now. Try again soon.');
    }
  }

  void _useWave(BuildContext context) {
    if (wavesLeft <= 0) {
      PremiumSnackBar.show(context, 'Daily waves used up. Check back tomorrow.');
      return;
    }
    setState(() => wavesLeft -= 1);
    PremiumSnackBar.show(context, 'Wave sent. $wavesLeft left today.', type: SnackBarType.success);
  }

  Future<void> _refresh(AppFlowController flow) async {
    await flow.refreshPaths(radiusKm: radius, intents: intents);
    if (mounted) setState(() {});
  }

  Future<void> _sendInvite(
    AppFlowController flow,
    PathsPresence person,
  ) async {
    final current = inviteStatusByUser[person.uid];
    if (current == 'pending') return;
    if (wavesLeft <= 0) {
      PremiumSnackBar.show(context, 'Out of invites for today.');
      return;
    }
    setState(() {
      inviteStatusByUser[person.uid] = 'pending';
      wavesLeft = (wavesLeft - 1).clamp(0, 99);
    });
    try {
      final inviteId = await flow.sendPathsInvite(
          receiverUid: person.uid,
        intent: person.intents.isNotEmpty ? person.intents.first : 'Either',
      );
      if (inviteId.isEmpty) {
        throw Exception('Failed to send invite');
      }
      _inviteSubs[person.uid]?.cancel();
      _inviteSubs[person.uid] = flow.inviteStatus(inviteId).listen((invite) {
        if (!mounted) return;
        setState(() {
          inviteStatusByUser[person.uid] = invite.status;
        });
        if (invite.status == 'accepted' && mounted) {
          _openChat(flow);
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        inviteStatusByUser[person.uid] = 'error';
      });
      PremiumSnackBar.show(context, 'Could not send invite. Please retry.', type: SnackBarType.error);
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
          child: RefreshIndicator(
          color: FreezmeDesignSystem.primary,
          backgroundColor: FreezmeDesignSystem.surface,
          onRefresh: () async => _refresh(flow),
          child: CustomScrollView(
            key: const PageStorageKey('pathsScroll'),
            slivers: [
              // 1. Header & Controls
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header row
                      Row(
                        children: [
                          const Text('Paths', style: FreezmeDesignSystem.display),
                          const Spacer(),
                          // Waves pill
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('👋', style: TextStyle(fontSize: 13)),
                                const SizedBox(width: 4),
                                Text(
                                  '$wavesLeft left',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: FreezmeDesignSystem.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _StatusBadge(visible: visible),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Frosted visibility toggle card
                      _FrostedCard(
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: visible
                                    ? const LinearGradient(
                                        colors: [FreezmeDesignSystem.primary, Color(0xFF7C3AED)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                    : null,
                                color: visible ? null : FreezmeDesignSystem.surfaceAlt,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                visible ? Icons.location_on_rounded : Icons.location_off_rounded,
                                color: visible ? Colors.white : FreezmeDesignSystem.textTertiary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Show me on Paths',
                                    style: FreezmeDesignSystem.h3.copyWith(fontSize: 16),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    visible
                                        ? 'Visible within ${radius.round()} km'
                                        : 'Turn on to discover people nearby',
                                    style: FreezmeDesignSystem.caption.copyWith(
                                      color: visible
                                          ? FreezmeDesignSystem.success
                                          : FreezmeDesignSystem.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: visible,
                              activeThumbColor: Colors.white,
                              activeTrackColor: FreezmeDesignSystem.primary,
                              inactiveThumbColor: Colors.white,
                              inactiveTrackColor: FreezmeDesignSystem.border,
                              onChanged: (v) {
                                HapticFeedback.mediumImpact();
                                setState(() => visible = v);
                                if (v) _refresh(flow);
                              },
                            ),
                          ],
                        ),
                      ),

                      if (visible) ...[
                        const SizedBox(height: 12),

                        // Distance card
                        _FrostedCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.straighten_rounded, size: 16, color: FreezmeDesignSystem.primary),
                                  const SizedBox(width: 6),
                                  const Text('Distance', style: FreezmeDesignSystem.captionMedium),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: FreezmeDesignSystem.primary,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${radius.round()} km',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              // Quick select pills
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [1.0, 5.0, 10.0, 25.0, 50.0].map((km) {
                                  final active = radius.round() == km.round();
                                  return GestureDetector(
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      setState(() => radius = km);
                                      _refresh(flow);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: active
                                            ? FreezmeDesignSystem.primary
                                            : Colors.white.withValues(alpha: 0.5),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: active
                                              ? FreezmeDesignSystem.primary
                                              : FreezmeDesignSystem.border,
                                        ),
                                      ),
                                      child: Text(
                                        '${km.round()}km',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: active ? Colors.white : FreezmeDesignSystem.textSecondary,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 4,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                                  activeTrackColor: FreezmeDesignSystem.primary,
                                  inactiveTrackColor: FreezmeDesignSystem.primary.withValues(alpha: 0.15),
                                  thumbColor: FreezmeDesignSystem.primary,
                                  overlayColor: FreezmeDesignSystem.primary.withValues(alpha: 0.1),
                                ),
                                child: Slider(
                                  value: radius,
                                  min: 1,
                                  max: 50,
                                  divisions: 49,
                                  onChanged: (v) => setState(() => radius = v),
                                  onChangeEnd: (_) => _refresh(flow),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Tonight's Vibe card
                        _FrostedCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.bolt_rounded, size: 16, color: FreezmeDesignSystem.primary),
                                  const SizedBox(width: 6),
                                  const Text("Tonight's Vibe", style: FreezmeDesignSystem.captionMedium),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Segmented pill toggle
                              Container(
                                decoration: BoxDecoration(
                                  color: FreezmeDesignSystem.surfaceAlt,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                padding: const EdgeInsets.all(4),
                                child: Row(
                                  children: [
                                    ('Connect', 'Friends'),
                                    ('Spark', 'Dates'),
                                    ('Open', 'Either'),
                                  ].map(((String, String) item) {
                                    final displayLabel = item.$1;
                                    final intentKey = item.$2;
                                    final isSelected = intents.contains(intentKey);
                                    return Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          HapticFeedback.selectionClick();
                                          setState(() {
                                            isSelected ? intents.remove(intentKey) : intents.add(intentKey);
                                          });
                                          _refresh(flow);
                                        },
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 180),
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          decoration: BoxDecoration(
                                            gradient: isSelected
                                                ? const LinearGradient(
                                                    colors: [FreezmeDesignSystem.primary, Color(0xFF7C3AED)],
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                  )
                                                : null,
                                            borderRadius: BorderRadius.circular(10),
                                            boxShadow: isSelected
                                                ? [
                                                    BoxShadow(
                                                      color: FreezmeDesignSystem.primary.withValues(alpha: 0.25),
                                                      blurRadius: 8,
                                                      offset: const Offset(0, 2),
                                                    ),
                                                  ]
                                                : null,
                                          ),
                                          child: Text(
                                            displayLabel,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: isSelected
                                                  ? Colors.white
                                                  : FreezmeDesignSystem.textSecondary,
                                              letterSpacing: 0.2,
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
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // 2. Section Title
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'Nearby',
                    style: FreezmeDesignSystem.h2.copyWith(fontSize: 22),
                  ),
                ),
              ),

              // 3. Content List
              if (!visible)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: EmptyStateView(
                      icon: Icons.visibility_off_outlined,
                      title: 'You are hidden',
                      subtitle: 'Turn on visibility above to see who is crossing your path.',
                    ),
                  ),
                )
              else if (flow.pathsLoading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: FreezmeDesignSystem.primary)),
                )
              else if (flow.pathsError != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: ErrorStateView(
                    message: flow.pathsError!,
                    onRetry: () => _refresh(flow),
                  ),
                )
              else if (flow.nearbyPaths.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            ScaleTransition(
                              scale: Tween(begin: 0.8, end: 1.2).animate(
                                CurvedAnimation(parent: _radarController, curve: Curves.easeInOut),
                              ),
                              child: Container(
                                width: 100, height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: FreezmeDesignSystem.primary.withValues(alpha: 0.1),
                                ),
                              ),
                            ),
                            RotationTransition(
                              turns: _radarController,
                              child: const Icon(
                                Icons.radar_rounded, 
                                size: 64, 
                                color: FreezmeDesignSystem.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const Text('Scanning area...', style: FreezmeDesignSystem.h3),
                        const SizedBox(height: 8),
                        const Text(
                          'No one matching your filters is nearby right now.\nTry increasing your distance!',
                          textAlign: TextAlign.center,
                          style: FreezmeDesignSystem.body,
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final person = flow.nearbyPaths[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _NearbyPersonCard(
                            person: person,
                            onWave: () {
                              _useWave(context);
                              _openChat(flow); // Simulated success
                            },
                            onInvite: () {
                              // Logic for Invite
                                final status = inviteStatusByUser[person.uid];
                              if (status == 'accepted') {
                                _openChat(flow);
                              } else {
                                _sendInvite(flow, person);
                              }
                            },
                              inviteStatus: inviteStatusByUser[person.uid],
                          ),
                        );
                      },
                      childCount: flow.nearbyPaths.length,
                    ),
                  ),
                ),
                
              // Bottom padding for nav bar
              const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

class _FrostedCard extends StatelessWidget {
  final Widget child;
  const _FrostedCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: FreezmeDesignSystem.primary.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool visible;
  const _StatusBadge({required this.visible});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: visible ? FreezmeDesignSystem.success.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: visible ? FreezmeDesignSystem.success.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: visible ? FreezmeDesignSystem.success : Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            visible ? 'Active' : 'Hidden',
            style: TextStyle(
              color: visible ? FreezmeDesignSystem.success : Colors.grey,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _NearbyPersonCard extends StatelessWidget {
  final PathsPresence person;
  final VoidCallback onWave;
  final VoidCallback onInvite;
  final String? inviteStatus;

  const _NearbyPersonCard({
    required this.person,
    required this.onWave,
    required this.onInvite,
    this.inviteStatus,
  });

  @override
  Widget build(BuildContext context) {
    return _FrostedCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [FreezmeDesignSystem.primary, Color(0xFF7C3AED)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 16),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(person.uid, style: FreezmeDesignSystem.h3.copyWith(fontSize: 18)), // Assuming userId is name for mock
                    if (person.lastActiveAt != null)
                      Text(
                        _timeAgo(person.lastActiveAt!),
                        style: const TextStyle(fontSize: 12, color: FreezmeDesignSystem.textSecondary),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                if (person.availability != null)
                  Text(person.availability!, style: FreezmeDesignSystem.bodyMedium),
                const SizedBox(height: 8),
                // Tags
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: person.intents.map((intent) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: FreezmeDesignSystem.surfaceAlt,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      intent,
                      style: const TextStyle(fontSize: 12, color: FreezmeDesignSystem.primary, fontWeight: FontWeight.w500),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 12),
                // Actions
                Row(
                  children: [
                    Expanded(
                      child: PremiumButton(
                        label: 'Wave 👋',
                        onPressed: onWave,
                        variant: ButtonVariant.outlined,
                        size: ButtonSize.small,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                       child: PremiumButton(
                        label: _inviteLabel(inviteStatus),
                        onPressed: onInvite,
                        variant: ButtonVariant.filled,
                        size: ButtonSize.small,
                        backgroundColor: _buttonColor(inviteStatus),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _buttonColor(String? status) {
    switch (status) {
      case 'sent': return Colors.grey;
      case 'accepted': return FreezmeDesignSystem.success;
      case 'rejected': return FreezmeDesignSystem.error;
      default: return FreezmeDesignSystem.primary;
    }
  }

  String _inviteLabel(String? status) {
    switch (status) {
      case 'sent': return 'Sent';
      case 'accepted': return 'Chat';
      case 'rejected': return 'Passed';
      default: return 'Invite';
    }
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
