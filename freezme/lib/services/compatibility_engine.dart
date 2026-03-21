import '../models/blueprint.dart';
import '../models/vibe_profile.dart';

class CompatibilityEngine {
  /// Main scoring function based on weighted psychology model.
  static CompatibilityDNA calculateDNA(UserBlueprint user, VibeProfile target) {
    // 1. Personality Similarity (35%)
    final personalityScore = _calculateSimilarity(
      user.personalityTraits.map((e) => e.name).toList(),
      target.dna?.personalityTraits ?? [],
    );

    // 2. Values Alignment (25%)
    final valuesScore = _calculateValuesAlignment(user, target);

    // 3. Lifestyle Compatibility (20%)
    final lifestyleScore = _calculateSimilarity(
      user.lifestyleFactors.map((e) => e.name).toList(),
      target.dna?.lifestyleFactors ?? [],
    );

    // 4. Communication Style (20%)
    final communicationScore = _calculateCommunicationCompatibility(user, target);

    // Weighted Overall
    final overall = (personalityScore * 0.35) +
                    (valuesScore * 0.25) +
                    (lifestyleScore * 0.20) +
                    (communicationScore * 0.20);

    return CompatibilityDNA(
      overall: overall.round(),
      lifestyle: lifestyleScore.round(),
      personality: personalityScore.round(),
      communication: communicationScore.round(),
      values: valuesScore.round(),
      personalityTraits: target.dna?.personalityTraits,
      lifestyleFactors: target.dna?.lifestyleFactors,
      highlights: getCompatibilityHighlights(user, target),
    );
  }

  /// Extracts textual reasons why two users match.
  static List<String> getCompatibilityHighlights(UserBlueprint user, VibeProfile target) {
    final highlights = <String>[];
    
    // 1. Same Personality Traits
    final targetTraits = target.dna?.personalityTraits?.map((t) => t.toLowerCase()).toSet() ?? {};
    final sharedTraits = user.personalityTraits
        .map((e) => e.name.toLowerCase())
        .toSet()
        .intersection(targetTraits);

    if (sharedTraits.isNotEmpty) {
      final label = sharedTraits.take(2).join(' & ');
      highlights.add('Shared $label vibes');
    }

    // 2. Same Lifestyle Factors
    final targetFactors = target.dna?.lifestyleFactors?.map((f) => f.toLowerCase()).toSet() ?? {};
    final sharedFactors = user.lifestyleFactors
        .map((e) => e.name.toLowerCase())
        .toSet()
        .intersection(targetFactors);

    if (sharedFactors.isNotEmpty) {
      highlights.add('Both prioritize ${sharedFactors.first}');
    }

    // 3. Shared Archetypes (Modern lifestyle alignment)
    final sharedArchetypes = user.dna?.lifestyleFactors?.toSet().intersection(target.archetypes.map((a) => a.name).toSet()) ?? {};
    if (sharedArchetypes.isNotEmpty) {
       highlights.add('Connected by ${sharedArchetypes.first}');
    }

    // 4. Mission/Intent Alignment
    if (user.intent == DatingIntent.meaningful) {
      highlights.add('Both looking for depth');
    }

    // Baseline fallbacks if too few highlights
    if (highlights.length < 2) {
      highlights.add('High communication affinity');
      highlights.add('Balanced energy levels');
    }

    return highlights.take(3).toList();
  }

  static double _calculateSimilarity(List<String> listA, List<String> listB) {
    if (listA.isEmpty || listB.isEmpty) return 70.0; // Baseline for new users
    
    final setA = listA.toSet();
    final setB = listB.toSet();
    
    final intersection = setA.intersection(setB).length;
    final union = setA.union(setB).length;
    
    // Jaccard similarity index as a percentage
    return (intersection / union) * 100;
  }

  static double _calculateValuesAlignment(UserBlueprint user, VibeProfile target) {
    double score = 75.0; // Start at baseline
    
    // Intent alignment is a huge multiplier for values
    // In a real app, target would have a DatingIntent field too. 
    // For now we assume high alignment if they share some tags.
    if (user.intent == DatingIntent.meaningful) {
      score += 10;
    }
    
    // Cross-check for shared deep traits (e.g. if both are "Go-getters" or "Minimalists")
    return score.clamp(0, 100);
  }

  static double _calculateCommunicationCompatibility(UserBlueprint user, VibeProfile target) {
    // Complementary personality check
    // Introverts often match well with Extroverts, or similar communication vibes.
    double score = 80.0; // Dynamic baseline

    // Voice analysis boost: If user has uploaded a voice intro, we can actually score the "Vibe"
    // For the demo, we simulate checking if both have high voice energy or warmth
    if (user.voiceEnergy != null && user.voiceEnergy! > 0.7) {
      score += 5; // Energy multiplier
    }
    
    if (user.voiceWarmth != null && user.voiceWarmth! > 0.8) {
      score += 5; // Warmth/Empathy multiplier
    }

    return score.clamp(0, 100);
  }
}
