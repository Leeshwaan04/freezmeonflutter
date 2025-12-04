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
    return 'Esta noche en $city';
  }

  @override
  String get livePaths => 'Rutas en vivo';

  @override
  String get tonightPool => 'Grupo de esta noche';

  @override
  String get trendingVibes => 'Vibras tendencia';

  @override
  String get onboardingWelcome => 'Bienvenido a Freezme';

  @override
  String get onboardingStep1Title => 'Conexiones espontáneas';

  @override
  String get onboardingStep1Desc =>
      'Encuentra personas que están libres esta noche, no solo algún día.';

  @override
  String get onboardingStep2Title => 'Verificación de vibras';

  @override
  String get onboardingStep2Desc =>
      'Mira quién coincide con tu energía ahora mismo.';

  @override
  String get profileCompletionTitle => 'Completa tu perfil';

  @override
  String get saveAndContinue => 'Guardar y continuar';

  @override
  String get nameLabel => 'Nombre';

  @override
  String get ageLabel => 'Edad';

  @override
  String get bioLabel => 'Biografía';

  @override
  String get distanceLabel => 'Distancia preferida';
}
