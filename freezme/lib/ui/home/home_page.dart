import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import '../../data/freezme_repository.dart';
import '../../main.dart';
import '../../models/vibe_profile.dart' as models;
import '../../services/location_service.dart';
import '../theme.dart';
import '../shared/state_views.dart';
import '../shared/bottom_nav_bar.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isLoading = true;
  bool _hasError = false;
  List<models.VibeProfile> _tonightPool = [];
  // TODO: Add Paths data model

  @override
  void initState() {
    super.initState();
    _loadData();
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
      backgroundColor: FreezmeColors.background,
      bottomNavigationBar: SafeArea(
        top: false,
        child: FreezmeBottomNavBar(
          currentIndex: flow.currentTabIndex,
          onTap: flow.openTab,
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const LoadingView(message: 'Fetching tonight\'s pool...')
            : _hasError && _tonightPool.isEmpty
                ? ErrorView(
                    message: 'Could not load tonight\'s pool.',
                    onRetry: _loadData,
                  )
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: CustomScrollView(
                      key: const PageStorageKey('homeScroll'),
                      slivers: [
                        if (!flow.isProfileComplete) _buildProfileGate(flow),
                        _buildHeader(),
                        _buildLivePathsSection(),
                        _buildTonightPoolSection(),
                        _buildTrendingFeedSection(),
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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: FreezmeColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.lock_outline,
                        color: FreezmeColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Complete your profile to unlock Tonight',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${flow.completionPercent}% complete · add photos, bio, preferences',
                          style: const TextStyle(
                            fontSize: 12,
                            color: FreezmeColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        AppFlowScope.of(context, listen: false)
                            .replaceStack(<AppStage>[AppStage.profileCompletion]),
                    child: const Text(
                      'Finish',
                      style: TextStyle(
                        color: FreezmeColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
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
        padding: const EdgeInsets.all(16.0),
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
                      style: FreezmeTypography.caption.copyWith(
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'New York 🗽', // TODO: Geo-location
                      style: FreezmeTypography.display,
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: FreezmeColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: FreezmeColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 16, color: FreezmeColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        '04:20:00', // TODO: Countdown
                        style: FreezmeTypography.body.copyWith(
                          color: FreezmeColors.primary,
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
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                const Icon(Icons.circle, size: 12, color: FreezmeColors.success),
                const SizedBox(width: 8),
                Text(
                  'LIVE NOW',
                  style: FreezmeTypography.title.copyWith(fontSize: 18),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 5, // Mock count
              itemBuilder: (context, index) {
                return _LivePathCard(index: index);
              },
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildTonightPoolSection() {
    if (_tonightPool.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: EmptyView(
            title: "No vibes yet",
            subtitle: "Check back closer to 6 PM or adjust your radius.",
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
              child: Text(
                "TONIGHT'S POOL",
                style: FreezmeTypography.title.copyWith(fontSize: 18),
              ),
            );
          }
          final profile = _tonightPool[index - 1];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
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
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'TRENDING VIBES',
              style: FreezmeTypography.title.copyWith(fontSize: 18),
            ),
          ),
          const SizedBox(height: 12),
          // Placeholder for Feed integration
          Container(
            height: 200,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: FreezmeColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Text('Feed Integration Coming Soon'),
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
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: FreezmeColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FreezmeColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: FreezmeColors.primary.withValues(alpha: 0.1),
            child: Text('U$index'),
          ),
          const SizedBox(height: 8),
          Text(
            'Grabbing Drinks',
            style: FreezmeTypography.caption.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          Text(
            '2km away',
            style: FreezmeTypography.caption.copyWith(fontSize: 10),
          ),
        ],
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
      height: 100,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: FreezmeColors.lowMotion
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
            child: CachedNetworkImage(
              imageUrl: profile.imageUrl,
              width: 100,
              height: 100,
              fit: BoxFit.cover,
              memCacheWidth: 200,
              memCacheHeight: 200,
              placeholder: (context, _) => Container(
                width: 100,
                height: 100,
                color: FreezmeColors.surfaceAlt,
                child: const Icon(Icons.person, color: FreezmeColors.primary),
              ),
              errorWidget: (context, _, __) => Container(
                width: 100,
                height: 100,
                color: FreezmeColors.surfaceAlt,
                child: const Icon(Icons.person, color: FreezmeColors.primary),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${profile.name}, ${profile.age}',
                    style: FreezmeTypography.title.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    profile.bio,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FreezmeTypography.bodyMuted,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 12, color: FreezmeColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        profile.distance,
                        style: FreezmeTypography.caption.copyWith(color: FreezmeColors.primary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.favorite_border),
            onPressed: () {}, // TODO: Like action
            color: FreezmeColors.primary,
          ),
        ],
      ),
    );
  }
}
