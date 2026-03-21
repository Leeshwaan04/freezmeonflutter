import 'package:flutter/material.dart';
import '../design_system.dart';

/// Enhanced Typing Indicator with smooth bouncing dots
class TypingIndicator extends StatefulWidget {
  final String? userName;
  
  const TypingIndicator({
    super.key,
    this.userName,
  });

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: FreezmeDesignSystem.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
          bottomLeft: Radius.circular(4),
          bottomRight: Radius.circular(20),
        ),
        border: Border.all(
          color: FreezmeDesignSystem.border,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Bouncing dots
          ...List.generate(3, (index) {
            return AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final offset = index * 0.2;
                final value = (_controller.value + offset) % 1.0;
                // Create bouncing effect
                final bounce = (value < 0.5) 
                    ? value * 2 
                    : 2.0 - (value * 2);
                
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  child: Transform.translate(
                    offset: Offset(0, -bounce * 4),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: FreezmeDesignSystem.primary.withValues(alpha: 0.5 + (bounce * 0.5)),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              },
            );
          }),
          if (widget.userName != null) ...[
            const SizedBox(width: 8),
            Text(
              '${widget.userName} is typing',
              style: FreezmeDesignSystem.small.copyWith(
                color: FreezmeDesignSystem.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Read Receipt Icon - Shows message delivery status
class ReadReceipt extends StatelessWidget {
  final MessageDeliveryStatus status;
  final double size;

  const ReadReceipt({
    super.key,
    required this.status,
    this.size = 16,
  });

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MessageDeliveryStatus.sending:
        return SizedBox(
          width: size,
          height: size,
          child: const CircularProgressIndicator(
            strokeWidth: 1.5,
            color: FreezmeDesignSystem.textTertiary,
          ),
        );
      case MessageDeliveryStatus.sent:
        return Icon(
          Icons.check_rounded,
          size: size,
          color: FreezmeDesignSystem.textTertiary,
        );
      case MessageDeliveryStatus.delivered:
        return Icon(
          Icons.done_all_rounded,
          size: size,
          color: FreezmeDesignSystem.textTertiary,
        );
      case MessageDeliveryStatus.read:
        return Icon(
          Icons.done_all_rounded,
          size: size,
          color: FreezmeDesignSystem.primary,
        );
      case MessageDeliveryStatus.failed:
        return Icon(
          Icons.error_outline_rounded,
          size: size,
          color: FreezmeDesignSystem.error,
        );
    }
  }
}

enum MessageDeliveryStatus {
  sending,
  sent,
  delivered,
  read,
  failed,
}
