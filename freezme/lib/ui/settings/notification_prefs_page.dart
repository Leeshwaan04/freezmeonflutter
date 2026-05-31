import 'package:flutter/material.dart';
import '../../main.dart';
import '../design_system.dart';
import '../components/premium_components.dart';

/// Per-type push notification preferences. Backed by GET/PATCH
/// /users/notification-prefs (opt-out model — missing key means enabled).
class NotificationPrefsPage extends StatefulWidget {
  const NotificationPrefsPage({super.key});

  @override
  State<NotificationPrefsPage> createState() => _NotificationPrefsPageState();
}

class _NotificationPrefsPageState extends State<NotificationPrefsPage> {
  bool _loading = true;
  Map<String, bool> _prefs = {};

  static const _items = <({String key, String title, String subtitle})>[
    (key: 'messages', title: 'Messages', subtitle: 'New chat messages'),
    (key: 'matches', title: 'New matches', subtitle: 'When you match with someone'),
    (key: 'likes', title: 'Likes', subtitle: 'When someone likes you'),
    (key: 'pathInvites', title: 'Path invites', subtitle: 'Location-based meetup invites'),
    (key: 'freezeRoom', title: 'Freeze rooms', subtitle: 'Group discovery rooms opening'),
    (key: 'marketing', title: 'News & offers', subtitle: 'Product updates and promotions'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final flow = AppFlowScope.of(context, listen: false);
      final prefs = await flow.repository.getNotificationPrefs();
      if (mounted) setState(() { _prefs = prefs; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle(String key, bool value) async {
    setState(() => _prefs[key] = value);
    try {
      final flow = AppFlowScope.of(context, listen: false);
      await flow.repository.updateNotificationPrefs({key: value});
    } catch (_) {
      if (mounted) {
        setState(() => _prefs[key] = !value); // revert
        PremiumSnackBar.show(context, 'Could not update. Please try again.', type: SnackBarType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FreezmeDesignSystem.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: FreezmeDesignSystem.background,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(FreezmeDesignSystem.spaceMd),
              children: [
                for (final item in _items)
                  SwitchListTile.adaptive(
                    value: _prefs[item.key] ?? (item.key != 'marketing'),
                    onChanged: (v) => _toggle(item.key, v),
                    title: Text(item.title, style: FreezmeDesignSystem.body),
                    subtitle: Text(item.subtitle, style: FreezmeDesignSystem.caption),
                    activeTrackColor: FreezmeDesignSystem.primary,
                  ),
              ],
            ),
    );
  }
}
