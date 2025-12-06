import 'package:flutter_test/flutter_test.dart';
import 'package:freezme/services/geo_service.dart';

void main() {
  group('GeoService', () {
    late GeoService geoService;

    setUp(() {
      geoService = GeoService();
    });

    group('encodeGeohash', () {
      test('encodes New York coordinates correctly', () {
        // New York City: 40.7128° N, 74.0060° W
        final geohash = geoService.encodeGeohash(40.7128, -74.0060, precision: 9);

        // Geohash for NYC should start with 'dr5r'
        expect(geohash.startsWith('dr5r'), true);
        expect(geohash.length, 9);
      });

      test('encodes San Francisco coordinates correctly', () {
        // San Francisco: 37.7749° N, 122.4194° W
        final geohash = geoService.encodeGeohash(37.7749, -122.4194, precision: 9);

        // Geohash for SF should start with '9q8y'
        expect(geohash.startsWith('9q8y'), true);
        expect(geohash.length, 9);
      });

      test('respects precision parameter', () {
        final geohash5 = geoService.encodeGeohash(40.7128, -74.0060, precision: 5);
        final geohash7 = geoService.encodeGeohash(40.7128, -74.0060, precision: 7);

        expect(geohash5.length, 5);
        expect(geohash7.length, 7);
        expect(geohash7.startsWith(geohash5), true);
      });

      test('handles equator coordinates', () {
        final geohash = geoService.encodeGeohash(0.0, 0.0, precision: 5);
        expect(geohash, 's0000');
      });

      test('handles pole coordinates', () {
        final northPole = geoService.encodeGeohash(89.9, 0.0, precision: 5);
        final southPole = geoService.encodeGeohash(-89.9, 0.0, precision: 5);

        expect(northPole.isNotEmpty, true);
        expect(southPole.isNotEmpty, true);
        expect(northPole != southPole, true);
      });
    });

    group('distanceBetween', () {
      test('calculates distance between NYC and LA correctly', () {
        // NYC: 40.7128° N, 74.0060° W
        // LA: 34.0522° N, 118.2437° W
        final distance = geoService.distanceBetween(40.7128, -74.0060, 34.0522, -118.2437);

        // Distance should be approximately 3935 km
        expect(distance, greaterThan(3900));
        expect(distance, lessThan(4000));
      });

      test('calculates zero distance for same location', () {
        final distance = geoService.distanceBetween(40.7128, -74.0060, 40.7128, -74.0060);
        expect(distance, 0.0);
      });

      test('calculates short distances accurately', () {
        // Two locations 1km apart in NYC
        final distance = geoService.distanceBetween(40.7128, -74.0060, 40.7138, -74.0060);

        // Should be approximately 1.1 km
        expect(distance, greaterThan(1.0));
        expect(distance, lessThan(1.5));
      });

      test('calculates distance across date line', () {
        // Tokyo to San Francisco (crosses date line)
        final distance = geoService.distanceBetween(35.6762, 139.6503, 37.7749, -122.4194);

        // Distance should be approximately 8280 km
        expect(distance, greaterThan(8000));
        expect(distance, lessThan(9000));
      });
    });

    group('edge cases', () {
      test('handles negative coordinates', () {
        final geohash = geoService.encodeGeohash(-33.8688, 151.2093, precision: 5);
        expect(geohash.isNotEmpty, true);
        expect(geohash.length, 5);
      });

      test('handles boundary coordinates', () {
        final geohash1 = geoService.encodeGeohash(90.0, 180.0, precision: 5);
        final geohash2 = geoService.encodeGeohash(-90.0, -180.0, precision: 5);

        expect(geohash1.isNotEmpty, true);
        expect(geohash2.isNotEmpty, true);
      });

      test('geohash proximity indicates nearby locations', () {
        final geohash1 = geoService.encodeGeohash(40.7128, -74.0060, precision: 5);
        final geohash2 = geoService.encodeGeohash(40.7138, -74.0065, precision: 5);

        // Nearby locations should have similar geohash prefixes
        expect(geohash1, equals(geohash2));
      });
    });
  });
}
