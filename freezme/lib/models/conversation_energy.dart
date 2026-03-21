/// Conversation Energy — computed from recent chat signals.
///
/// Signals tracked:
///   - Message depth     (average character count, normalised)
///   - Emoji warmth      (emoji density per message)
///   - Alternation       (penalises one-sided runs)
///   - Reciprocity       (how balanced the message counts are)
library;

import '../ui/chat/chat_screen_page.dart' show ChatMessageItem;

enum EnergyLevel { low, medium, high }

/// Stage of the conversation, used to select adaptive prompts.
enum ConversationStage { early, mid, late }

class ConversationEnergy {
  const ConversationEnergy({
    required this.level,
    required this.score, // 0–100 composite
    this.depthScore = 0,
    this.warmthScore = 0,
    this.alternationScore = 0,
    this.reciprocityScore = 0,
  });

  final EnergyLevel level;
  final int score;

  /// Sub-scores exposed for the health dashboard (0–100 each).
  final int depthScore;
  final int warmthScore;
  final int alternationScore;
  final int reciprocityScore;

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

  /// Human-readable energy summary for the health dashboard.
  String get healthSummary {
    switch (level) {
      case EnergyLevel.low:
        return 'The conversation needs a nudge — try sharing something personal.';
      case EnergyLevel.medium:
        return 'Good momentum. Keep the back-and-forth going.';
      case EnergyLevel.high:
        return 'Great chemistry! You\'re both fully engaged.';
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
    final avgLen = window.map((m) => m.text.length).reduce((a, b) => a + b) /
        window.length;
    final depth = (avgLen / 100).clamp(0.0, 1.0);

    // 2. Emoji warmth — count unicode emoji characters.
    final emojiRegex = RegExp(
      r'[\u{1F300}-\u{1F9FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]',
      unicode: true,
    );
    final totalEmoji =
        window.fold<int>(0, (sum, m) => sum + emojiRegex.allMatches(m.text).length);
    final warmth = (totalEmoji / (window.length * 0.5)).clamp(0.0, 1.0);

    // 3. Alternation — penalise long one-sided runs.
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
    final alternation = (1 - ((longestRun - 1) / window.length)).clamp(0.0, 1.0);

    // 4. Reciprocity — how balanced the message counts are (0 = all one-side, 1 = 50/50).
    final myCount = window.where((m) => m.isMe).length;
    final theirCount = window.length - myCount;
    final majority = myCount > theirCount ? myCount : theirCount;
    final reciprocity = window.length > 1
        ? (1 - ((majority - theirCount.toDouble().abs()) / window.length)).clamp(0.0, 1.0)
        : 0.5;

    // Weighted composite (depth 35%, warmth 25%, alternation 25%, reciprocity 15%)
    final composite = depth * 0.35 + warmth * 0.25 + alternation * 0.25 + reciprocity * 0.15;
    final score = (composite * 100).round();

    final level = score >= 65
        ? EnergyLevel.high
        : score >= 35
            ? EnergyLevel.medium
            : EnergyLevel.low;

    return ConversationEnergy(
      level: level,
      score: score,
      depthScore: (depth * 100).round(),
      warmthScore: (warmth * 100).round(),
      alternationScore: (alternation * 100).round(),
      reciprocityScore: (reciprocity * 100).round(),
    );
  }

  // ─── Stage Helper ─────────────────────────────────────────────────────────

  static ConversationStage stageFor(int messageCount) {
    if (messageCount < 3) return ConversationStage.early;
    if (messageCount < 9) return ConversationStage.mid;
    return ConversationStage.late;
  }
}
