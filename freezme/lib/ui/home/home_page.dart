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
              FreezmeDesignSystem.spaceMd,
              FreezmeDesignSystem.spaceLg,
              FreezmeDesignSystem.spaceMd,
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
          const SizedBox(height: FreezmeDesignSystem.spaceLg),
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
          const SizedBox(height: FreezmeDesignSystem.spaceLg),
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

  void _showSheet(BuildContext context) {
    final d = widget.data;
    final colors = _gradients[d.type] ??
        [FreezmeDesignSystem.primary, const Color(0xFF9C27B0)];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PulseCardSheet(data: d, colors: colors, pollVote: _pollVote,
        onPollVote: (i) => setState(() => _pollVote = i)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final colors = _gradients[d.type] ??
        [FreezmeDesignSystem.primary, const Color(0xFF9C27B0)];
    final isPoll = d.type == _PulseCardType.poll;
    final isMystery = d.type == _PulseCardType.mystery;
    final isClock = d.type == _PulseCardType.clock;

    return GestureDetector(
      onTap: () => _showSheet(context),
      child: AnimatedBuilder(
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
              // ── Top row: icon + LIVE badge ─────────────────────────────
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
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
              // ── Hero content ───────────────────────────────────────────
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
                      fontWeight: FontWeight.w500),
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
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ] else if (isClock) ...[
                Text(
                  d.sub.contains('—') ? d.sub.split('—').last.trim() : d.sub,
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
                      fontWeight: FontWeight.w500),
                ),
              ] else if (isPoll && d.pollOptions != null) ...[
                Text(
                  d.sub,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.35),
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
              ] else ...[
                Text(
                  d.headline,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      height: 1.2),
                ),
                const SizedBox(height: 6),
                Text(
                  d.sub,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 11,
                      height: 1.4),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Bottom sheet for each pulse card ────────────────────────────────────────
class _PulseCardSheet extends StatefulWidget {
  const _PulseCardSheet({
    required this.data,
    required this.colors,
    required this.pollVote,
    required this.onPollVote,
  });

  final _PulseCardData data;
  final List<Color> colors;
  final int? pollVote;
  final ValueChanged<int> onPollVote;

  @override
  State<_PulseCardSheet> createState() => _PulseCardSheetState();
}

class _PulseCardSheetState extends State<_PulseCardSheet> {
  late int? _vote;

  @override
  void initState() {
    super.initState();
    _vote = widget.pollVote;
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final colors = widget.colors;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Gradient header ─────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: colors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(d.icon, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        d.headline,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (d.isLive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.circle,
                                size: 7, color: Color(0xFF4ADE80)),
                            SizedBox(width: 4),
                            Text('LIVE',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // ── Body ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: _buildSheetBody(context, d, colors),
          ),

          // ── Bottom safe area ────────────────────────────────────────────
          SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
        ],
      ),
    );
  }

  Widget _buildSheetBody(
      BuildContext context, _PulseCardData d, List<Color> colors) {
    switch (d.type) {
      case _PulseCardType.heat:
        return _SheetHeat(colors: colors);
      case _PulseCardType.mystery:
        return _SheetMystery(score: d.compatScore ?? 94, colors: colors);
      case _PulseCardType.spark:
        return _SheetSpark(colors: colors);
      case _PulseCardType.clock:
        return _SheetClock(countdown: d.sub, colors: colors);
      case _PulseCardType.poll:
        return _SheetPoll(
          question: d.sub,
          options: d.pollOptions ?? ['Agree', 'Disagree'],
          vote: _vote,
          colors: colors,
          onVote: (i) {
            setState(() => _vote = i);
            widget.onPollVote(i);
          },
        );
      case _PulseCardType.icebreaker:
        return _SheetIcebreaker(question: d.sub, colors: colors);
    }
  }
}

// ── Sheet body variants ───────────────────────────────────────────────────────

class _SheetHeat extends StatelessWidget {
  const _SheetHeat({required this.colors});
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatRow(icon: Icons.people_alt_rounded, label: '12 people', sub: 'active in your area right now', colors: colors),
        const SizedBox(height: 12),
        _StatRow(icon: Icons.trending_up_rounded, label: 'Peak window', sub: '9 PM – 11 PM tonight', colors: colors),
        const SizedBox(height: 12),
        _StatRow(icon: Icons.location_on_rounded, label: 'Near you', sub: 'No precise location shared', colors: colors),
        const SizedBox(height: 24),
        Text('Open tonight\'s pool to meet them.',
            style: TextStyle(color: FreezmeDesignSystem.textSecondary, fontSize: 13, height: 1.5)),
        const SizedBox(height: 20),
        _SheetPrimaryButton(label: 'View Tonight\'s Pool', colors: colors,
            onTap: () => Navigator.pop(context)),
      ],
    );
  }
}

class _SheetMystery extends StatelessWidget {
  const _SheetMystery({required this.score, required this.colors});
  final int score;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors[0].withValues(alpha: 0.1),
              ),
              child: Icon(Icons.lock_rounded, color: colors[0], size: 28),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$score% Vibe Match',
                    style: TextStyle(
                        color: colors[0],
                        fontSize: 22,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                const Text('Someone nearby — identity hidden',
                    style: TextStyle(
                        color: FreezmeDesignSystem.textSecondary, fontSize: 13)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),
        _InfoCard(
          icon: Icons.shield_outlined,
          text: 'We never reveal who this person is without mutual consent.',
          colors: colors,
        ),
        const SizedBox(height: 12),
        _InfoCard(
          icon: Icons.star_rounded,
          text: 'Unlock with Freezme+ to see their profile and send a match request.',
          colors: colors,
        ),
        const SizedBox(height: 24),
        _SheetPrimaryButton(label: 'Unlock with Freezme+ ✦', colors: colors,
            onTap: () => Navigator.pop(context)),
      ],
    );
  }
}

class _SheetSpark extends StatelessWidget {
  const _SheetSpark({required this.colors});
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatRow(icon: Icons.favorite_rounded, label: '3 connections', sub: 'made near you in the last hour', colors: colors),
        const SizedBox(height: 12),
        _StatRow(icon: Icons.groups_rounded, label: 'All anonymous', sub: 'No personal details shared', colors: colors),
        const SizedBox(height: 20),
        _InfoCard(
          icon: Icons.info_outline_rounded,
          text: 'Connections happen when two people both like each other. You could be next.',
          colors: colors,
        ),
        const SizedBox(height: 24),
        _SheetPrimaryButton(label: 'See Tonight\'s Pool', colors: colors,
            onTap: () => Navigator.pop(context)),
      ],
    );
  }
}

class _SheetClock extends StatelessWidget {
  const _SheetClock({required this.countdown, required this.colors});
  final String countdown;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final time = countdown.contains('—') ? countdown.split('—').last.trim() : countdown;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            time,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white, fontSize: 42, fontWeight: FontWeight.w900, letterSpacing: 2),
          ),
        ),
        const SizedBox(height: 16),
        _InfoCard(
          icon: Icons.lock_clock,
          text: 'Tonight\'s pool resets at 6 PM tomorrow. Profiles you haven\'t seen yet will be gone.',
          colors: colors,
        ),
        const SizedBox(height: 24),
        _SheetPrimaryButton(label: 'Browse Pool Now', colors: colors,
            onTap: () => Navigator.pop(context)),
      ],
    );
  }
}

class _SheetPoll extends StatelessWidget {
  const _SheetPoll({
    required this.question,
    required this.options,
    required this.vote,
    required this.colors,
    required this.onVote,
  });
  final String question;
  final List<String> options;
  final int? vote;
  final List<Color> colors;
  final ValueChanged<int> onVote;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question,
          style: const TextStyle(
              fontSize: 17, fontWeight: FontWeight.w700, height: 1.4),
        ),
        const SizedBox(height: 8),
        const Text(
          'Anonymous · results shown after you vote',
          style: TextStyle(color: FreezmeDesignSystem.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 20),
        for (int i = 0; i < options.length; i++) ...[
          GestureDetector(
            onTap: () => onVote(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                gradient: vote == i
                    ? LinearGradient(colors: colors)
                    : null,
                color: vote == i ? null : colors[0].withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: vote == i ? Colors.transparent : colors[0].withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                options[i],
                style: TextStyle(
                  color: vote == i ? Colors.white : colors[0],
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
        if (vote != null) ...[
          const SizedBox(height: 8),
          Text(
            'You voted: ${options[vote!]}  ·  Results update in real time',
            style: TextStyle(
                color: colors[0], fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}

class _SheetIcebreaker extends StatelessWidget {
  const _SheetIcebreaker({required this.question, required this.colors});
  final String question;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors[0].withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors[0].withValues(alpha: 0.15)),
          ),
          child: Text(
            '"$question"',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: colors[0],
                height: 1.45),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Use this as your opening line tonight. It\'s refreshed daily.',
          style: TextStyle(
              color: FreezmeDesignSystem.textSecondary,
              fontSize: 13,
              height: 1.5),
        ),
        const SizedBox(height: 24),
        _SheetPrimaryButton(
            label: 'Copy to clipboard',
            colors: colors,
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied to clipboard!')),
              );
            }),
      ],
    );
  }
}

// ── Shared sheet components ───────────────────────────────────────────────────

class _StatRow extends StatelessWidget {
  const _StatRow({required this.icon, required this.label, required this.sub, required this.colors});
  final IconData icon;
  final String label;
  final String sub;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colors[0].withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: colors[0], size: 18),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14)),
            Text(sub,
                style: const TextStyle(
                    color: FreezmeDesignSystem.textSecondary, fontSize: 12)),
          ],
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.text, required this.colors});
  final IconData icon;
  final String text;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors[0].withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors[0].withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: colors[0]),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 13,
                    color: FreezmeDesignSystem.textSecondary,
                    height: 1.4)),
          ),
        ],
      ),
    );
  }
}

class _SheetPrimaryButton extends StatelessWidget {
  const _SheetPrimaryButton({required this.label, required this.colors, required this.onTap});
  final String label;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: colors,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: colors[0].withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
              color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

// ─── Trust badge ─────────────────────────────────────────────────────────────
enum _TrustTier { basic, verified, elite }

class _TrustBadge extends StatelessWidget {
  const _TrustBadge({required this.tier});
  final _TrustTier tier;

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (tier) {
      _TrustTier.elite    => (Icons.workspace_premium_rounded, const Color(0xFFF59E0B), 'Elite'),
      _TrustTier.verified => (Icons.verified_rounded,          const Color(0xFF6B21A8), 'Verified'),
      _TrustTier.basic    => (Icons.check_circle_outline,      const Color(0xFF6B7280), 'Basic'),
    };

    return Tooltip(
      message: '$label member',
      child: Icon(icon, size: 14, color: color),
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${profile.name}, ${profile.age}',
                            style: FreezmeDesignSystem.h3.copyWith(fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (profile.isPremium)
                          _TrustBadge(tier: _TrustTier.verified),
                      ],
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
