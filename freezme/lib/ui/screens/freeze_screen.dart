import 'package:flutter/material.dart';
import 'dart:ui';
import '../theme.dart';
import '../../controllers/flow_controller.dart';
import '../../core/app_stage.dart';
import '../widgets/luxury_animations.dart';

class FreezeScreen extends StatefulWidget {
  const FreezeScreen({super.key});

  @override
  State<FreezeScreen> createState() => _FreezeScreenState();
}

class _FreezeScreenState extends State<FreezeScreen> with SingleTickerProviderStateMixin {
  final GlobalKey<ShatterTransitionState> _shatterKey = GlobalKey();

  @override
  void dispose() {
    super.dispose();
  }

  void _handleUnfreeze(AppFlowController flow) async {
    _shatterKey.currentState?.start();
    await Future.delayed(const Duration(milliseconds: 800));
    flow.toggleFreeze(false);
  }

  @override
  Widget build(BuildContext context) {
    final flow = AppFlowScope.of(context);
    final missionTheme = MissionTheme.fromArchetype(flow.selectedArchetype);

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient (themed but muted)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    missionTheme.accentColor.withValues(alpha: 0.2),
                    FreezmeColors.background,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),


          SafeArea(
            child: ShatterTransition(
              key: _shatterKey,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Frost Icon
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.2),
                        border: Border.all(color: Colors.white38),
                        boxShadow: [
                          BoxShadow(
                            color: missionTheme.accentColor.withValues(alpha: 0.2),
                            blurRadius: 40,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.ac_unit,
                        size: 64,
                        color: missionTheme.accentColor,
                      ),
                    ),
                    const SizedBox(height: 40),

                    Text(
                      'You are frozen',
                      style: FreezmeTypography.display.copyWith(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      'Taking a breather is intentional.\nYour matches are saved, but the pool is paused.',
                      textAlign: TextAlign.center,
                      style: FreezmeTypography.bodyMuted.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 48),

                    // Countdown / Status Box
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'FREEZE ENDS IN',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                              color: FreezmeColors.muted,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _getRemainingTime(flow.freezeUntil),
                            style: FreezmeTypography.title.copyWith(
                              fontSize: 28,
                              color: missionTheme.accentColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 60),

                    // Unfreeze Button
                    ElevatedButton(
                      onPressed: () => _handleUnfreeze(flow),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: FreezmeColors.neutral,
                        minimumSize: const Size(200, 60),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: const Text('Unfreeze Early'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getRemainingTime(DateTime? until) {
    if (until == null) return "00:00:00";
    final diff = until.difference(DateTime.now());
    if (diff.isNegative) return "00:00:00";
    
    final hours = diff.inHours.toString().padLeft(2, '0');
    final minutes = (diff.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (diff.inSeconds % 60).toString().padLeft(2, '0');
    
    return "$hours:$minutes:$seconds";
  }
}

