import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/api_client.dart';
import '../theme.dart';

class PathInvitesPage extends StatelessWidget {
  const PathInvitesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = AuthService.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Path Invites'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: FreezmeGradients.backgroundSoft,
        ),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchPendingInvites(currentUser.uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final invites = snapshot.data ?? [];

            if (invites.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.route_outlined, size: 64, color: FreezmeColors.muted),
                    SizedBox(height: 16),
                    Text('No pending invites', style: FreezmeTypography.bodyMuted),
                  ],
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: invites.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final invite = invites[index];
                final inviteId = invite['id'] as String? ?? '';

                return _PathInviteCard(
                  inviteId: inviteId,
                  pathName: invite['path_name'] as String? ?? 'Unknown Path',
                  senderName: invite['sender_name'] as String? ?? 'Someone',
                  activity: invite['activity'] as String? ?? 'Activity',
                  time: invite['time'] as String? ?? 'Tonight',
                  onAccept: () => _acceptInvite(context, inviteId),
                  onDecline: () => _declineInvite(context, inviteId),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchPendingInvites(String uid) async {
    try {
      final response = await ApiClient.instance.dio
          .get<List<dynamic>>('/paths/invites', queryParameters: {'status': 'pending'});
      return (response.data ?? []).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<void> _acceptInvite(BuildContext context, String inviteId) async {
    try {
      await ApiClient.instance.dio.post<void>(
        '/paths/invite/$inviteId/respond',
        data: {'status': 'accepted'},
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invite accepted! You're in.")),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _declineInvite(BuildContext context, String inviteId) async {
    try {
      await ApiClient.instance.dio.post<void>(
        '/paths/invite/$inviteId/respond',
        data: {'status': 'declined'},
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invite declined')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}

class _PathInviteCard extends StatelessWidget {
  final String inviteId;
  final String pathName;
  final String senderName;
  final String activity;
  final String time;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _PathInviteCard({
    required this.inviteId,
    required this.pathName,
    required this.senderName,
    required this.activity,
    required this.time,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: FreezmeColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.route, color: FreezmeColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pathName, style: FreezmeTypography.title),
                      Text('$senderName invited you', style: FreezmeTypography.bodyMuted),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _InfoChip(icon: Icons.local_activity, label: activity),
                const SizedBox(width: 8),
                _InfoChip(icon: Icons.access_time, label: time),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDecline,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: FreezmeColors.error,
                      side: const BorderSide(color: FreezmeColors.error),
                    ),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onAccept,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FreezmeColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Accept'),
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

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: FreezmeColors.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: FreezmeColors.neutral),
          const SizedBox(width: 4),
          Text(label, style: FreezmeTypography.caption),
        ],
      ),
    );
  }
}
