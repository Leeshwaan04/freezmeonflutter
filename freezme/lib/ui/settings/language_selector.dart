import 'package:flutter/material.dart';
import '../../services/localization_service.dart';
import '../theme.dart';

class LanguageSelector extends StatefulWidget {
  const LanguageSelector({super.key});

  @override
  State<LanguageSelector> createState() => _LanguageSelectorState();
}

class _LanguageSelectorState extends State<LanguageSelector> {
  String _selectedLocale = LocalizationService().currentLocale.languageCode;

  final List<Map<String, String>> _languages = [
    {'code': 'en', 'name': 'English', 'flag': '🇺🇸'},
    {'code': 'es', 'name': 'Español', 'flag': '🇪🇸'},
    {'code': 'fr', 'name': 'Français', 'flag': '🇫🇷'},
    {'code': 'de', 'name': 'Deutsch', 'flag': '🇩🇪'},
    {'code': 'pt', 'name': 'Português', 'flag': '🇧🇷'},
    {'code': 'ar', 'name': 'العربية', 'flag': '🇸🇦'},
    {'code': 'hi', 'name': 'हिन्दी', 'flag': '🇮🇳'},
    {'code': 'zh', 'name': '中文', 'flag': '🇨🇳'},
    {'code': 'ja', 'name': '日本語', 'flag': '🇯🇵'},
    {'code': 'ko', 'name': '한국어', 'flag': '🇰🇷'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Language'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: FreezmeGradients.backgroundSoft,
        ),
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _languages.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final lang = _languages[index];
            final isSelected = lang['code'] == _selectedLocale;

            return Card(
              elevation: isSelected ? 4 : 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: isSelected
                    ? const BorderSide(color: FreezmeColors.primary, width: 2)
                    : BorderSide.none,
              ),
              child: ListTile(
                leading: Text(
                  lang['flag']!,
                  style: const TextStyle(fontSize: 28),
                ),
                title: Text(
                  lang['name']!,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? FreezmeColors.primary : FreezmeColors.neutral,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_circle, color: FreezmeColors.primary)
                    : null,
                onTap: () async {
                  final code = lang['code']!;
                  setState(() => _selectedLocale = code);
                  await LocalizationService().setLocale(code);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Language changed to ${lang['name']}'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
