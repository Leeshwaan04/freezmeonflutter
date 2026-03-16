import '../models/blueprint.dart';

enum PersonalityArchetype {
  explorer,
  nurturer,
  visionary,
  harmonizer,
  dynamo;

  String get label {
    switch (this) {
      case explorer: return "The Explorer";
      case nurturer: return "The Nurturer";
      case visionary: return "The Visionary";
      case harmonizer: return "The Harmonizer";
      case dynamo: return "The Dynamo";
    }
  }

  String get description {
    switch (this) {
      case explorer: return "You enjoy new experiences, travel, and deep conversations. You match best with curious and adventurous people.";
      case nurturer: return "You value deep emotional connections and taking care of others. Stable and loyal partner.";
      case visionary: return "You are creative and always looking at the big picture. You need someone who appreciates your ideas.";
      case harmonizer: return "You seek balance and peace in relationships. You are the glue that holds things together.";
      case dynamo: return "You are high-energy and achievement-oriented. You need a partner who can keep up with your pace.";
    }
  }
}

class ArchetypeService {
  static PersonalityArchetype determine(List<PersonalityTrait> traits) {
    if (traits.contains(PersonalityTrait.adventurous)) return PersonalityArchetype.explorer;
    if (traits.contains(PersonalityTrait.spontaneous)) return PersonalityArchetype.visionary;
    if (traits.contains(PersonalityTrait.extrovert)) return PersonalityArchetype.dynamo;
    if (traits.contains(PersonalityTrait.emotional)) return PersonalityArchetype.nurturer;
    
    return PersonalityArchetype.harmonizer; // Default
  }
}
