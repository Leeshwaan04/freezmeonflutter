/// Conversation Energy — computed from recent chat signals.
///
/// Signals tracked:
///   - Response speed  (average time between turns, normalised)
///   - Message depth   (average character count, normalised)
///   - Emoji warmth    (emoji density per message)
library;

import '../ui/chat/chat_screen_page.dart' show ChatMessageItem;

enum EnergyLevel { low, medium, high }

class ConversationEnergy {
  const ConversationEnergy({
    required this.level,
    required this.score, // 0–100
  });

  final EnergyLevel level;
  final int score;

  String get label {
    switch (level) {
      case EnergyLevel.low:
        return 'Low Energy';
      case EnergyLevel.medium:
        return 'Good Energy';
      case EnergyLevel.high:
        return 'High Energy';
    }
  }

  /// Colour used for the indicator chip.
  static const _levelColors = {
    EnergyLevel.low: 0xFF9E9E9E,     // grey
    EnergyLevel.medium: 0xFF42A5F5,  // blue
    EnergyLevel.high: 0xFFFF7043,    // deep orange
  };

  int get colorValue => _levelColors[level]!;

  // ─── Factory ──────────────────────────────────────────────────────────────

  /// Compute energy from the last [windowSize] messages in the conversation.
  static ConversationEnergy compute(
    List<ChatMessageItem> messages, {
    int windowSize = 20,
  }) {
    if (messages.isEmpty) {
      return const ConversationEnergy(level: EnergyLevel.low, score: 0);
    }

    final window = messages.length > windowSize
        ? messages.sublist(messages.length - windowSize)
        : messages;

    // 1. Message depth — average character count normalised to [0,1].
    //    A 100+ char message is considered "deep" (score = 1.0).
    final avgLen = window.map((m) => m.text.length).reduce((a, b) => a + b) /
        window.length;
    final depthScore = (avgLen / 100).clamp(0.0, 1.0);

    // 2. Emoji warmth — count unicode emoji characters.
    final emojiRegex = RegExp(
      r'[\u{1F300}-\u{1F9FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]',
      unicode: true,
    );
    final totalEmoji =
        window.fold<int>(0, (sum, m) => sum + emojiRegex.allMatches(m.text).length);
    // Normalise: 0.5+ emoji per message = max warmth
    final warmthScore = (totalEmoji / (window.length * 0.5)).clamp(0.0, 1.0);

    // 3. Alternation — penalise long one-sided runs (one person sending 3+ in a row).
    int longestRun = 1;
    int currentRun = 1;
    for (int i = 1; i < window.length; i++) {
      if (window[i].isMe == window[i - 1].isMe) {
        currentRun++;
        if (currentRun > longestRun) longestRun = currentRun;
      } else {
        currentRun = 1;
      }
    }
    // A run ≥ 4 in a row starts penalising. Score = 1 if no run, 0 if all one-sided.
    final alternationScore = (1 - ((longestRun - 1) / window.length)).clamp(0.0, 1.0);

    // Weighted composite (depth 40%, warmth 30%, alternation 30%)
    final composite = depthScore * 0.4 + warmthScore * 0.3 + alternationScore * 0.3;
    final score = (composite * 100).round();

    final level = score >= 65
        ? EnergyLevel.high
        : score >= 35
            ? EnergyLevel.medium
            : EnergyLevel.low;

    return ConversationEnergy(level: level, score: score);
  }
}
