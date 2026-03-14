import 'package:flutter/material.dart';
import '../theme.dart';
import '../../controllers/flow_controller.dart';

class ProfilePreviewPage extends StatelessWidget {
  const ProfilePreviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final flow = AppFlowScope.of(context, listen: false);
    const imageUrl =
        'https://images.unsplash.com/photo-1546961329-78bef0414d7c?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHx5b3VuZyUyMHdvbWFuJTIwcG9ydHJhaXR8ZW58MXx8fHwxNzYwOTQ2MDQ5fDA&ixlib=rb-4.1.0&q=80&w=1080';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: flow.pop,
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: FreezmeGradients.backgroundSoft,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: Image.network(
                  imageUrl,
                  height: 480,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sarah Johnson, 24',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: FreezmeColors.neutral,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Art Director • 2km away',
                        style: TextStyle(color: FreezmeColors.muted),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: FreezmeGradients.primary,
                    ),
                    child: const Icon(Icons.edit, color: Colors.white, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'About Me',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: FreezmeColors.neutral,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'I\'m a digital artist who loves exploring coffee shops and finding hidden gems in the city. Looking for someone to share deep conversations and spontaneous adventures with 🎨☕✨',
                style: TextStyle(
                  color: FreezmeColors.neutral,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Interests',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: FreezmeColors.neutral,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [
                  _PreviewChip(label: 'Digital Art'),
                  _PreviewChip(label: 'Coffee'),
                  _PreviewChip(label: 'Travel'),
                  _PreviewChip(label: 'Music'),
                  _PreviewChip(label: 'Hiking'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewChip extends StatelessWidget {
  const _PreviewChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: FreezmeColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: FreezmeColors.neutral,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
