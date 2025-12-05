import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalizationService extends ChangeNotifier {
  static final LocalizationService _instance = LocalizationService._internal();
  factory LocalizationService() => _instance;
  LocalizationService._internal();

  Locale _currentLocale = const Locale('en');
  Locale get currentLocale => _currentLocale;

  static const String _localeKey = 'selected_locale';

  final List<Locale> supportedLocales = const [
    Locale('en'), // English
    Locale('es'), // Spanish
    Locale('ar'), // Arabic (RTL)
    Locale('fr'), // French
    Locale('de'), // German
    Locale('pt'), // Portuguese
    Locale('hi'), // Hindi
    Locale('zh'), // Chinese
    Locale('ja'), // Japanese
    Locale('ko'), // Korean
  ];

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLocale = prefs.getString(_localeKey);
    if (savedLocale != null) {
      _currentLocale = Locale(savedLocale);
    }
  }

  Future<void> setLocale(String languageCode) async {
    if (_currentLocale.languageCode == languageCode) return;

    _currentLocale = Locale(languageCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, languageCode);
    notifyListeners();
  }

  bool get isRtl => _currentLocale.languageCode == 'ar' || _currentLocale.languageCode == 'he';

  String getLanguageName(String code) {
    const names = {
      'en': 'English',
      'es': 'Español',
      'ar': 'العربية',
      'fr': 'Français',
      'de': 'Deutsch',
      'pt': 'Português',
      'hi': 'हिन्दी',
      'zh': '中文',
      'ja': '日本語',
      'ko': '한국어',
    };
    return names[code] ?? code;
  }
}
