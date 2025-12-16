import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'dart:async'; // Added
import '../../data/freezme_repository.dart';
import '../../main.dart';
import '../../models/vibe_profile.dart' as models;
import '../../services/location_service.dart';
import '../design_system.dart';
import '../components/premium_components.dart';
import '../components/skeleton_loaders.dart';
import '../shared/bottom_nav_bar.dart';
import '../profile/profile_detail_page.dart'; // Added

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
      final timezone = await FlutterTimezone.getLocalTimezone();

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

  @override
  Widget build(BuildContext context) {
    final flow = AppFlowScope.of(context, listen: true);

    return Scaffold(
      backgroundColor: FreezmeDesignSystem.background,
      bottomNavigationBar: SafeArea(
        top: false,
        child: FreezmeBottomNavBar(
          currentIndex: flow.currentTabIndex,
          onTap: flow.openTab,
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: FreezmeDesignSystem.primary,
          backgroundColor: FreezmeDesignSystem.surface,
          onRefresh: _loadData,
          child: CustomScrollView(
            key: const PageStorageKey('homeScroll'),
            slivers: [
              _buildHeader(),
              if (!flow.isProfileComplete) _buildProfileGate(flow),
              if (_isLoading) ...[
                 _buildLivePathsSkeleton(),
                 _buildTonightPoolSkeleton(),
              ] else if (_hasError && _tonightPool.isEmpty) ...[
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: ErrorStateView(
                    message: 'Could not load tonight\'s pool.',
                    onRetry: _loadData,
                  ),
                )
              ] else ...[
                _buildLivePathsSection(),
                _buildTonightPoolSection(),
                _buildTrendingFeedSection(),
              ],
              const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
            ],
          ),
        ),
      ),
    );
  }

  SliverToBoxAdapter _buildProfileGate(AppFlowController flow) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: FreezmeDesignSystem.spaceLg, vertical: FreezmeDesignSystem.spaceMd),
        child: PremiumCard(
          gradient: FreezmeGradients.primary,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                   Container(
                    padding: const EdgeInsets.all(FreezmeDesignSystem.spaceSm),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(FreezmeDesignSystem.radiusMd),
                    ),
                    child: const Icon(Icons.rocket_launch, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: FreezmeDesignSystem.spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Unlock Tonight Mode',
                          style: FreezmeDesignSystem.bodyMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: FreezmeDesignSystem.spaceXs),
                        Text(
                          '${flow.completionPercent}% complete · Match with people nearby',
                          style: FreezmeDesignSystem.caption.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: FreezmeDesignSystem.spaceMd),
              SizedBox(
                width: double.infinity,
                child: PremiumButton(
                  label: 'Complete Profile',
                  onPressed: () => AppFlowScope.of(context, listen: false)
                      .replaceStack(<AppStage>[AppStage.profileCompletion]),
                  variant: ButtonVariant.filled,
                  // Use a white button style for contrast
                  backgroundColor: Colors.white,
                  textColor: FreezmeDesignSystem.primary,
                ),
              ),
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
                Column(
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
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: FreezmeDesignSystem.surface,
                    borderRadius: BorderRadius.circular(FreezmeDesignSystem.radiusFull),
                    border: Border.all(color: FreezmeDesignSystem.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 16, color: FreezmeDesignSystem.primary),
                      const SizedBox(width: 4),
                      Text(
                        _countdown,
                        style: FreezmeDesignSystem.small.copyWith(
                          color: FreezmeDesignSystem.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLivePathsSection() {
    return SliverToBoxAdapter(
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
              itemCount: 5, // Mock count
              itemBuilder: (context, index) {
                return _LivePathCard(index: index);
              },
            ),
          ),
          const SizedBox(height: FreezmeDesignSystem.spaceXl),
        ],
      ),
    );
  }
  
  Widget _buildLivePathsSkeleton() {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: FreezmeDesignSystem.spaceLg),
            child: const SkeletonLoader(width: 100, height: 20),
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
  
  Widget _buildTonightPoolSkeleton() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: FreezmeDesignSystem.spaceLg, vertical: FreezmeDesignSystem.spaceSm),
              child: const SkeletonLoader(width: 150, height: 24),
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

  Widget _buildTonightPoolSection() {
    if (_tonightPool.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(FreezmeDesignSystem.spaceLg),
          child: EmptyStateView(
            icon: Icons.nightlife,
            title: "No vibes tonight yet",
            subtitle: "Check back closer to 6 PM or adjust your radius to find people nearby.",
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: FreezmeDesignSystem.spaceLg, vertical: FreezmeDesignSystem.spaceSm),
              child: Text(
                "TONIGHT'S POOL",
                style: FreezmeDesignSystem.h3.copyWith(fontSize: 18),
              ),
            );
          }
          final profile = _tonightPool[index - 1];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: FreezmeDesignSystem.spaceLg, vertical: FreezmeDesignSystem.spaceSm),
            child: _TonightProfileCard(profile: profile),
          );
        },
        childCount: _tonightPool.length + 1,
      ),
    );
  }

  Widget _buildTrendingFeedSection() {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: FreezmeDesignSystem.spaceXl),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: FreezmeDesignSystem.spaceLg),
            child: Text(
              'TRENDING VIBES',
              style: FreezmeDesignSystem.h3.copyWith(fontSize: 18),
            ),
          ),
          const SizedBox(height: FreezmeDesignSystem.spaceMd),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: FreezmeDesignSystem.spaceLg),
            child: PremiumCard(
               variant: CardVariant.flat,
               onTap: (){},
               child: Container(
                 height: 120,
                 alignment: Alignment.center,
                 child: Column(
                   mainAxisAlignment: MainAxisAlignment.center,
                   children: [
                     Icon(Icons.auto_awesome, color: FreezmeDesignSystem.primary, size: 32),
                     const SizedBox(height: FreezmeDesignSystem.spaceSm),
                     const Text('Feed Integration Coming Soon', style: FreezmeDesignSystem.caption),
                   ],
                 ),
               ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LivePathCard extends StatefulWidget {
  final int index;

  const _LivePathCard({required this.index});

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
    final activities = ['Grabbing Drinks', 'Coffee Date', 'Evening Walk', 'Chilling', 'Out Tonight'];
    final distances = ['0.5km', '1.2km', '2km', '3.5km', '5km'];
    
    return GestureDetector(
      onTap: () {
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
              FreezmeDesignSystem.primary.withValues(alpha: 0.1),
              FreezmeDesignSystem.secondary.withValues(alpha: 0.05),
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
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: FreezmeDesignSystem.primary.withValues(alpha: 0.15),
                    child: Text(
                      'U${widget.index}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: FreezmeDesignSystem.primary,
                      ),
                    ),
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
              activities[widget.index % activities.length],
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
                  distances[widget.index % distances.length],
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

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: FreezmeDesignSystem.spaceSm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(FreezmeDesignSystem.radiusLg),
        boxShadow: [
          BoxShadow(
            color: FreezmeDesignSystem.primary.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: FreezmeDesignSystem.border.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(FreezmeDesignSystem.radiusLg),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ProfileDetailPage(profile: profile),
              ),
            );
          },
          child: SizedBox(
            height: 120,
            child: Row(
              children: [
                // Profile Image with gradient overlay
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(FreezmeDesignSystem.radiusLg)),
                      child: CachedNetworkImage(
                        imageUrl: profile.imageUrl,
                        width: 110,
                        height: 120,
                        fit: BoxFit.cover,
                        memCacheWidth: 220,
                        memCacheHeight: 240,
                        placeholder: (context, _) => Container(
                          width: 110,
                          height: 120,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                FreezmeDesignSystem.primary.withValues(alpha: 0.2),
                                FreezmeDesignSystem.secondary.withValues(alpha: 0.2),
                              ],
                            ),
                          ),
                          child: const Icon(Icons.person, color: Colors.white54, size: 40),
                        ),
                        errorWidget: (context, _, __) => Container(
                          width: 110,
                          height: 120,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                FreezmeDesignSystem.primary.withValues(alpha: 0.3),
                                FreezmeDesignSystem.secondary.withValues(alpha: 0.3),
                              ],
                            ),
                          ),
                          child: const Icon(Icons.person, color: Colors.white70, size: 40),
                        ),
                      ),
                    ),
                    // Compatibility badge
                    if (profile.compatibility > 0)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [FreezmeDesignSystem.primary, FreezmeDesignSystem.secondary],
                            ),
                            borderRadius: BorderRadius.circular(12),
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
                  ],
                ),
                // Profile Info
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(FreezmeDesignSystem.spaceMd),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${profile.name}, ${profile.age}',
                          style: FreezmeDesignSystem.h3.copyWith(fontSize: 17),
                        ),
                        const SizedBox(height: 4),
                        if (profile.bio.isNotEmpty)
                          Text(
                            profile.bio,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: FreezmeDesignSystem.caption.copyWith(
                              fontSize: 12,
                              color: FreezmeDesignSystem.textSecondary,
                              height: 1.3,
                            ),
                          ),
                        const Spacer(),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: FreezmeDesignSystem.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 12,
                                    color: FreezmeDesignSystem.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    profile.distance,
                                    style: FreezmeDesignSystem.caption.copyWith(
                                      fontSize: 11,
                                      color: FreezmeDesignSystem.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Like Button
                Container(
                  margin: const EdgeInsets.only(right: FreezmeDesignSystem.spaceMd),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        FreezmeDesignSystem.secondary.withValues(alpha: 0.1),
                        FreezmeDesignSystem.primary.withValues(alpha: 0.1),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.favorite_border_rounded),
                    iconSize: 24,
                    onPressed: () {
                       final flow = AppFlowScope.of(context, listen: false);
                       flow.repository.likeProfile(profile.uid);
                       PremiumSnackBar.show(context, 'You liked ${profile.name}! 💜', type: SnackBarType.success);
                    },
                    color: FreezmeDesignSystem.secondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
