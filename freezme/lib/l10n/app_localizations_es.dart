// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Freezme';

  @override
  String pulseDashboardTitle(String city) {
    return 'Esta Noche En $city';
  }

  @override
  String get livePaths => 'Rutas Activas';

  @override
  String get tonightPool => 'Pool de Esta Noche';

  @override
  String get trendingVibes => 'Vibes Tendencia';

  @override
  String get onboardingWelcome => 'Bienvenido a Freezme';

  @override
  String get onboardingStep1Title => 'Conexiones Espontáneas';

  @override
  String get onboardingStep1Desc =>
      'Encuentra personas libres esta noche, no algún día.';

  @override
  String get onboardingStep2Title => 'Vibe Check';

  @override
  String get onboardingStep2Desc =>
      'Mira quién coincide con tu energía ahora mismo.';

  @override
  String get profileCompletionTitle => 'Completa Tu Perfil';

  @override
  String get saveAndContinue => 'Guardar y Continuar';

  @override
  String get nameLabel => 'Nombre';

  @override
  String get ageLabel => 'Edad';

  @override
  String get bioLabel => 'Bio';

  @override
  String get distanceLabel => 'Distancia preferida';
}
