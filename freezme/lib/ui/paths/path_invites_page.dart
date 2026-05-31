import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../main.dart';
import '../../models/paths.dart';
import '../design_system.dart';
import '../shared/humanize_error.dart';
import '../components/premium_components.dart';
import '../components/skeleton_loaders.dart';

class PathInvitesPage extends StatefulWidget {
  const PathInvitesPage({super.key});

  @override
  State<PathInvitesPage> createState() => _PathInvitesPageState();
}

class _PathInvitesPageState extends State<PathInvitesPage> {
  List<PathsInvite> _invites = [];
  bool _loading = true;
  String? _error;
  final Set<String> _processing = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final flow = AppFlowScope.of(context, listen: false);
      final invites = await flow.repository.fetchPendingPathsInvites();
      if (mounted) setState(() { _invites = invites; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = humanizeError(e); _loading = false; });
    }
  }

  Future<void> _respond(PathsInvite invite, String status) async {
    if (_processing.contains(invite.id)) return;
    setState(() => _processing.add(invite.id));
    try {
      final flow = AppFlowScope.of(context, listen: false);
      if (status == 'cancelled') {
        await flow.repository.cancelPathsInvite(invite.id);
      } else {
        // Use dynamic dispatch to call respondPathsInvite on the EC2 repo
        await (flow.repository as dynamic).respondPathsInvite(invite.id, status);
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _processing.remove(invite.id);
      _invites.removeWhere((i) => i.id == invite.id);
    });

    if (status == 'accepted') {
      PremiumSnackBar.show(context, "You're in! Check your chats.", type: SnackBarType.success);
      // Navigate to chats tab
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          AppFlowScope.of(context, listen: false).openTab(1);
          Navigator.of(context).pop();
        }
      });
    } else {
      PremiumSnackBar.show(context, 'Invite declined.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FreezmeDesignSystem.background,
      appBar: AppBar(
        title: const Text('Path Invites', style: FreezmeDesignSystem.h3),
        backgroundColor: FreezmeDesignSystem.background,
        iconTheme: const IconThemeData(color: FreezmeDesignSystem.primary),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const ChatListSkeleton(itemCount: 4)
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: FreezmeDesignSystem.error),
                      const SizedBox(height: 12),
                      Text('Failed to load invites', style: FreezmeDesignSystem.body),
                      const SizedBox(height: 8),
                      PremiumButton(label: 'Retry', onPressed: _load, size: ButtonSize.small),
                    ],
                  ),
                )
              : _invites.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.route_outlined, size: 64, color: FreezmeDesignSystem.textTertiary),
                          const SizedBox(height: 16),
                          Text('No pending invites', style: FreezmeDesignSystem.body.copyWith(color: FreezmeDesignSystem.textSecondary)),
                          const SizedBox(height: 8),
                          const Text(
                            'When someone crosses your path and sends\nan invite, it will appear here.',
                            textAlign: TextAlign.center,
                            style: FreezmeDesignSystem.caption,
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: FreezmeDesignSystem.primary,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _invites.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final invite = _invites[index];
                          final isProcessing = _processing.contains(invite.id);
                          return _InviteCard(
                            invite: invite,
                            isProcessing: isProcessing,
                            onAccept: () => _respond(invite, 'accepted'),
                            onDecline: () => _respond(invite, 'declined'),
                          );
                        },
                      ),
                    ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  final PathsInvite invite;
  final bool isProcessing;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _InviteCard({
    required this.invite,
    required this.isProcessing,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    // Find emoji for intent
    const activities = [
      (emoji: '🎉', key: 'party'),   (emoji: '🏋️', key: 'gym'),
      (emoji: '🚴', key: 'cycling'), (emoji: '☕', key: 'coffee'),
      (emoji: '🥾', key: 'hiking'),  (emoji: '📚', key: 'study'),
      (emoji: '🍕', key: 'food'),    (emoji: '🎮', key: 'gaming'),
      (emoji: '🎵', key: 'music'),   (emoji: '🏃', key: 'running'),
      (emoji: '🧘', key: 'yoga'),    (emoji: '🤝', key: 'connect'),
    ];
    final matched = activities.where((a) => a.key == invite.intent.toLowerCase()).firstOrNull;
    final intentEmoji = matched?.emoji ?? '📍';
    final intentLabel = invite.intent.isEmpty ? 'Activity' : invite.intent;

    return Container(
      decoration: BoxDecoration(
        color: FreezmeDesignSystem.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FreezmeDesignSystem.border),
        boxShadow: [
          BoxShadow(color: FreezmeDesignSystem.primary.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: FreezmeDesignSystem.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(child: Text(intentEmoji, style: const TextStyle(fontSize: 22))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Someone wants to $intentLabel with you',
                        style: FreezmeDesignSystem.bodyMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        timeago.format(invite.createdAt),
                        style: FreezmeDesignSystem.caption,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (isProcessing)
              const Center(child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: CircularProgressIndicator(color: FreezmeDesignSystem.primary),
              ))
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onDecline,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: FreezmeDesignSystem.error,
                        side: const BorderSide(color: FreezmeDesignSystem.error),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onAccept,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FreezmeDesignSystem.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Accept 🎉'),
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
