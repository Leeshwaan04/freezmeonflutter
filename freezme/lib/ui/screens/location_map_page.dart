import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../design_system.dart';

/// View-only map of the user's live location (OpenStreetMap tiles, no API key).
/// The user can pan/zoom to look around but cannot change their matching
/// location from here — it's a "where am I in the pool" view, not an editor.
class LocationMapPage extends StatelessWidget {
  const LocationMapPage({
    super.key,
    required this.lat,
    required this.lng,
    required this.cityName,
  });

  final double lat;
  final double lng;
  final String cityName;

  @override
  Widget build(BuildContext context) {
    final center = LatLng(lat, lng);
    return Scaffold(
      backgroundColor: FreezmeDesignSystem.background,
      appBar: AppBar(
        backgroundColor: FreezmeDesignSystem.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back to Tonight',
        ),
        title: Text(cityName, style: FreezmeDesignSystem.h3),
      ),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: center,
                initialZoom: 13,
                minZoom: 3,
                maxZoom: 18,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  // OSM tile-usage policy requires a real UA identifier.
                  userAgentPackageName: 'com.freezme.app',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: center,
                      width: 48,
                      height: 48,
                      child: const _LocationPin(),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // View-only clarification — reassures on privacy.
          Container(
            width: double.infinity,
            color: FreezmeDesignSystem.background,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Text(
              "This is your approximate location — it shapes tonight's pool. "
              'Your exact spot is never shown to anyone.',
              textAlign: TextAlign.center,
              style: FreezmeDesignSystem.small
                  .copyWith(color: FreezmeDesignSystem.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationPin extends StatelessWidget {
  const _LocationPin();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: FreezmeDesignSystem.primary,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: FreezmeDesignSystem.primary.withValues(alpha: 0.45),
            blurRadius: 14,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Icon(Icons.person_rounded, color: Colors.white, size: 26),
    );
  }
}
