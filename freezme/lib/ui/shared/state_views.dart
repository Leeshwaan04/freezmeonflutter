import 'package:flutter/material.dart';
import '../theme.dart';

/// Lightweight, reusable loading/error/empty scaffolds to keep pages consistent.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: 12),
            Text(message!, style: FreezmeTypography.bodyMuted),
          ],
        ],
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.onRetry, this.message});

  final VoidCallback onRetry;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: FreezmeColors.error.withValues(alpha: 0.9)),
          const SizedBox(height: 8),
          Text(message ?? 'Something went wrong', style: FreezmeTypography.body),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, this.title, this.subtitle, this.action});

  final String? title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox_outlined, size: 36, color: FreezmeColors.muted),
            const SizedBox(height: 8),
            Text(title ?? 'Nothing here yet', style: FreezmeTypography.body),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!, style: FreezmeTypography.bodyMuted, textAlign: TextAlign.center),
            ],
            if (action != null) ...[
              const SizedBox(height: 12),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
