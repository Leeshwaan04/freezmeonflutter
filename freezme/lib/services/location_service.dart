import 'package:geolocator/geolocator.dart';

class LocationResult {
  const LocationResult({this.lat, this.lng, this.denied = false});

  final double? lat;
  final double? lng;
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
        ),
      );
      return LocationResult(lat: position.latitude, lng: position.longitude);
    } catch (_) {
      return const LocationResult(denied: true);
    }
  }
}
