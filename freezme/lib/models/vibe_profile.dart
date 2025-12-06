class VibeProfile {
  const VibeProfile({
    required this.uid,
    this.id,
    required this.name,
    required this.age,
    required this.imageUrl,
    this.photoUrls = const <String>[],
    required this.compatibility,
    required this.bio,
    required this.distance,
    this.lat,
    this.lng,
    this.geohash,
    this.lastActive,
    this.timezone,
  });

  final String uid;
  final int? id;
  final String name;
  final int age;
  final String imageUrl;
  final List<String> photoUrls;
  final int compatibility;
  final String bio;
  final String distance;
  final double? lat;
  final double? lng;
  final String? geohash;
  final DateTime? lastActive;
  final String? timezone;

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
    final rawUid = json['uid'];
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
    final String fallbackImageUrl = json['imageUrl'] as String? ?? '';
    if (normalizedPhotos.isEmpty && fallbackImageUrl.isNotEmpty) {
      normalizedPhotos.add(fallbackImageUrl);
    }
    final String primaryImage = normalizedPhotos.isNotEmpty
        ? normalizedPhotos.first
        : fallbackImageUrl;

    // Parse lastActive as DateTime
    DateTime? lastActive;
    final rawLastActive = json['lastActive'];
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
      name: json['name'] as String? ?? 'Unknown',
      age: (json['age'] as num?)?.toInt() ?? 0,
      imageUrl: primaryImage,
      photoUrls: List<String>.unmodifiable(normalizedPhotos),
      compatibility: (json['compatibility'] as num?)?.toInt() ?? 0,
      bio: json['bio'] as String? ?? '',
      distance: json['distance'] as String? ?? '',
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      geohash: json['geohash'] as String?,
      lastActive: lastActive,
      timezone: json['timezone'] as String?,
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
    'bio': bio,
    'distance': distance,
    if (lat != null) 'lat': lat,
    if (lng != null) 'lng': lng,
    if (geohash != null) 'geohash': geohash,
    if (lastActive != null) 'lastActive': lastActive!.toIso8601String(),
    if (timezone != null) 'timezone': timezone,
  };
}
