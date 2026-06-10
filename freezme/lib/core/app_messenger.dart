import 'package:flutter/material.dart';
import '../ui/theme.dart';

/// Root ScaffoldMessenger so toasts survive page/stack transitions (e.g. a
/// "Signed in" confirmation shown as the auth screen is replaced by onboarding).
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Show a floating toast at the app root. Safe to call across navigation.
void showAppToast(String message, {bool success = true}) {
  final messenger = rootScaffoldMessengerKey.currentState;
  if (messenger == null) return;
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(success ? Icons.check_circle_rounded : Icons.info_outline,
              color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: success ? FreezmeColors.primary : FreezmeColors.neutral,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
    ),
  );
}
