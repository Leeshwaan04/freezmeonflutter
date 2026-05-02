import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class LocationResult {
  const LocationResult({this.lat, this.lng, this.cityName, this.denied = false});

  final double? lat;
  final double? lng;
  final String? cityName;
  final bool denied;
}

class LocationService {
  Future<LocationResult> getCoarseLocation() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      final requested = await Geolocator.requestPermission();
      if (requested == LocationPermission.denied ||
          requested == LocationPermission.deniedForever) {
        return const LocationResult(denied: true);
      }
    } else if (permission == LocationPermission.deniedForever) {
      return const LocationResult(denied: true);
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 5),
        ),
      );
      final cityName = await _reverseGeocode(position.latitude, position.longitude);
      return LocationResult(
        lat: position.latitude,
        lng: position.longitude,
        cityName: cityName,
      );
    } catch (_) {
      return const LocationResult(denied: true);
    }
  }

  /// Returns neighbourhood/suburb → city → state as a short readable name.
  /// Falls back gracefully to null on any network/parse failure.
  Future<String?> _reverseGeocode(double lat, double lng) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=json&lat=$lat&lon=$lng&zoom=12&addressdetails=1',
      );
      final response = await http.get(
        uri,
        headers: {'User-Agent': 'FreezmeApp/1.0'},
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final address = data['address'] as Map<String, dynamic>?;
      if (address == null) return null;

      // Prefer city-level name for clean display (e.g. "Mumbai" not "Zone 5")
      final city = address['city'] as String? ??
          address['town'] as String? ??
          address['village'] as String? ??
          address['county'] as String?;
      // Optionally append suburb for specificity if city is known
      final suburb = address['suburb'] as String? ??
          address['neighbourhood'] as String? ??
          address['city_district'] as String?;
      final name = city != null && suburb != null && suburb != city
          ? '$city, $suburb'
          : city ?? suburb ?? address['state'] as String?;

      return name;
    } catch (_) {
      return null;
    }
  }
}
