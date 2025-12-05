import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme.dart';
import '../../main.dart';

class PathInvitesPage extends StatelessWidget {
  const PathInvitesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
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
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('path_invites')
              .where('receiver_uid', isEqualTo: currentUser.uid)
              .where('status', isEqualTo: 'pending')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final invites = snapshot.data?.docs ?? [];

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
                final invite = invites[index].data() as Map<String, dynamic>;
                final inviteId = invites[index].id;

                return _PathInviteCard(
                  inviteId: inviteId,
                  pathName: invite['path_name'] ?? 'Unknown Path',
                  senderName: invite['sender_name'] ?? 'Someone',
                  activity: invite['activity'] ?? 'Activity',
                  time: invite['time'] ?? 'Tonight',
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

  Future<void> _acceptInvite(BuildContext context, String inviteId) async {
    try {
      final inviteRef = FirebaseFirestore.instance.collection('path_invites').doc(inviteId);
      final inviteDoc = await inviteRef.get();
      final inviteData = inviteDoc.data()!;

      // Update invite status
      await inviteRef.update({
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      // Add user to path participants
      final pathId = inviteData['path_id'];
      final currentUid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance.collection('paths').doc(pathId).update({
        'participants': FieldValue.arrayUnion([currentUid]),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invite accepted! You\'re in.')),
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
      await FirebaseFirestore.instance
          .collection('path_invites')
          .doc(inviteId)
          .update({'status': 'declined'});

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
                    color: FreezmeColors.primary.withOpacity(0.1),
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
