import '../models/vibe_profile.dart';

abstract class FreezmeRepository {
  Future<List<VibeProfile>> fetchDailyProfiles();
  Future<void> createProfile(VibeProfile profile);
  Future<void> likeProfile(String targetUid);
  Future<void> skipProfile(String targetUid);
  Future<List<Map<String, dynamic>>> fetchMatches();
}
