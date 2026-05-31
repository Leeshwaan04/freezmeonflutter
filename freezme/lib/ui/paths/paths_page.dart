import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../main.dart';
import '../../models/paths.dart';
import '../design_system.dart';
import '../components/aurora_background.dart';
import '../components/premium_components.dart';
import '../components/skeleton_loaders.dart';

// ── Activity intents ──────────────────────────────────────────────────────────
const _kActivities = [
  (emoji: '🎉', label: 'Party',    key: 'party'),
  (emoji: '🏋️', label: 'Gym',      key: 'gym'),
  (emoji: '🚴', label: 'Cycling',  key: 'cycling'),
  (emoji: '☕', label: 'Coffee',   key: 'coffee'),
  (emoji: '🥾', label: 'Hiking',   key: 'hiking'),
  (emoji: '📚', label: 'Study',    key: 'study'),
  (emoji: '🍕', label: 'Food',     key: 'food'),
  (emoji: '🎮', label: 'Gaming',   key: 'gaming'),
  (emoji: '🎵', label: 'Music',    key: 'music'),
  (emoji: '🏃', label: 'Running',  key: 'running'),
  (emoji: '🧘', label: 'Yoga',     key: 'yoga'),
  (emoji: '🤝', label: 'Connect',  key: 'connect'),
];

class PathsPage extends StatefulWidget {
  const PathsPage({super.key});

  @override
  State<PathsPage> createState() => _PathsPageState();
}

class _PathsPageState extends State<PathsPage> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  bool _visible = false;
  double _radius = 10;
  final Set<String> _selectedActivities = {};
  int _wavesLeft = 5;
  bool _presenceBroadcast = false;   // true once we've sent presence to server
  Position? _lastPosition;
  static const _wavesKey = 'paths_waves_left';
  static const _wavesDateKey = 'paths_waves_date';
  final Map<String, String> _inviteStatusByUser = {};
  final Map<String, StreamSubscription<PathsInvite>> _inviteSubs = {};
  late final AnimationController _radarController;
  Timer? _presenceTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadWaves();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _radarController.dispose();
    _presenceTimer?.cancel();
    for (final sub in _inviteSubs.values) sub.cancel();
    super.dispose();
  }

  // Stop presence broadcast when app goes to background
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      if (_presenceBroadcast && mounted) {
        final flow = AppFlowScope.of(context, listen: false);
        _stopPresence(flow);
      }
    }
  }

  // ── Waves ─────────────────────────────────────────────────────────────────

  Future<void> _loadWaves() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (prefs.getString(_wavesDateKey) == today) {
      if (mounted) setState(() => _wavesLeft = prefs.getInt(_wavesKey) ?? 5);
    } else {
      await prefs.setInt(_wavesKey, 5);
      await prefs.setString(_wavesDateKey, today);
      if (mounted) setState(() => _wavesLeft = 5);
    }
  }

  Future<void> _consumeWave() async {
    final n = (_wavesLeft - 1).clamp(0, 99);
    setState(() => _wavesLeft = n);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_wavesKey, n);
  }

  // ── GPS + Presence ────────────────────────────────────────────────────────

  Future<Position?> _getLocation() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        _showLocationDeniedDialog(permanent: true);
        return null;
      }
      if (perm == LocationPermission.denied) {
        _showLocationDeniedDialog(permanent: false);
        return null;
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      ).timeout(const Duration(seconds: 8));
    } catch (_) {
      return null;
    }
  }

  void _showLocationDeniedDialog({required bool permanent}) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Location Required'),
        content: Text(permanent
            ? 'Location is permanently denied. Please enable it in Settings to use Paths.'
            : 'Paths needs your location to show nearby people.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (permanent) {
                await Geolocator.openAppSettings();
              } else {
                // Re-trigger broadcast after dismissing — user may have changed mind
                final flow = AppFlowScope.of(context, listen: false);
                await _broadcastPresence(flow);
              }
            },
            child: Text(permanent ? 'Open Settings' : 'Try Again'),
          ),
        ],
      ),
    );
  }

  Future<void> _broadcastPresence(AppFlowController flow) async {
    if (_selectedActivities.isEmpty) {
      if (mounted) {
        PremiumSnackBar.show(context, 'Pick at least one activity first.');
      }
      return;
    }
    final pos = await _getLocation();
    if (pos == null) return; // dialog already shown inside _getLocation
    _lastPosition = pos;
    try {
      await flow.repository.upsertPathsPresence(PathsPresence(
        uid: '',  // server uses JWT uid
        intents: _selectedActivities.toList(),
        radiusKm: _radius,
        visibleUntil: DateTime.now().add(const Duration(hours: 1)),
        lat: pos.latitude,
        lng: pos.longitude,
      ));
      setState(() => _presenceBroadcast = true);
      await _refresh(flow);
      // Auto-refresh every 3 minutes to keep presence alive
      _presenceTimer?.cancel();
      _presenceTimer = Timer.periodic(const Duration(minutes: 3), (_) {
        if (_visible && mounted) _broadcastPresence(flow);
      });
    } catch (e) {
      if (mounted) {
        PremiumSnackBar.show(context, 'Could not go live. Try again.', type: SnackBarType.error);
      }
    }
  }

  Future<void> _stopPresence(AppFlowController flow) async {
    _presenceTimer?.cancel();
    setState(() => _presenceBroadcast = false);
    try {
      await flow.repository.deletePathsPresence();
    } catch (_) {}
  }

  Future<void> _refresh(AppFlowController flow) async {
    final pos = _lastPosition ?? await _getLocation();
    if (pos == null) return;
    _lastPosition = pos;
    await flow.refreshPaths(radiusKm: _radius, intents: _selectedActivities);
    if (mounted) setState(() {});
  }

  // ── Invite / Wave ─────────────────────────────────────────────────────────

  Future<void> _sendInvite(AppFlowController flow, PathsPresence person) async {
    if (_inviteStatusByUser[person.uid] == 'pending') return;
    if (_wavesLeft <= 0) {
      PremiumSnackBar.show(context, 'Daily waves used up. Come back tomorrow.');
      return;
    }
    setState(() => _inviteStatusByUser[person.uid] = 'pending');
    await _consumeWave();
    try {
      final inviteId = await flow.sendPathsInvite(
        receiverUid: person.uid,
        intent: _selectedActivities.isNotEmpty
            ? _selectedActivities.first
            : (person.intents.isNotEmpty ? person.intents.first : 'connect'),
      );
      if (inviteId.isEmpty) throw Exception('no id');
      _inviteSubs[person.uid]?.cancel();
      _inviteSubs[person.uid] = flow.inviteStatus(inviteId).listen((invite) {
        if (!mounted) return;
        setState(() => _inviteStatusByUser[person.uid] = invite.status);
        if (invite.status == 'accepted' && mounted) {
          PremiumSnackBar.show(context, '🎉 They accepted! Opening chat…', type: SnackBarType.success);
          // Open chat — chatId comes via push notification or we reload chats
          flow.openHome();
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) flow.openTab(1); // Chats tab
          });
        }
      });
      if (mounted) {
        PremiumSnackBar.show(context, 'Wave sent! ${_wavesLeft} left today.', type: SnackBarType.success);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _inviteStatusByUser[person.uid] = 'error');
        PremiumSnackBar.show(context, 'Could not send invite. Please retry.', type: SnackBarType.error);
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

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
            onRefresh: () async => _visible ? _refresh(flow) : null,
            child: CustomScrollView(
              key: const PageStorageKey('pathsScroll'),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  sliver: SliverToBoxAdapter(child: _buildControls(flow)),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: [
                        Text('Nearby', style: FreezmeDesignSystem.h2.copyWith(fontSize: 22)),
                        const Spacer(),
                        if (_visible)
                          IconButton(
                            icon: const Icon(Icons.refresh_rounded, color: FreezmeDesignSystem.primary),
                            onPressed: () => _refresh(flow),
                            tooltip: 'Refresh',
                          ),
                      ],
                    ),
                  ),
                ),
                _buildNearbyContent(flow),
                const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControls(AppFlowController flow) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            const Text('Paths', style: FreezmeDesignSystem.display),
            const Spacer(),
            _WavesPill(wavesLeft: _wavesLeft),
            const SizedBox(width: 8),
            _StatusBadge(visible: _visible, broadcast: _presenceBroadcast),
          ],
        ),
        const SizedBox(height: 16),

        // Activity chips — THE core UX
        _FrostedCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_activity_rounded, size: 16, color: FreezmeDesignSystem.primary),
                  const SizedBox(width: 6),
                  const Text("What are you up for?", style: FreezmeDesignSystem.captionMedium),
                  const Spacer(),
                  if (_selectedActivities.isNotEmpty)
                    GestureDetector(
                      onTap: () { setState(() => _selectedActivities.clear()); },
                      child: const Text('Clear', style: TextStyle(fontSize: 12, color: FreezmeDesignSystem.primary)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _kActivities.map((a) {
                  final selected = _selectedActivities.contains(a.key);
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        selected ? _selectedActivities.remove(a.key) : _selectedActivities.add(a.key);
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: selected
                            ? const LinearGradient(
                                colors: [FreezmeDesignSystem.primary, Color(0xFF7C3AED)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: selected ? null : Colors.white.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected ? FreezmeDesignSystem.primary : FreezmeDesignSystem.border,
                        ),
                        boxShadow: selected
                            ? [BoxShadow(color: FreezmeDesignSystem.primary.withValues(alpha: 0.2), blurRadius: 6)]
                            : null,
                      ),
                      child: Text(
                        a.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : FreezmeDesignSystem.textSecondary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Visibility toggle
        _FrostedCard(
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44, height: 44,
                decoration: BoxDecoration(
                  gradient: _visible
                      ? const LinearGradient(
                          colors: [FreezmeDesignSystem.primary, Color(0xFF7C3AED)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: _visible ? null : FreezmeDesignSystem.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _visible ? Icons.location_on_rounded : Icons.location_off_rounded,
                  color: _visible ? Colors.white : FreezmeDesignSystem.textTertiary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Show me on Paths', style: FreezmeDesignSystem.h3.copyWith(fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(
                      _visible
                          ? (_presenceBroadcast
                              ? 'Live · visible within ${_radius.round()} km'
                              : 'Turning on…')
                          : 'Turn on to discover people nearby',
                      style: FreezmeDesignSystem.caption.copyWith(
                        color: _visible
                            ? FreezmeDesignSystem.success
                            : FreezmeDesignSystem.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _visible,
                activeThumbColor: Colors.white,
                activeTrackColor: FreezmeDesignSystem.primary,
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: FreezmeDesignSystem.border,
                onChanged: (v) {
                  HapticFeedback.mediumImpact();
                  setState(() => _visible = v);
                  if (v) {
                    _broadcastPresence(flow);
                  } else {
                    _stopPresence(flow);
                  }
                },
              ),
            ],
          ),
        ),

        if (_visible) ...[
          const SizedBox(height: 12),
          // Distance
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
                        '${_radius.round()} km',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [1.0, 5.0, 10.0, 25.0, 50.0].map((km) {
                    final active = _radius.round() == km.round();
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _radius = km);
                        _refresh(flow);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: active ? FreezmeDesignSystem.primary : Colors.white.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: active ? FreezmeDesignSystem.primary : FreezmeDesignSystem.border,
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
                    value: _radius,
                    min: 1,
                    max: 50,
                    divisions: 49,
                    onChanged: (v) => setState(() => _radius = v),
                    onChangeEnd: (_) => _refresh(flow),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNearbyContent(AppFlowController flow) {
    if (!_visible) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Padding(
          padding: EdgeInsets.all(32),
          child: EmptyStateView(
            icon: Icons.visibility_off_outlined,
            title: 'You are hidden',
            subtitle: 'Pick an activity above and turn on visibility to see who\'s nearby.',
          ),
        ),
      );
    }
    if (flow.pathsLoading) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: PathsUserSkeleton(),
            ),
            childCount: 4,
          ),
        ),
      );
    }
    if (flow.pathsError != null) {
      if (flow.pathsError!.contains('Location permission denied') || flow.pathsError!.contains('Location services disabled')) {
        return SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: EmptyStateView(
              icon: Icons.location_disabled_rounded,
              title: 'Location Required',
              subtitle: 'Paths needs your location to show nearby people. Please enable it in Settings.',
              actionLabel: 'Open Settings',
              onAction: () => Geolocator.openAppSettings(),
            ),
          ),
        );
      }
      return SliverFillRemaining(
        hasScrollBody: false,
        child: ErrorStateView(message: flow.pathsError!, onRetry: () => _refresh(flow)),
      );
    }
    if (flow.nearbyPaths.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
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
              const SizedBox(height: 24),
              RotationTransition(
                turns: _radarController,
                child: const Icon(Icons.radar_rounded, size: 64, color: FreezmeDesignSystem.primary),
              ),
              const SizedBox(height: 24),
              const Text('Scanning area…', style: FreezmeDesignSystem.h3),
              const SizedBox(height: 8),
              const Text(
                'No one nearby right now.\nTry a wider radius or different activity.',
                textAlign: TextAlign.center,
                style: FreezmeDesignSystem.body,
              ),
            ],
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final person = flow.nearbyPaths[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _NearbyPersonCard(
                person: person,
                inviteStatus: _inviteStatusByUser[person.uid],
                onWave: () => _sendInvite(flow, person),
                onInvite: () {
                  if (_inviteStatusByUser[person.uid] == 'accepted') {
                    flow.openTab(1);
                  } else {
                    _sendInvite(flow, person);
                  }
                },
              ),
            );
          },
          childCount: flow.nearbyPaths.length,
        ),
      ),
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

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
          BoxShadow(color: FreezmeDesignSystem.primary.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: child,
    );
  }
}

class _WavesPill extends StatelessWidget {
  final int wavesLeft;
  const _WavesPill({required this.wavesLeft});
  @override
  Widget build(BuildContext context) {
    return Container(
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
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: FreezmeDesignSystem.primary),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool visible;
  final bool broadcast;
  const _StatusBadge({required this.visible, required this.broadcast});
  @override
  Widget build(BuildContext context) {
    final active = visible && broadcast;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: active ? FreezmeDesignSystem.success.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? FreezmeDesignSystem.success.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(color: active ? FreezmeDesignSystem.success : Colors.grey, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            active ? 'Live' : (visible ? 'Locating…' : 'Hidden'),
            style: TextStyle(
              color: active ? FreezmeDesignSystem.success : Colors.grey,
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
    final name = person.displayName?.isNotEmpty == true ? person.displayName! : 'Nearby person';
    final timeLeft = person.visibleUntil.difference(DateTime.now());
    final expiryLabel = timeLeft.inMinutes > 0
        ? '${timeLeft.inMinutes}m left'
        : 'Expiring soon';

    return _FrostedCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: person.imageUrl != null && person.imageUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: person.imageUrl!,
                    width: 60, height: 60,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _defaultAvatar(),
                  )
                : _defaultAvatar(),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(name, style: FreezmeDesignSystem.h3.copyWith(fontSize: 16), overflow: TextOverflow.ellipsis),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: FreezmeDesignSystem.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        expiryLabel,
                        style: const TextStyle(fontSize: 11, color: FreezmeDesignSystem.primary, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Activity chips
                Wrap(
                  spacing: 6, runSpacing: 4,
                  children: person.intents.map((intent) {
                    final activity = _kActivities.where((a) => a.key == intent.toLowerCase()).firstOrNull;
                    final label = activity != null ? activity.label : intent;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: FreezmeDesignSystem.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(label, style: const TextStyle(fontSize: 12, color: FreezmeDesignSystem.primary, fontWeight: FontWeight.w500)),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                // Actions
                Row(
                  children: [
                    Expanded(
                      child: PremiumButton(
                        label: '👋 Wave',
                        onPressed: inviteStatus != null ? null : onWave,
                        variant: ButtonVariant.outlined,
                        size: ButtonSize.small,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: PremiumButton(
                        label: _inviteLabel(inviteStatus),
                        onPressed: (inviteStatus == 'pending' || inviteStatus == 'declined') ? null : onInvite,
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

  Widget _defaultAvatar() => Container(
    width: 60, height: 60,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [FreezmeDesignSystem.primary, Color(0xFF7C3AED)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(16),
    ),
    child: const Icon(Icons.person, color: Colors.white, size: 30),
  );

  Color _buttonColor(String? status) {
    switch (status) {
      case 'pending': return Colors.grey;
      case 'accepted': return FreezmeDesignSystem.success;
      case 'declined': return FreezmeDesignSystem.error;
      default: return FreezmeDesignSystem.primary;
    }
  }

  String _inviteLabel(String? status) {
    switch (status) {
      case 'pending': return 'Sent…';
      case 'accepted': return '✓ Chat';
      case 'declined': return 'Passed';
      case 'error': return 'Retry';
      default: return 'Invite';
    }
  }
}
