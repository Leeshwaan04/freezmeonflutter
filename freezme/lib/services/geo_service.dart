import 'package:geolocator/geolocator.dart';

class GeoService {
  static final GeoService _instance = GeoService._internal();
  factory GeoService() => _instance;
  GeoService._internal();

  Future<Position?> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    return await Geolocator.getCurrentPosition();
  }

  // Simple Geohash implementation
  String encodeGeohash(double lat, double lon, {int precision = 9}) {
    // Basic implementation or placeholder if complex logic is needed.
    // For now, let's use a simplified string representation or a known algorithm if possible.
    // Since implementing a full geohash algorithm from scratch is verbose, 
    // I will implement a standard one here.
    
    return _encode(lat, lon, precision);
  }

  // Geohash encoding logic
  static const _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

  String _encode(double lat, double lon, int precision) {
    var idx = 0;
    var bit = 0;
    var evenBit = true;
    var geohash = '';

    var latMin = -90.0;
    var latMax = 90.0;
    var lonMin = -180.0;
    var lonMax = 180.0;

    while (geohash.length < precision) {
      if (evenBit) {
        // Bisect E-W longitude
        var lonMid = (lonMin + lonMax) / 2;
        if (lon >= lonMid) {
          idx = idx * 2 + 1;
          lonMin = lonMid;
        } else {
          idx = idx * 2;
          lonMax = lonMid;
        }
      } else {
        // Bisect N-S latitude
        var latMid = (latMin + latMax) / 2;
        if (lat >= latMid) {
          idx = idx * 2 + 1;
          latMin = latMid;
        } else {
          idx = idx * 2;
          latMax = latMid;
        }
      }
      evenBit = !evenBit;

      if (++bit == 5) {
        geohash += _base32[idx];
        bit = 0;
        idx = 0;
      }
    }

    return geohash;
  }
  
  // Calculate distance in km
  double distanceBetween(double startLat, double startLng, double endLat, double endLng) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng) / 1000;
  }
}
