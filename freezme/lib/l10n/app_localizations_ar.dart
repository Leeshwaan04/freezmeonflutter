// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'Freezme';

  @override
  String pulseDashboardTitle(String city) {
    return 'الليلة في $city';
  }

  @override
  String get livePaths => 'مسارات مباشرة';

  @override
  String get tonightPool => 'مجموعة الليلة';

  @override
  String get trendingVibes => 'الأجواء الرائجة';

  @override
  String get onboardingWelcome => 'مرحباً بك في Freezme';

  @override
  String get onboardingStep1Title => 'اتصالات عفوية';

  @override
  String get onboardingStep1Desc =>
      'ابحث عن أشخاص متاحين الليلة، وليس يوماً ما.';

  @override
  String get onboardingStep2Title => 'فحص الأجواء';

  @override
  String get onboardingStep2Desc => 'اطلع على من يتناسب مع طاقتك الآن.';

  @override
  String get profileCompletionTitle => 'أكمل ملفك الشخصي';

  @override
  String get saveAndContinue => 'حفظ ومتابعة';

  @override
  String get nameLabel => 'الاسم';

  @override
  String get ageLabel => 'العمر';

  @override
  String get bioLabel => 'السيرة الذاتية';

  @override
  String get distanceLabel => 'المسافة المفضلة';
}
