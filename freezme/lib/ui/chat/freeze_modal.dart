import 'package:flutter/material.dart';
import 'package:freezme/ui/theme.dart';

Future<void> showFreezeModal(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: FreezeModalContent(
          onClose: () => Navigator.of(dialogContext).pop(),
        ),
      );
    },
  );
}

class FreezeModalContent extends StatelessWidget {
  const FreezeModalContent({super.key, required this.onClose});

  final VoidCallback onClose;

  static final _options = [
    (
      icon: Icons.person_outline,
      title: 'Freeze my profile',
      description: 'Hide your profile for 24 hours',
      emoji: '🙈',
      premium: false,
    ),
    (
      icon: Icons.ac_unit,
      title: 'Pause this match',
      description: 'Take a break from this connection',
      emoji: '⏸️',
      premium: false,
    ),
    (
      icon: Icons.message_outlined,
      title: 'Freeze chat',
      description: 'Pause notifications for 24 hours',
      emoji: '🔕',
      premium: false,
    ),
    (
      icon: Icons.access_time,
      title: 'Extend Freeze',
      description: 'Premium: Freeze for up to 7 days',
      emoji: '⭐',
      premium: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [FreezmeColors.primary, FreezmeColors.secondary],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      onPressed: onClose,
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ),
                  const Row(
                    children: [
                      Icon(Icons.ac_unit, color: Colors.white, size: 48),
                      SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Take a Breather\nWe\'ll hold your vibe safely',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Scrollable options
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  children: [
                    for (final option in _options) ...[
                      InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: onClose,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: FreezmeColors.surface,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: FreezmeColors.border),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                height: 48,
                                width: 48,
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      FreezmeColors.primary,
                                      FreezmeColors.secondary,
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(option.icon, color: Colors.white),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          option.title,
                                          style: const TextStyle(
                                            color: FreezmeColors.neutral,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(option.emoji),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      option.description,
                                      style: const TextStyle(
                                        color: FreezmeColors.muted,
                                        fontSize: 13,
                                      ),
                                    ),
                                    if (option.premium) ...[
                                      const SizedBox(height: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: const BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              FreezmeColors.secondary,
                                              FreezmeColors.accent,
                                            ],
                                          ),
                                          borderRadius: BorderRadius.all(
                                            Radius.circular(999),
                                          ),
                                        ),
                                        child: const Text(
                                          'Freezme+ Only',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    // Footer note
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: FreezmeColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Text(
                        'Taking breaks is healthy. Your connections will be here when you\'re ready.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: FreezmeColors.primary, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
