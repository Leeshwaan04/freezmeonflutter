import 'blueprint.dart';
import '../core/app_stage.dart' show LifestyleArchetype;

class VibeProfile {
  const VibeProfile({
    required this.uid,
    this.id,
    required this.name,
    required this.age,
    required this.imageUrl,
    this.photoUrls = const <String>[],
    required this.compatibility,
    this.dna,
    this.interests = const <String>[],
    this.sharedInterests = const <String>[],
    required this.bio,
    this.gender = '',
    required this.distance,
    this.lat,
    this.lng,
    this.geohash,
    this.lastActive,
    this.timezone,
    this.isPremium = false,
    this.isVerified = false,
    this.archetypes = const <LifestyleArchetype>[],
    // Calibration fields
    this.energyType,
    this.paceSignal,
    this.promptAnswer,
    this.presenceLabel,
    this.presenceScore = 50,
    this.intent,
  });

  final String uid;
  final int? id;
  final String name;
  final int age;
  final String imageUrl;
  final List<String> photoUrls;
  final int compatibility;
  final CompatibilityDNA? dna;
  final List<String> interests;
  final List<String> sharedInterests;
  final String bio;
  final String gender;
  final String distance;
  final double? lat;
  final double? lng;
  final String? geohash;
  final DateTime? lastActive;
  final String? timezone;
  final bool isPremium;
  final bool isVerified;
  final List<LifestyleArchetype> archetypes;
  // Calibration fields from algorithm
  final EnergyType? energyType;
  final PaceSignal? paceSignal;
  final PromptAnswer? promptAnswer;
  final PresenceLabel? presenceLabel;
  final int presenceScore;
  final String? intent;

  factory VibeProfile.fromJson(
    Map<String, dynamic> json, {
    String? documentId,
  }) {
    final rawId = json['id'];
    final parsedId = rawId is int
        ? rawId
        : int.tryParse(rawId?.toString() ?? '') ??
              int.tryParse(documentId ?? '') ??
              0;
    final normalizedId = parsedId.clamp(0, 1 << 32).toInt();
    
    // Prisma uses 'userId', older Firestore used 'uid'
    final rawUid = json['uid'] ?? json['userId'];
    final uid = (rawUid is String && rawUid.isNotEmpty)
        ? rawUid
        : (documentId?.isNotEmpty == true
              ? documentId!
              : 'profile_$normalizedId');
              
    final List<dynamic>? rawPhotos = json['photoUrls'] as List<dynamic>?;
    final List<String> normalizedPhotos = rawPhotos != null
        ? rawPhotos
              .whereType<String>()
              .where((url) => url.isNotEmpty)
              .map((url) => url.trim())
              .toList()
        : <String>[];
        
    // Server uses 'imageUrl' as primary
    final String serverImageUrl = json['imageUrl'] as String? ?? '';
    final String fallbackImageUrl = json['photoUrl'] as String? ?? '';
    
    if (normalizedPhotos.isEmpty && serverImageUrl.isNotEmpty) {
      normalizedPhotos.add(serverImageUrl);
    } else if (normalizedPhotos.isEmpty && fallbackImageUrl.isNotEmpty) {
      normalizedPhotos.add(fallbackImageUrl);
    }
    
    final String primaryImage = normalizedPhotos.isNotEmpty
        ? normalizedPhotos.first
        : (serverImageUrl.isNotEmpty ? serverImageUrl : fallbackImageUrl);

    // Parse lastActive as DateTime
    DateTime? lastActive;
    final rawLastActive = json['lastActive'] ?? json['lastActiveAt'] ?? json['updatedAt'];
    if (rawLastActive is String) {
      try {
        lastActive = DateTime.parse(rawLastActive);
      } catch (_) {
        // Invalid date format
      }
    }

    return VibeProfile(
      uid: uid,
      id: normalizedId == 0 ? null : normalizedId,
      name: json['name'] as String? ?? json['displayName'] as String? ?? 'Unknown',
      age: (json['age'] as num?)?.toInt() ?? 0,
      imageUrl: primaryImage,
      photoUrls: List<String>.unmodifiable(normalizedPhotos),
      compatibility: (json['compatibility'] as num?)?.toInt() ?? 0,
      dna: json['dna'] != null ? CompatibilityDNA.fromJson(json['dna']) : null,
      interests: (json['interests'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      sharedInterests: (json['sharedInterests'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      bio: json['bio'] as String? ?? '',
      gender: json['gender'] as String? ?? '',
      distance: json['distance'] as String? ?? '',
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      geohash: json['geohash'] as String?,
      lastActive: lastActive,
      timezone: json['timezone'] as String?,
      isPremium: json['isPremium'] as bool? ?? false,
      isVerified: json['isVerified'] as bool? ?? false,
      energyType: EnergyType.fromString(json['energyType'] as String?),
      paceSignal: PaceSignal.fromString(json['paceSignal'] as String?),
      promptAnswer: json['promptAnswer'] != null
          ? PromptAnswer.fromJson(json['promptAnswer'] as Map<String, dynamic>)
          : null,
      presenceLabel: PresenceLabel.fromString(json['presenceLabel'] as String?),
      presenceScore: (json['presenceScore'] as num?)?.toInt() ?? 50,
      intent: json['intent'] as String?,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'uid': uid,
    'id': id,
    'name': name,
    'age': age,
    'imageUrl': imageUrl,
    'photoUrls': photoUrls,
    'compatibility': compatibility,
    if (dna != null) 'dna': dna!.toJson(),
    'interests': interests,
    'sharedInterests': sharedInterests,
    'bio': bio,
    'gender': gender,
    'distance': distance,
    if (lat != null) 'lat': lat,
    if (lng != null) 'lng': lng,
    if (geohash != null) 'geohash': geohash,
    if (lastActive != null) 'lastActive': lastActive!.toIso8601String(),
    if (timezone != null) 'timezone': timezone,
    'isPremium': isPremium,
    'isVerified': isVerified,
    if (energyType != null) 'energyType': energyType!.name,
    if (paceSignal != null) 'paceSignal': paceSignal!.name,
    if (promptAnswer != null) 'promptAnswer': promptAnswer!.toJson(),
    if (presenceLabel != null) 'presenceLabel': presenceLabel!.name,
    'presenceScore': presenceScore,
    if (intent != null) 'intent': intent,
  };

  VibeProfile copyWith({
    String? uid,
    int? id,
    String? name,
    int? age,
    String? imageUrl,
    List<String>? photoUrls,
    int? compatibility,
    CompatibilityDNA? dna,
    List<String>? interests,
    List<String>? sharedInterests,
    String? bio,
    String? gender,
    String? distance,
    double? lat,
    double? lng,
    String? geohash,
    DateTime? lastActive,
    String? timezone,
    bool? isPremium,
    bool? isVerified,
    List<LifestyleArchetype>? archetypes,
    EnergyType? energyType,
    PaceSignal? paceSignal,
    PromptAnswer? promptAnswer,
    PresenceLabel? presenceLabel,
    int? presenceScore,
    String? intent,
  }) {
    return VibeProfile(
      uid: uid ?? this.uid,
      id: id ?? this.id,
      name: name ?? this.name,
      age: age ?? this.age,
      imageUrl: imageUrl ?? this.imageUrl,
      photoUrls: photoUrls ?? this.photoUrls,
      compatibility: compatibility ?? this.compatibility,
      dna: dna ?? this.dna,
      interests: interests ?? this.interests,
      sharedInterests: sharedInterests ?? this.sharedInterests,
      bio: bio ?? this.bio,
      gender: gender ?? this.gender,
      distance: distance ?? this.distance,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      geohash: geohash ?? this.geohash,
      lastActive: lastActive ?? this.lastActive,
      timezone: timezone ?? this.timezone,
      isPremium: isPremium ?? this.isPremium,
      isVerified: isVerified ?? this.isVerified,
      archetypes: archetypes ?? this.archetypes,
      energyType: energyType ?? this.energyType,
      paceSignal: paceSignal ?? this.paceSignal,
      promptAnswer: promptAnswer ?? this.promptAnswer,
      presenceLabel: presenceLabel ?? this.presenceLabel,
      presenceScore: presenceScore ?? this.presenceScore,
      intent: intent ?? this.intent,
    );
  }
}
