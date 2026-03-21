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

enum TrustTier {
  basic,
  trusted,
  verified,
  elite,
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
    this.personalityTraits,
    this.lifestyleFactors,
    this.highlights,
  });

  final int overall;
  final int lifestyle;
  final int personality;
  final int communication;
  final int values;
  final List<String>? personalityTraits;
  final List<String>? lifestyleFactors;
  final List<String>? highlights;

  factory CompatibilityDNA.fromJson(Map<String, dynamic> json) {
    return CompatibilityDNA(
      overall: json['overall'] ?? 0,
      lifestyle: json['lifestyle'] ?? 0,
      personality: json['personality'] ?? 0,
      communication: json['communication'] ?? 0,
      values: json['values'] ?? 0,
      personalityTraits: (json['personalityTraits'] as List?)?.cast<String>(),
      lifestyleFactors: (json['lifestyleFactors'] as List?)?.cast<String>(),
      highlights: (json['highlights'] as List?)?.cast<String>(),
    );
  }

  Map<String, dynamic> toJson() => {
    'overall': overall,
    'lifestyle': lifestyle,
    'personality': personality,
    'communication': communication,
    'values': values,
    if (personalityTraits != null) 'personalityTraits': personalityTraits,
    if (lifestyleFactors != null) 'lifestyleFactors': lifestyleFactors,
    if (highlights != null) 'highlights': highlights,
  };
}

class UserBlueprint {
  const UserBlueprint({
    required this.intent,
    required this.personalityTraits,
    required this.lifestyleFactors,
    this.voiceIntroUrl,
    this.trustScore = 150,
    this.dna,
    this.voiceEnergy,
    this.voiceWarmth,
  });

  final DatingIntent intent;
  final List<PersonalityTrait> personalityTraits;
  final List<LifestyleFactor> lifestyleFactors;
  final String? voiceIntroUrl;
  final int trustScore;
  final CompatibilityDNA? dna;
  final double? voiceEnergy; // 0.0 to 1.0
  final double? voiceWarmth; // 0.0 to 1.0

  TrustTier get trustTier {
    if (trustScore >= 260) return TrustTier.elite;
    if (trustScore >= 220) return TrustTier.verified;
    if (trustScore >= 180) return TrustTier.trusted;
    return TrustTier.basic;
  }

  factory UserBlueprint.fromJson(Map<String, dynamic> json) {
    return UserBlueprint(
      intent: DatingIntent.values.firstWhere((e) => e.name == json['intent'], orElse: () => DatingIntent.meaningful),
      personalityTraits: (json['personalityTraits'] as List?)?.map((e) => PersonalityTrait.values.firstWhere((v) => v.name == e)).toList() ?? [],
      lifestyleFactors: (json['lifestyleFactors'] as List?)?.map((e) => LifestyleFactor.values.firstWhere((v) => v.name == e)).toList() ?? [],
      voiceIntroUrl: json['voiceIntroUrl'],
      trustScore: json['trustScore'] ?? 150,
      dna: json['dna'] != null ? CompatibilityDNA.fromJson(json['dna']) : null,
      voiceEnergy: json['voiceEnergy']?.toDouble(),
      voiceWarmth: json['voiceWarmth']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'intent': intent.name,
    'personalityTraits': personalityTraits.map((e) => e.name).toList(),
    'lifestyleFactors': lifestyleFactors.map((e) => e.name).toList(),
    'voiceIntroUrl': voiceIntroUrl,
    'trustScore': trustScore,
    'dna': dna?.toJson(),
    'voiceEnergy': voiceEnergy,
    'voiceWarmth': voiceWarmth,
  };
}
