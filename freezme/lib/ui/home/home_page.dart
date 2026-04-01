import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'dart:async'; // Added
import '../../main.dart';
import '../../models/vibe_profile.dart' as models;
import '../../services/location_service.dart';
import '../../models/paths.dart';
import '../design_system.dart';
import '../components/premium_components.dart';
import '../components/skeleton_loaders.dart';
import '../shared/bottom_nav_bar.dart';
import '../profile/profile_detail_page.dart';
import '../profile/profile_settings_page.dart';
import '../chat/chat_list_page.dart';
import '../paths/paths_page.dart';
import '../blinds/blinds_page.dart';
import '../components/aurora_background.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isLoading = true;
  bool _hasError = false;
  List<models.VibeProfile> _tonightPool = [];
  Timer? _timer;
  String _countdown = '00:00:00';
  String _locationName = 'Your Area';

  @override
  void initState() {
    super.initState();
    _startTimer();
    _loadData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _updateCountdown();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateCountdown());
  }

  void _updateCountdown() {
    final now = DateTime.now();
    // Target: Today 6 PM or Tomorrow 6 PM
    var target = DateTime(now.year, now.month, now.day, 18, 0, 0);
    if (now.isAfter(target)) {
      target = target.add(const Duration(days: 1));
    }
    
    final diff = target.difference(now);
    final hours = diff.inHours.toString().padLeft(2, '0');
    final minutes = (diff.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (diff.inSeconds % 60).toString().padLeft(2, '0');

    if (mounted) {
      setState(() {
        _countdown = '$hours:$minutes:$seconds';
      });
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final flow = AppFlowScope.of(context, listen: false);

      // Get user location
      final locationService = LocationService();
      final locationResult = await locationService.getCoarseLocation();

      // Get device timezone
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      final timezone = timezoneInfo.identifier;

      // Fetch Tonight Pool with location and timezone
      List<models.VibeProfile> profiles;
      if (locationResult.denied || locationResult.lat == null || locationResult.lng == null) {
        // Location denied or unavailable, fallback to basic fetch
        profiles = await flow.repository.fetchDailyProfiles();
      } else {
        // Use enhanced Tonight Pool with geo + timezone
        profiles = await flow.repository.fetchTonightPool(
          lat: locationResult.lat!,
          lng: locationResult.lng!,
          timezone: timezone,
        );
      }

      if (mounted) {
        setState(() {
          _tonightPool = profiles;
          _isLoading = false;
          _hasError = false;
          if (locationResult.cityName != null) {
            _locationName = locationResult.cityName!;
          }
        });

        // Trigger paths refresh in background
        // Trigger paths refresh in background
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            unawaited(flow.refreshPaths(
              radiusKm: flow.lastPathsRadiusKm,
              intents: flow.lastPathsIntents,
            ));
          }
        });
      }
    } catch (e) {
      // Error loading data, use fallback
      if (mounted) {
        try {
          final flow = AppFlowScope.of(context, listen: false);
          final profiles = await flow.repository.fetchDailyProfiles();
          setState(() {
            _tonightPool = profiles;
            _isLoading = false;
            _hasError = true; // show error but keep fallback data
          });
        } catch (_) {
          setState(() {
            _tonightPool = [];
            _isLoading = false;
            _hasError = true;
          });
        }
      }
    }
  }

  Future<void> _manualLocationSearch() async {
    final city = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter City'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Mumbai, Berlin'),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ],
      ),
    );
    if (city != null && city.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        _locationName = city;
        _isLoading = true;
      });
      // Simulate fetching for city
      await Future.delayed(const Duration(seconds: 1));
      _loadData(); // Re-trigger with fake city name logic
    }
  }

  @override
  Widget build(BuildContext context) {
    final flow = AppFlowScope.of(context);

    return Scaffold(
      backgroundColor: FreezmeDesignSystem.background,
      bottomNavigationBar: SafeArea(
        top: false,
        child: FreezmeBottomNavBar(
          currentIndex: flow.currentTabIndex,
          onTap: flow.openTab,
        ),
      ),
      body: IndexedStack(
        index: flow.currentTabIndex,
        children: [
          _buildFeedTab(flow),
          const ChatListPage(),
          const PathsPage(),
          const BlindsPage(),
          const ProfileSettingsPage(),
        ],
      ),
    );
  }

  Widget _buildFeedTab(AppFlowController flow) {
    return AuroraBackground(
      isPremium: flow.isPremium,
      child: SafeArea(
        child: RefreshIndicator(
          color: FreezmeDesignSystem.primary,
          backgroundColor: FreezmeDesignSystem.surface,
          onRefresh: _loadData,
          child: CustomScrollView(
            // Key removed to prevent Duplicate GlobalKey collision during transitions
            slivers: [
              _buildHeader(),
              // Profile completion prompt moved to Profile page - no longer a blocker here
              if (_isLoading) ...[
                 _buildLivePathsSkeleton(key: const ValueKey('live_paths_skeleton')),
                 _buildTonightPoolSkeleton(key: const ValueKey('tonight_pool_skeleton')),
              ] else if (_hasError && _tonightPool.isEmpty) ...[
                SliverFillRemaining(
                  key: const ValueKey('error_retry_fill'),
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.location_off_outlined, size: 64, color: FreezmeDesignSystem.textTertiary),
                        const SizedBox(height: 24),
                        const Text(
                          'Location Access Required',
                          style: FreezmeDesignSystem.h2,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'To find vibes near you, we need your location. You can also search manually.',
                          style: FreezmeDesignSystem.body.copyWith(color: FreezmeDesignSystem.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        PremiumButton(
                          label: 'Search Manually',
                          onPressed: _manualLocationSearch,
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _loadData,
                          child: const Text('Retry GPS'),
                        ),
                      ],
                    ),
                  ),
                )
              ] else ...[
                _buildLivePathsSection(key: const ValueKey('live_paths_section')),
                _buildTonightPoolSection(key: const ValueKey('tonight_pool_section')),
                _buildTrendingFeedSection(key: const ValueKey('trending_feed_section')),
              ],
              const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(FreezmeDesignSystem.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TONIGHT IN',
                        style: FreezmeDesignSystem.caption.copyWith(
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w800,
                          color: FreezmeDesignSystem.textSecondary,
                        ),
                      ),
                      Text(
                        _locationName,
                        style: FreezmeDesignSystem.display,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: FreezmeDesignSystem.surface,
                    borderRadius: BorderRadius.circular(FreezmeDesignSystem.radiusFull),
                    border: Border.all(color: FreezmeDesignSystem.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer_outlined, size: 14, color: FreezmeDesignSystem.primary),
                      const SizedBox(width: 4),
                      Text(
                        _countdown,
                        style: FreezmeDesignSystem.small.copyWith(
                          color: FreezmeDesignSystem.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Builder(builder: (ctx) {
                  final f = AppFlowScope.of(ctx, listen: false);
                  return GestureDetector(
                    onTap: () => f.openTab(4),
                    child: UserAvatar(
                      imageUrl: f.profilePhotoUrl,
                      size: 36,
                      isPremium: f.isPremium,
                    ),
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLivePathsSection({Key? key}) {
    final flow = AppFlowScope.of(context);
    final paths = flow.nearbyPaths;

    if (paths.isEmpty && !flow.pathsLoading) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      key: key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: FreezmeDesignSystem.spaceLg),
            child: Row(
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(color: FreezmeDesignSystem.success, shape: BoxShape.circle),
                ),
                const SizedBox(width: FreezmeDesignSystem.spaceSm),
                Text(
                  'LIVE NOW',
                  style: FreezmeDesignSystem.h3.copyWith(fontSize: 18),
                ),
              ],
            ),
          ),
          const SizedBox(height: FreezmeDesignSystem.spaceMd),
          SizedBox(
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: FreezmeDesignSystem.spaceLg),
              itemCount: flow.pathsLoading ? 3 : paths.length,
              itemBuilder: (context, index) {
                if (flow.pathsLoading) return const LiveCardSkeleton();
                return _LivePathCard(presence: paths[index]);
              },
            ),
          ),
          const SizedBox(height: FreezmeDesignSystem.spaceXl),
        ],
      ),
    );
  }
  
  Widget _buildLivePathsSkeleton({Key? key}) {
    return SliverToBoxAdapter(
      key: key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: FreezmeDesignSystem.spaceLg),
            child: SkeletonLoader(width: 100, height: 20),
          ),
          const SizedBox(height: FreezmeDesignSystem.spaceMd),
          SizedBox(
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: FreezmeDesignSystem.spaceLg),
              itemCount: 3, 
              itemBuilder: (context, index) {
                return const LiveCardSkeleton();
              },
            ),
          ),
          const SizedBox(height: FreezmeDesignSystem.spaceXl),
        ],
      ),
    );
  }
  
  Widget _buildTonightPoolSkeleton({Key? key}) {
    return SliverList(
      key: key,
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index == 0) {
            return const Padding(
              padding: EdgeInsets.symmetric(horizontal: FreezmeDesignSystem.spaceLg, vertical: FreezmeDesignSystem.spaceSm),
              child: SkeletonLoader(width: 150, height: 24),
            );
          }
          return const Padding(
             padding: EdgeInsets.symmetric(vertical: FreezmeDesignSystem.spaceSm),
             child: ProfileCardSkeleton(),
          );
        },
        childCount: 4,
      ),
    );
  }

  Widget _buildTonightPoolSection({Key? key}) {
    if (_tonightPool.isEmpty) {
      return SliverToBoxAdapter(
        key: const ValueKey('empty_pool_state'),
        child: Padding(
          padding: const EdgeInsets.all(FreezmeDesignSystem.spaceLg),
          child: const EmptyStateView(
            icon: Icons.nightlife,
            title: "No vibes tonight yet",
            subtitle: "Check back closer to 6 PM or adjust your radius to find people nearby.",
          ),
        ),
      );
    }

    return SliverToBoxAdapter(
      key: key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              FreezmeDesignSystem.spaceLg,
              FreezmeDesignSystem.spaceSm,
              FreezmeDesignSystem.spaceLg,
              FreezmeDesignSystem.spaceSm,
            ),
            child: Text(
              "TONIGHT'S POOL",
              style: FreezmeDesignSystem.h3.copyWith(fontSize: 18),
            ),
          ),
          SizedBox(
            height: 300,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: FreezmeDesignSystem.spaceLg,
              ),
              itemCount: _tonightPool.length,
              separatorBuilder: (context, i) => const SizedBox(width: 12),
              itemBuilder: (context, index) =>
                  _TonightProfileCard(profile: _tonightPool[index]),
            ),
          ),
          const SizedBox(height: FreezmeDesignSystem.spaceMd),
        ],
      ),
    );
  }

  Widget _buildTrendingFeedSection({Key? key}) {
    final cards = _PulseCardData.generate(_locationName, _countdown);
    return SliverToBoxAdapter(
      key: key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: FreezmeDesignSystem.spaceXl),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: FreezmeDesignSystem.spaceLg),
            child: Row(
              children: [
                Text(
                  "TONIGHT'S PULSE",
                  style: FreezmeDesignSystem.h3.copyWith(fontSize: 18),
                ),
                const SizedBox(width: 8),
                _LiveDot(),
              ],
            ),
          ),
          const SizedBox(height: FreezmeDesignSystem.spaceMd),
          SizedBox(
            height: 176,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                  horizontal: FreezmeDesignSystem.spaceLg),
              itemCount: cards.length,
              separatorBuilder: (context, i) => const SizedBox(width: 12),
              itemBuilder: (context, i) => _PulseCard(data: cards[i]),
            ),
          ),
          const SizedBox(height: FreezmeDesignSystem.spaceMd),
        ],
      ),
    );
  }
}

// ─── Live pulsing dot ────────────────────────────────────────────────────────
class _LiveDot extends StatefulWidget {
  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF4CAF50).withValues(alpha: _anim.value),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4CAF50).withValues(alpha: _anim.value * 0.6),
              blurRadius: 6,
              spreadRadius: 2,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Card data model ─────────────────────────────────────────────────────────
enum _PulseCardType { heat, mystery, poll, icebreaker, spark, clock }

class _PulseCardData {
  const _PulseCardData({
    required this.type,
    required this.icon,
    required this.headline,
    required this.sub,
    required this.isLive,
    this.compatScore,
    this.pollOptions,
  });

  final _PulseCardType type;
  final IconData icon;
  final String headline;
  final String sub;
  final bool isLive;
  final int? compatScore;
  final List<String>? pollOptions;

  static List<_PulseCardData> generate(String area, String countdown) {
    final shortArea = area.split(' ').take(2).join(' ');
    return [
      _PulseCardData(
        type: _PulseCardType.heat,
        icon: Icons.local_fire_department_rounded,
        headline: 'Active near you',
        sub: '12 people in your area are in tonight\'s pool right now',
        isLive: true,
      ),
      _PulseCardData(
        type: _PulseCardType.mystery,
        icon: Icons.auto_awesome_rounded,
        headline: 'High match nearby',
        sub: 'Someone in $shortArea has an unusually high vibe score with you',
        isLive: true,
        compatScore: 94,
      ),
      _PulseCardData(
        type: _PulseCardType.spark,
        icon: Icons.favorite_rounded,
        headline: '3 connections',
        sub: 'happened near $shortArea in the last hour',
        isLive: true,
      ),
      _PulseCardData(
        type: _PulseCardType.clock,
        icon: Icons.timer_outlined,
        headline: 'Pool closes in',
        sub: 'Don\'t miss tonight\'s matches — $countdown left',
        isLive: false,
      ),
      _PulseCardData(
        type: _PulseCardType.poll,
        icon: Icons.how_to_vote_rounded,
        headline: 'Quick take',
        sub: 'Spontaneous plans > scheduled dates',
        isLive: false,
        pollOptions: ['Agree', 'Disagree'],
      ),
      _PulseCardData(
        type: _PulseCardType.icebreaker,
        icon: Icons.chat_bubble_outline_rounded,
        headline: 'Tonight\'s opener',
        sub: 'What\'s the most spontaneous thing you\'ve ever done?',
        isLive: false,
      ),
    ];
  }
}

// ─── Pulse card widget ───────────────────────────────────────────────────────
class _PulseCard extends StatefulWidget {
  const _PulseCard({required this.data});
  final _PulseCardData data;

  @override
  State<_PulseCard> createState() => _PulseCardState();
}

class _PulseCardState extends State<_PulseCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;
  int? _pollVote;

  // Per-type gradient palettes
  static const _gradients = <_PulseCardType, List<Color>>{
    _PulseCardType.heat: [Color(0xFF6B21A8), Color(0xFF9333EA)],
    _PulseCardType.mystery: [Color(0xFF1E1B4B), Color(0xFF4C1D95)],
    _PulseCardType.spark: [Color(0xFFBE185D), Color(0xFFEC4899)],
    _PulseCardType.clock: [Color(0xFF0F766E), Color(0xFF14B8A6)],
    _PulseCardType.poll: [Color(0xFF1D4ED8), Color(0xFF60A5FA)],
    _PulseCardType.icebreaker: [Color(0xFF92400E), Color(0xFFF59E0B)],
  };

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 2400),
      vsync: this,
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final colors = _gradients[d.type] ??
        [FreezmeDesignSystem.primary, const Color(0xFF9C27B0)];
    final isPoll = d.type == _PulseCardType.poll;
    final isMystery = d.type == _PulseCardType.mystery;
    final isClock = d.type == _PulseCardType.clock;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) => Container(
        width: 168,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: colors[0].withValues(alpha: 0.28 + _pulse.value * 0.14),
              blurRadius: 18 + _pulse.value * 8,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: child,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top row: icon + LIVE badge ──────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(d.icon, size: 18, color: Colors.white),
                ),
                if (d.isLive)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: Color(0xFF4ADE80),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            const Spacer(),

            // ── Hero content by card type ───────────────────────────────

            // Mystery: big score number
            if (isMystery) ...[
              Text(
                '${d.compatScore}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'vibe match nearby',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Unlock with Plus ✦',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ]

            // Clock: large countdown
            else if (isClock) ...[
              Text(
                d.sub.contains('—')
                    ? d.sub.split('—').last.trim()
                    : d.sub,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'until pool closes',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ]

            // Poll: question + two tap buttons
            else if (isPoll && d.pollOptions != null) ...[
              Text(
                d.sub,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (int i = 0; i < d.pollOptions!.length; i++) ...[
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _pollVote = i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          decoration: BoxDecoration(
                            color: _pollVote == i
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            d.pollOptions![i],
                            style: TextStyle(
                              color: _pollVote == i
                                  ? const Color(0xFF1D4ED8)
                                  : Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (i == 0) const SizedBox(width: 6),
                  ],
                ],
              ),
            ]

            // Default (heat, spark, icebreaker)
            else ...[
              Text(
                d.headline,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                d.sub,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 11,
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LivePathCard extends StatefulWidget {
  final PathsPresence presence;

  const _LivePathCard({required this.presence});

  @override
  State<_LivePathCard> createState() => _LivePathCardState();
}

class _LivePathCardState extends State<_LivePathCard> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determine activity from intents
    final activity = widget.presence.intents.isNotEmpty 
        ? widget.presence.intents.first 
        : 'Out Tonight';
        
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        // TODO: Navigate to profile or send wave
      },
      child: Container(
        width: 110,
        height: 125,
        margin: const EdgeInsets.only(right: FreezmeDesignSystem.spaceMd),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(FreezmeDesignSystem.radiusLg),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              FreezmeDesignSystem.primary.withValues(alpha: 0.08),
              FreezmeDesignSystem.primaryLight.withValues(alpha: 0.3),
            ],
          ),
          border: Border.all(
            color: FreezmeDesignSystem.primary.withValues(alpha: 0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: FreezmeDesignSystem.primary.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Avatar with online pulse
            Stack(
              children: [
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: FreezmeDesignSystem.success.withValues(alpha: 0.3 + (_pulseAnimation.value * 0.4)),
                          width: 2,
                        ),
                      ),
                      child: child,
                    );
                  },
                  child: UserAvatar(
                    size: 44,
                    // Use a mock image or initials if not provided
                    initials: widget.presence.uid.substring(0, 2).toUpperCase(),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: FreezmeDesignSystem.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Activity
            Text(
              activity,
              style: FreezmeDesignSystem.caption.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 11,
                color: FreezmeDesignSystem.textPrimary,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            // Distance with icon
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.location_on,
                  size: 10,
                  color: FreezmeDesignSystem.primary.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 2),
                Text(
                  'Nearby', // Simplified for now
                  style: FreezmeDesignSystem.caption.copyWith(
                    fontSize: 10,
                    color: FreezmeDesignSystem.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}



class _TonightProfileCard extends StatelessWidget {
  final models.VibeProfile profile;

  const _TonightProfileCard({required this.profile});

  static const double _cardWidth = 180;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ProfileDetailPage(profile: profile),
        ),
      ),
      child: Container(
        width: _cardWidth,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: FreezmeDesignSystem.primary.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Photo (fills top ~65% of card) ──────────────────────────────
            Expanded(
              flex: 65,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: profile.imageUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: 540,
                    placeholder: (context, _) => Container(
                      color: FreezmeDesignSystem.primaryLight,
                      child: const Center(
                        child: Icon(Icons.person, color: FreezmeDesignSystem.primary, size: 48),
                      ),
                    ),
                    errorWidget: (context, _, e) => Container(
                      color: FreezmeDesignSystem.primaryLight,
                      child: const Center(
                        child: Icon(Icons.person, color: FreezmeDesignSystem.primary, size: 48),
                      ),
                    ),
                  ),
                  // Bottom fade-to-white gradient so name blends in
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 48,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.white.withValues(alpha: 0.9),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Compatibility badge
                  if (profile.compatibility > 0)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: FreezmeDesignSystem.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.flash_on, size: 10, color: Colors.white),
                            Text(
                              '${profile.compatibility}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Like button top-right
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () {
                        final flow = AppFlowScope.of(context, listen: false);
                        flow.repository.likeProfile(profile.uid);
                        PremiumSnackBar.show(context, 'You liked ${profile.name}!', type: SnackBarType.success);
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.favorite_border_rounded,
                          size: 16,
                          color: FreezmeDesignSystem.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ── Info strip (bottom ~35%) ────────────────────────────────────
            Expanded(
              flex: 35,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${profile.name}, ${profile.age}',
                      style: FreezmeDesignSystem.h3.copyWith(fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (profile.bio.isNotEmpty)
                      Text(
                        profile.bio,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: FreezmeDesignSystem.caption.copyWith(
                          fontSize: 11,
                          color: FreezmeDesignSystem.textSecondary,
                        ),
                      ),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 10, color: FreezmeDesignSystem.primary),
                        const SizedBox(width: 2),
                        Text(
                          profile.distance,
                          style: FreezmeDesignSystem.caption.copyWith(
                            fontSize: 10,
                            color: FreezmeDesignSystem.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
