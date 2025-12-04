// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Freezme';

  @override
  String pulseDashboardTitle(String city) {
    return 'Ce soir à $city';
  }

  @override
  String get livePaths => 'Chemins en direct';

  @override
  String get tonightPool => 'Groupe de ce soir';

  @override
  String get trendingVibes => 'Vibes tendance';

  @override
  String get onboardingWelcome => 'Bienvenue sur Freezme';

  @override
  String get onboardingStep1Title => 'Connexions spontanées';

  @override
  String get onboardingStep1Desc =>
      'Trouvez des personnes qui sont libres ce soir, pas seulement un jour.';

  @override
  String get onboardingStep2Title => 'Vérification des vibes';

  @override
  String get onboardingStep2Desc =>
      'Voyez qui correspond à votre énergie en ce moment.';

  @override
  String get profileCompletionTitle => 'Complétez votre profil';

  @override
  String get saveAndContinue => 'Enregistrer et continuer';

  @override
  String get nameLabel => 'Nom';

  @override
  String get ageLabel => 'Âge';

  @override
  String get bioLabel => 'Biographie';

  @override
  String get distanceLabel => 'Distance préférée';
}
