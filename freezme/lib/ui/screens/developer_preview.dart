import 'package:flutter/material.dart';
import '../theme.dart';
import '../../controllers/flow_controller.dart';
import '../../core/app_stage.dart';

class DeveloperPreviewScreen extends StatelessWidget {
  const DeveloperPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final flow = AppFlowScope.of(context);
    final actions = [
      (
        label: 'Auth Gate',
        action: () => flow.replaceStack(<AppStage>[AppStage.authGate]),
      ),
      (
        label: 'Onboarding',
        action: () => flow.replaceStack(<AppStage>[AppStage.onboarding]),
      ),
      (
        label: 'Daily Vibe Pool',
        action: () => flow.replaceStack(<AppStage>[AppStage.dailyPool]),
      ),
      (
        label: 'Video Date',
        action: () {
          flow.replaceStack(<AppStage>[AppStage.dailyPool]);
          flow.startVideoDate(flow.currentProfile);
        },
      ),
      (
        label: 'Match Success',
        action: () {
          flow.replaceStack(<AppStage>[AppStage.matchSuccess]);
          flow.activeProfile = flow.currentProfile;
        },
      ),
      (
        label: 'Chat Screen',
        action: () {
          flow.replaceStack(<AppStage>[AppStage.dailyPool]);
          flow.openChat(flow.currentProfile);
        },
      ),
      (
        label: 'Profile Settings',
        action: () {
          flow.replaceStack(<AppStage>[AppStage.dailyPool]);
          flow.openProfileSettings();
        },
      ),
      (
        label: 'Profile Preview',
        action: () {
          flow.replaceStack(<AppStage>[AppStage.profilePreview]);
        },
      ),
      (
        label: 'Daily Recap',
        action: () {
          flow.replaceStack(<AppStage>[AppStage.dailyRecap]);
        },
      ),
      (
        label: 'Freezme+',
        action: () {
          flow.replaceStack(<AppStage>[AppStage.freezmePlus]);
        },
      ),
      (
        label: 'Vector Simulation',
        action: flow.openVectorSimulation,
      ),
      (
        label: 'Vibe Verification',
        action: flow.openVerification,
      ),
      for (final archetype in LifestyleArchetype.values)
        (
          label: 'Mission: ${archetype.name.toUpperCase()}',
          action: () {
            flow.setLifestyleArchetype(archetype);
            flow.returnToPool(resetIndex: true);
          },
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Design Previews'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: flow.closeDeveloperMenu,
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              FreezmeColors.background,
              Color(0xFFE7E9FF),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final action in actions)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7A6ACD),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    onPressed: action.action,
                    child: Text(action.label),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
