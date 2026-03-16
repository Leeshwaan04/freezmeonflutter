import 'dart:convert';
import '../models/vibe_profile.dart';

/// VibeService handles the E2E communication with the Go Backend
/// and Pinecone-backed Matching Engine.
class VibeService {
  final String baseUrl = "https://api.freezme.app/v1";

  Future<void> toggleFreeze(bool status) async {
    // POST /user/toggle-freeze
    print("API CALL: Sending freeze status $status to backend...");
    // await http.post("$baseUrl/user/toggle-freeze", body: {"status": status});
  }

  Future<List<VibeProfile>> fetchDailyPool() async {
    // GET /matches/daily
    print("API CALL: Fetching 7 AM curated pool...");
    // final response = await http.get("$baseUrl/matches/daily");
    // return (json.decode(response.body) as List).map((p) => VibeProfile.fromJson(p)).toList();
    return []; // Mock return for now
  }

  Future<void> submitVibeRating(String dateId, int rating) async {
    // POST /matches/vibe/rate
    print("API CALL: Submitting vibe rating $rating for session $dateId");
  }

  Future<void> verifySelfie(String imagePath) async {
    // POST /user/verify
    print("API CALL: Uploading selfie for AI verification...");
  }
}
