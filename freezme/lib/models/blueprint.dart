enum DatingIntent {
  meaningful,
  exploring,
  friendship,
}

enum PersonalityTrait {
  introvert,
  extrovert,
  adventurous,
  cautious,
  logical,
  emotional,
  spontaneous,
  planner,
}

enum LifestyleFactor {
  fitness,
  travel,
  career,
  creative,
  spiritual,
}

class CompatibilityDNA {
  const CompatibilityDNA({
    required this.overall,
    required this.lifestyle,
    required this.personality,
    required this.communication,
    required this.values,
  });

  final int overall;
  final int lifestyle;
  final int personality;
  final int communication;
  final int values;

  factory CompatibilityDNA.fromJson(Map<String, dynamic> json) {
    return CompatibilityDNA(
      overall: json['overall'] ?? 0,
      lifestyle: json['lifestyle'] ?? 0,
      personality: json['personality'] ?? 0,
      communication: json['communication'] ?? 0,
      values: json['values'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'overall': overall,
    'lifestyle': lifestyle,
    'personality': personality,
    'communication': communication,
    'values': values,
  };
}

class UserBlueprint {
  const UserBlueprint({
    required this.intent,
    required this.personalityTraits,
    required this.lifestyleFactors,
    this.voiceIntroUrl,
    this.trustScore = 100,
    this.dna,
  });

  final DatingIntent intent;
  final List<PersonalityTrait> personalityTraits;
  final List<LifestyleFactor> lifestyleFactors;
  final String? voiceIntroUrl;
  final int trustScore;
  final CompatibilityDNA? dna;

  factory UserBlueprint.fromJson(Map<String, dynamic> json) {
    return UserBlueprint(
      intent: DatingIntent.values.firstWhere((e) => e.name == json['intent'], orElse: () => DatingIntent.meaningful),
      personalityTraits: (json['personalityTraits'] as List?)?.map((e) => PersonalityTrait.values.firstWhere((v) => v.name == e)).toList() ?? [],
      lifestyleFactors: (json['lifestyleFactors'] as List?)?.map((e) => LifestyleFactor.values.firstWhere((v) => v.name == e)).toList() ?? [],
      voiceIntroUrl: json['voiceIntroUrl'],
      trustScore: json['trustScore'] ?? 100,
      dna: json['dna'] != null ? CompatibilityDNA.fromJson(json['dna']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'intent': intent.name,
    'personalityTraits': personalityTraits.map((e) => e.name).toList(),
    'lifestyleFactors': lifestyleFactors.map((e) => e.name).toList(),
    'voiceIntroUrl': voiceIntroUrl,
    'trustScore': trustScore,
    'dna': dna?.toJson(),
  };
}
