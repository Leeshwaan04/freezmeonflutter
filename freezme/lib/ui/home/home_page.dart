import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../data/freezme_repository.dart';
import '../../main.dart';
import '../../models/vibe_profile.dart' as models;
import '../theme.dart';

const bool kLowMotion = false;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isLoading = true;
  List<models.VibeProfile> _tonightPool = [];
  // TODO: Add Paths data model

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // TODO: Fetch real data using Tonight Algorithm
    // For now, we'll simulate a delay and use mock data
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      final flow = AppFlowScope.of(context, listen: false);
      final profiles = await flow.repository.fetchDailyProfiles(); // Will be replaced by fetchTonightPool
      setState(() {
        _tonightPool = profiles;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final flow = AppFlowScope.of(context, listen: true);

    return Scaffold(
      backgroundColor: FreezmeColors.background,
      bottomNavigationBar: SafeArea(
        top: false,
        child: _BottomNavBar(
          currentIndex: flow.currentTabIndex,
          onTap: flow.openTab,
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadData,
                child: CustomScrollView(
                  key: const PageStorageKey('homeScroll'),
                  slivers: [
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
                    border: Border.all(color: FreezmeColors.primary.withOpacity(0.2)),
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
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text("TONIGHT'S POOL", style: FreezmeTypography.title),
              SizedBox(height: 8),
              _EmptyState(),
            ],
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
            backgroundColor: FreezmeColors.primary.withOpacity(0.1),
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
        boxShadow: kLowMotion
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
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
