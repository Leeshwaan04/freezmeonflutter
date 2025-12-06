import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFF5F8), // Surface - light pink
              Color(0xFFF5E6F0), // Surface Alt - lavender pink
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App Logo Icon
              Icon(
                Icons.ac_unit_outlined,
                size: 80,
                color: Color(0xFF6C4B9C), // Primary purple
              ),
              SizedBox(height: 24),
              
              // App Name
              Text(
                'FREEZME',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF6C4B9C), // Primary purple
                  letterSpacing: 4,
                ),
              ),
              SizedBox(height: 8),
              
              // Tagline
              Text(
                'Tonight. Not someday.',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF8B7A9A), // Muted purple-gray
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
