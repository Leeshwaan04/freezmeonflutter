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
          // Set location name based on coordinates for simulation realism
          if (locationResult.lat != null) {
            _locationName = 'Downtown area'; 
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
                const SizedBox(width: FreezmeDesignSystem.spaceMd),
                GestureDetector(
                  onTap: () => AppFlowScope.of(context, listen: false).openTab(4), // Profile tab
                  child: UserAvatar(
                    imageUrl: AppFlowScope.of(context, listen: false).profilePhotoUrl,
                    size: 40,
                    isPremium: AppFlowScope.of(context, listen: false).isPremium,
                  ),
                ),
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
      return const SizedBox.shrink();
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

    return SliverList(
      key: key,
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

  Widget _buildTrendingFeedSection({Key? key}) {
    final flow = AppFlowScope.of(context);
    return SliverToBoxAdapter(
      key: key,
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
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: flow.repository.watchFeed(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: FreezmeDesignSystem.spaceLg),
                  child: SkeletonLoader(width: double.infinity, height: 120),
                );
              }
              
              final posts = snapshot.data ?? [];
              if (posts.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: FreezmeDesignSystem.spaceLg),
                  child: PremiumCard(
                     variant: CardVariant.flat,
                     child: Container(
                       height: 120,
                       alignment: Alignment.center,
                       child: const Column(
                         mainAxisAlignment: MainAxisAlignment.center,
                         children: [
                           Icon(Icons.auto_awesome, color: FreezmeDesignSystem.primary, size: 32),
                           SizedBox(height: FreezmeDesignSystem.spaceSm),
                           Text('Feed Integration Coming Soon', style: FreezmeDesignSystem.caption),
                         ],
                       ),
                     ),
                  ),
                );
              }

              return Column(
                children: posts.map((post) => _FeedPostItem(post: post)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FeedPostItem extends StatelessWidget {
  final Map<String, dynamic> post;

  const _FeedPostItem({required this.post});

  @override
  Widget build(BuildContext context) {
    final photoUrls = List<String>.from(post['photoUrls'] ?? []);
    final caption = post['caption'] ?? '';
    final senderName = post['senderName'] ?? 'Freezme User';
    final senderPhoto = post['senderPhotoUrl'] ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: FreezmeDesignSystem.spaceLg, vertical: FreezmeDesignSystem.spaceSm),
      child: Container(
        decoration: FreezmeDesignSystem.cardDecoration,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User section
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  UserAvatar(imageUrl: senderPhoto, size: 32),
                  const SizedBox(width: 10),
                  Text(senderName, style: FreezmeDesignSystem.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            // Image
            if (photoUrls.isNotEmpty)
              CachedNetworkImage(
                imageUrl: photoUrls.first,
                width: double.infinity,
                height: 250,
                fit: BoxFit.cover,
              ),
            // Caption
            if (caption.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(caption, style: FreezmeDesignSystem.body),
              ),
            // Actions
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  Icon(Icons.favorite_border_rounded, size: 20, color: FreezmeDesignSystem.textSecondary),
                  SizedBox(width: 16),
                  Icon(Icons.chat_bubble_outline_rounded, size: 20, color: FreezmeDesignSystem.textSecondary),
                ],
              ),
            ),
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
                          decoration: const BoxDecoration(
                            color: FreezmeDesignSystem.primaryLight,
                          ),
                          child: const Icon(Icons.person, color: FreezmeDesignSystem.primary, size: 40),
                        ),
                        errorWidget: (context, _, _) => Container(
                          width: 110,
                          height: 120,
                          decoration: const BoxDecoration(
                            color: FreezmeDesignSystem.primaryLight,
                          ),
                          child: const Icon(Icons.person, color: FreezmeDesignSystem.primary, size: 40),
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
                            color: FreezmeDesignSystem.primary,
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
                                  const Icon(
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
                  decoration: const BoxDecoration(
                    color: FreezmeDesignSystem.primaryLight,
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
                    color: FreezmeDesignSystem.primary,
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
