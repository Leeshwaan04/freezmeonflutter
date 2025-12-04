// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Freezme';

  @override
  String pulseDashboardTitle(String city) {
    return 'Tonight In $city';
  }

  @override
  String get livePaths => 'Live Paths';

  @override
  String get tonightPool => 'Tonight\'s Pool';

  @override
  String get trendingVibes => 'Trending Vibes';

  @override
  String get onboardingWelcome => 'Welcome to Freezme';

  @override
  String get onboardingStep1Title => 'Spontaneous Connections';

  @override
  String get onboardingStep1Desc =>
      'Find people who are free tonight, not just someday.';

  @override
  String get onboardingStep2Title => 'Vibe Check';

  @override
  String get onboardingStep2Desc => 'See who matches your energy right now.';

  @override
  String get profileCompletionTitle => 'Complete Your Profile';

  @override
  String get saveAndContinue => 'Save & Continue';

  @override
  String get nameLabel => 'Name';

  @override
  String get ageLabel => 'Age';

  @override
  String get bioLabel => 'Bio';

  @override
  String get distanceLabel => 'Preferred distance';
}
