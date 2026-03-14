import '../core/app_stage.dart';

class VibeProfile {
  const VibeProfile({
    required this.id,
    required this.name,
    required this.age,
    required this.imageUrl,
    required this.compatibility,
    required this.bio,
    required this.distance,
    this.archetypes = const [],
  });

  final int id;
  final String name;
  final int age;
  final String imageUrl;
  final int compatibility;
  final String bio;
  final String distance;
  final List<LifestyleArchetype> archetypes;
}

class AppMatch {
  const AppMatch({
    required this.profile,
    required this.matchedAt,
    this.scheduledSlot,
  });

  final VibeProfile profile;
  final DateTime matchedAt;
  final String? scheduledSlot;
}

class VibeCircle {
  const VibeCircle({
    required this.id,
    required this.name,
    required this.archetype,
    this.members = const [],
    required this.createdAt,
  });

  final String id;
  final String name;
  final LifestyleArchetype archetype;
  final List<VibeProfile> members;
  final DateTime createdAt;
}
