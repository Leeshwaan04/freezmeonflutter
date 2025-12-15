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

class _LivePathCard extends StatelessWidget {
  final int index;

  const _LivePathCard({required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: FreezmeDesignSystem.spaceMd),
      child: PremiumCard(
        padding: EdgeInsets.all(FreezmeDesignSystem.spaceMd),
        onTap: () {},
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: FreezmeDesignSystem.primary.withValues(alpha: 0.1),
              child: Text('U$index', style: const TextStyle(fontWeight: FontWeight.bold, color: FreezmeDesignSystem.primary)),
            ),
            const SizedBox(height: FreezmeDesignSystem.spaceSm),
            Text(
              'Grabbing Drinks',
              style: FreezmeDesignSystem.caption.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            Text(
              '2km away',
              style: FreezmeDesignSystem.caption.copyWith(fontSize: 10, color: FreezmeDesignSystem.textSecondary),
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
    return PremiumCard(
      padding: EdgeInsets.zero,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ProfileDetailPage(profile: profile),
          ),
        );
      },
      child: SizedBox(
        height: 110,
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(FreezmeDesignSystem.radiusLg)),
              child: CachedNetworkImage(
                imageUrl: profile.imageUrl,
                width: 100,
                height: 110,
                fit: BoxFit.cover,
                memCacheWidth: 200,
                memCacheHeight: 200,
                placeholder: (context, _) => Container(
                  width: 100,
                  height: 110,
                  color: FreezmeDesignSystem.surfaceAlt,
                  child: const Icon(Icons.person, color: FreezmeDesignSystem.textTertiary),
                ),
                errorWidget: (context, _, __) => Container(
                  width: 100,
                  height: 110,
                  color: FreezmeDesignSystem.surfaceAlt,
                  child: const Icon(Icons.person, color: FreezmeDesignSystem.textTertiary),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(FreezmeDesignSystem.spaceMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${profile.name}, ${profile.age}',
                      style: FreezmeDesignSystem.h3,
                    ),
                    const SizedBox(height: FreezmeDesignSystem.spaceXs),
                    Text(
                      profile.bio,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FreezmeDesignSystem.caption,
                    ),
                    const SizedBox(height: FreezmeDesignSystem.spaceSm),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 12, color: FreezmeDesignSystem.primary),
                        const SizedBox(width: 4),
                        Text(
                          profile.distance,
                          style: FreezmeDesignSystem.caption.copyWith(color: FreezmeDesignSystem.primary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: FreezmeDesignSystem.spaceSm),
              child: IconButton(
                icon: const Icon(Icons.favorite_border),
                onPressed: () {
                   final flow = AppFlowScope.of(context, listen: false);
                   flow.repository.likeProfile(profile.uid);
                   PremiumSnackBar.show(context, 'You liked ${profile.name}!', type: SnackBarType.success);
                },
                color: FreezmeDesignSystem.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
