import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme.dart';

class MeetupPlannerHUD extends StatefulWidget {
  const MeetupPlannerHUD({super.key});

  @override
  State<MeetupPlannerHUD> createState() => _MeetupPlannerHUDState();
}

class _MeetupPlannerHUDState extends State<MeetupPlannerHUD> {
  int? _selectedVenueIndex;
  String? _selectedTime;

  final List<Map<String, String>> _venues = [
    {
      'name': 'The Social Blue',
      'type': 'Verified Gym Social',
      'distance': '0.8km',
      'rating': '4.9',
      'image': 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?fit=crop&w=300',
    },
    {
      'name': 'Nitro Brews',
      'type': 'Recovery Cafe',
      'distance': '1.2km',
      'rating': '4.7',
      'image': 'https://images.unsplash.com/photo-1509042239860-f550ce710b93?fit=crop&w=300',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Row(
            children: [
              Icon(Icons.location_on, color: FreezmeColors.primary),
              SizedBox(width: 8),
              Text(
                'Plan Social Escape',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Suggest a venue and time to sync with the group.',
            style: TextStyle(color: FreezmeColors.muted),
          ),
          const SizedBox(height: 24),
          
          // Venue Selection
          const Text(
            'VERIFIED SOCIAL HUBS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: FreezmeColors.muted,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _venues.length,
              itemBuilder: (context, index) {
                final venue = _venues[index];
                bool isSelected = _selectedVenueIndex == index;
                return GestureDetector(
                  onTap: () => setState(() => _selectedVenueIndex = index),
                  child: Container(
                    width: 240,
                    margin: const EdgeInsets.only(right: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isSelected ? FreezmeColors.primary : Colors.black12,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: CachedNetworkImage(
                              imageUrl: venue['image']!,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(color: Colors.black12),
                              errorWidget: (context, url, error) => const Icon(Icons.error),
                            ),
                          ),
                          Positioned.fill(
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.transparent, Colors.black87],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 16,
                            left: 16,
                            right: 16,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  venue['name']!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                  ),
                                ),
                                Text(
                                  '${venue['type']} • ${venue['distance']}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            const Positioned(
                              top: 12,
                              right: 12,
                              child: CircleAvatar(
                                radius: 14,
                                backgroundColor: FreezmeColors.primary,
                                child: Icon(Icons.check, size: 16, color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Time Selection
          const Text(
            'SELECT TIME',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: FreezmeColors.muted,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildTimeChip('8:00 AM'),
              const SizedBox(width: 8),
              _buildTimeChip('9:30 AM'),
              const SizedBox(width: 8),
              _buildTimeChip('11:00 AM'),
            ],
          ),
          
          const SizedBox(height: 32),
          
          // Final CTA
          SizedBox(
            width: double.infinity,
            height: 64,
            child: ElevatedButton(
              onPressed: (_selectedVenueIndex != null && _selectedTime != null)
                  ? () => Navigator.pop(context, true)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: FreezmeColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Sync Meetup Plan',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeChip(String time) {
    bool isSelected = _selectedTime == time;
    return GestureDetector(
      onTap: () => setState(() => _selectedTime = time),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? FreezmeColors.primary : FreezmeColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          time,
          style: TextStyle(
            color: isSelected ? Colors.white : FreezmeColors.neutral,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

void showMeetupPlanner(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const MeetupPlannerHUD(),
  );
}
