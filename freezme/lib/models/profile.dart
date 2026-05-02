import 'vibe_profile.dart';

class AppMatch {
  const AppMatch({
    required this.profile,
    required this.matchedAt,
    required this.expiresAt,
    this.scheduledSlot,
    this.hasConversationStarted = false,
  });

  final VibeProfile profile;
  final DateTime matchedAt;
  final DateTime expiresAt;
  final String? scheduledSlot;
  final bool hasConversationStarted;

  bool get isExpired => !hasConversationStarted && DateTime.now().isAfter(expiresAt);
  
  Duration get remainingTime => expiresAt.difference(DateTime.now());
}

