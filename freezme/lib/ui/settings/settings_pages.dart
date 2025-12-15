import 'package:flutter/material.dart';
import '../design_system.dart';

class SafetyPrivacyPage extends StatelessWidget {
  const SafetyPrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FreezmeDesignSystem.background,
      appBar: AppBar(title: const Text('Safety & Privacy', style: FreezmeDesignSystem.h3)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          ListTile(
            leading: Icon(Icons.lock_outline, color: FreezmeDesignSystem.primary),
            title: Text('Privacy Policy'),
            trailing: Icon(Icons.arrow_forward_ios, size: 16),
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.shield_outlined, color: FreezmeDesignSystem.primary),
            title: Text('Safety Tips'),
            trailing: Icon(Icons.arrow_forward_ios, size: 16),
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.block, color: FreezmeDesignSystem.error),
            title: Text('Blocked Users'),
            trailing: Icon(Icons.arrow_forward_ios, size: 16),
          ),
        ],
      ),
    );
  }
}

class HelpSupportPage extends StatelessWidget {
  const HelpSupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FreezmeDesignSystem.background,
      appBar: AppBar(title: const Text('Help & Support', style: FreezmeDesignSystem.h3)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const ListTile(
            leading: Icon(Icons.help_outline, color: FreezmeDesignSystem.primary),
            title: Text('FAQ'),
            trailing: Icon(Icons.arrow_forward_ios, size: 16),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.mail_outline, color: FreezmeDesignSystem.primary),
            title: const Text('Contact Us'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
               // Launch email
            },
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.bug_report_outlined, color: FreezmeDesignSystem.primary),
            title: Text('Report a Bug'),
            trailing: Icon(Icons.arrow_forward_ios, size: 16),
          ),
        ],
      ),
    );
  }
}
