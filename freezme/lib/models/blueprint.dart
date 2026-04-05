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

/// Derived from forced-choice calibration pairs — not self-reported
enum EnergyType {
  deepDiver,    // reflective, prefers depth, slower to open up
  roomIgniter,  // outgoing, high social energy, energised by people
  quietStorm,   // calm exterior, strong interior world
  openRoad;     // spontaneous, adventurous, always moving

  String get label {
    switch (this) {
      case deepDiver:    return 'Deep Diver';
      case roomIgniter:  return 'Room Igniter';
      case quietStorm:   return 'Quiet Storm';
      case openRoad:     return 'Open Road';
    }
  }

  String get description {
    switch (this) {
      case deepDiver:    return 'You go deep fast. One real conversation beats ten surface ones.';
      case roomIgniter:  return 'You walk in and the energy shifts. People remember you.';
      case quietStorm:   return 'Still on the outside, turbulent on the inside. Worth knowing.';
      case openRoad:     return 'Plans are suggestions. You go where the moment takes you.';
    }
  }

  String get emoji {
    switch (this) {
      case deepDiver:    return '🌊';
      case roomIgniter:  return '🔥';
      case quietStorm:   return '🌙';
      case openRoad:     return '🗺️';
    }
  }

  static EnergyType? fromString(String? s) {
    if (s == null) return null;
    return EnergyType.values.firstWhere(
      (e) => e.name == s || e.name == s.replaceAll('_', ''),
      orElse: () => EnergyType.deepDiver,
    );
  }
}

enum PaceSignal {
  takesTheirTime,
  movesWithInterest,
  quickConnector;

  String get label {
    switch (this) {
      case takesTheirTime:     return 'Takes their time';
      case movesWithInterest:  return 'Moves with interest';
      case quickConnector:     return 'Quick connector';
    }
  }

  static PaceSignal? fromString(String? s) {
    if (s == null) return null;
    return PaceSignal.values.firstWhere(
      (e) => e.name == s || e.name == s.replaceAll('_', ''),
      orElse: () => PaceSignal.movesWithInterest,
    );
  }
}

enum PresenceLabel {
  inTheFire,
  inTheFlow,
  inTheQuiet,
  frozen;

  String get label {
    switch (this) {
      case inTheFire:   return 'In the fire';
      case inTheFlow:   return 'In the flow';
      case inTheQuiet:  return 'In the quiet';
      case frozen:      return 'Frozen';
    }
  }

  String get emoji {
    switch (this) {
      case inTheFire:   return '🔥';
      case inTheFlow:   return '🌊';
      case inTheQuiet:  return '🌙';
      case frozen:      return '❄️';
    }
  }

  static PresenceLabel fromString(String? s) {
    switch (s) {
      case 'in_the_fire':   return PresenceLabel.inTheFire;
      case 'in_the_flow':   return PresenceLabel.inTheFlow;
      case 'in_the_quiet':  return PresenceLabel.inTheQuiet;
      case 'frozen':        return PresenceLabel.frozen;
      default:              return PresenceLabel.inTheFlow;
    }
  }
}

/// Calibration forced-choice pair — shown during onboarding
class CalibrationChoice {
  const CalibrationChoice({
    required this.optionA,
    required this.optionB,
    required this.dimension,
  });
  final String optionA;
  final String optionB;
  final String dimension; // used to compute energyType
}

const kCalibrationPairs = [
  CalibrationChoice(
    optionA: 'A quiet rooftop, city lights, one person, deep conversation till 3am',
    optionB: 'A house full of strangers, music, energy, dancing till 3am',
    dimension: 'social_energy',
  ),
  CalibrationChoice(
    optionA: 'Plans ahead — knows what the weekend looks like by Wednesday',
    optionB: 'Goes with the flow — the best things happen spontaneously',
    dimension: 'structure',
  ),
  CalibrationChoice(
    optionA: 'Needs time alone to recharge after people',
    optionB: 'Feels more energised after being around people',
    dimension: 'recharge',
  ),
  CalibrationChoice(
    optionA: 'Head-driven — logic first, feelings second',
    optionB: 'Heart-driven — feelings first, then reasons',
    dimension: 'decision_style',
  ),
];

/// A Saturday scenario — one choice reveals 3 signals at once
const kSaturdayScenarios = [
  'Morning run, good coffee, a long podcast',
  'Brunch with friends, farmers market, lazy afternoon',
  'Home, cooking something new, movie night',
  'Spontaneous road trip — destination decided at the petrol station',
];

class PromptAnswer {
  const PromptAnswer({required this.prompt, required this.answer});
  final String prompt;
  final String answer;

  factory PromptAnswer.fromJson(Map<String, dynamic> json) => PromptAnswer(
    prompt: json['prompt'] as String? ?? '',
    answer: json['answer'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {'prompt': prompt, 'answer': answer};
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
    this.archetype,
    this.energyType,
    this.paceSignal,
    this.promptAnswer,
    this.presenceWindows = const [],
    this.voiceIntroUrl,
    this.trustScore = 150,
    this.dna,
    this.voiceEnergy,
    this.voiceWarmth,
  });

  final DatingIntent intent;
  final List<PersonalityTrait> personalityTraits;
  final List<LifestyleFactor> lifestyleFactors;
  final String? archetype;
  final EnergyType? energyType;
  final PaceSignal? paceSignal;
  final PromptAnswer? promptAnswer;
  final List<Map<String, dynamic>> presenceWindows;
  final String? voiceIntroUrl;
  final int trustScore;
  final CompatibilityDNA? dna;
  final double? voiceEnergy;
  final double? voiceWarmth;

  TrustTier get trustTier {
    if (trustScore >= 260) return TrustTier.elite;
    if (trustScore >= 220) return TrustTier.verified;
    if (trustScore >= 180) return TrustTier.trusted;
    return TrustTier.basic;
  }

  factory UserBlueprint.fromJson(Map<String, dynamic> json) {
    return UserBlueprint(
      intent: DatingIntent.values.firstWhere(
        (e) => e.name == json['intent'],
        orElse: () => DatingIntent.meaningful,
      ),
      personalityTraits: (json['personalityTraits'] as List?)
          ?.map((e) => PersonalityTrait.values.firstWhere((v) => v.name == e,
              orElse: () => PersonalityTrait.introvert))
          .toList() ?? [],
      lifestyleFactors: (json['lifestyleFactors'] as List?)
          ?.map((e) => LifestyleFactor.values.firstWhere((v) => v.name == e,
              orElse: () => LifestyleFactor.creative))
          .toList() ?? [],
      archetype: json['archetype'] as String?,
      energyType: EnergyType.fromString(json['energyType'] as String?),
      paceSignal: PaceSignal.fromString(json['paceSignal'] as String?),
      promptAnswer: json['promptAnswer'] != null
          ? PromptAnswer.fromJson(json['promptAnswer'] as Map<String, dynamic>)
          : null,
      presenceWindows: (json['presenceWindows'] as List?)
          ?.cast<Map<String, dynamic>>() ?? [],
      voiceIntroUrl: json['voiceIntroUrl'] as String?,
      trustScore: json['trustScore'] as int? ?? 150,
      dna: json['dna'] != null ? CompatibilityDNA.fromJson(json['dna']) : null,
      voiceEnergy: (json['voiceEnergy'] as num?)?.toDouble(),
      voiceWarmth: (json['voiceWarmth'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'intent': intent.name,
    'personalityTraits': personalityTraits.map((e) => e.name).toList(),
    'lifestyleFactors': lifestyleFactors.map((e) => e.name).toList(),
    if (archetype != null) 'archetype': archetype,
    if (energyType != null) 'energyType': energyType!.name,
    if (paceSignal != null) 'paceSignal': paceSignal!.name,
    if (promptAnswer != null) 'promptAnswer': promptAnswer!.toJson(),
    'presenceWindows': presenceWindows,
    if (voiceIntroUrl != null) 'voiceIntroUrl': voiceIntroUrl,
    'trustScore': trustScore,
    if (dna != null) 'dna': dna!.toJson(),
    if (voiceEnergy != null) 'voiceEnergy': voiceEnergy,
    if (voiceWarmth != null) 'voiceWarmth': voiceWarmth,
  };
}
