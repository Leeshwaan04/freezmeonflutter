# Freezme MVP Features - Implementation Plan

## Executive Summary
This document outlines the implementation plan for completing the core MVP features of the Freezme dating app. Based on thorough codebase analysis, ~60% of the foundation is already built. This plan focuses on the remaining 40% to deliver a production-ready app.

---

## Current State Analysis

### ✅ Already Implemented
1. **Geo Services** - Complete geohash encoding & distance calculation
   - File: `lib/services/geo_service.dart`
   - Status: Production ready

2. **Location Services** - Permission handling & position retrieval
   - File: `lib/services/location_service.dart`
   - Status: Production ready

3. **Auth Infrastructure** - Firebase Auth, Google Sign-In, Apple Sign-In packages
   - File: `pubspec.yaml` (lines 42-45)
   - Status: Packages installed, implementation pending

4. **Localization Framework** - flutter_localizations, intl, auto-generation
   - Files: `l10n.yaml`, `lib/l10n/app_en.arb`
   - Status: Framework ready, needs additional languages

5. **Repository Architecture** - Abstract + 3 implementations (Firestore, Cloud Functions, Mock)
   - Files: `lib/data/*.dart`
   - Status: `fetchTonightPool()` & `updateUserPreferences()` methods exist

6. **UI Components** - Auth buttons, theme system, profile completion page
   - Files: `lib/widgets/auth_button.dart`, `lib/ui/theme.dart`, `lib/ui/profile/profile_completion_page.dart`
   - Status: Basic UI components ready

7. **Photo Upload** - Firebase Storage integration
   - File: `lib/services/photo_upload_service.dart`
   - Status: Production ready

8. **App Flow** - Navigation stack with AppStage enum
   - File: `lib/main.dart` (lines 39-58)
   - Flow: splash → authGate → onboarding → profileCompletion → dailyPool

### ⚠️ Missing/Incomplete

1. **Auth Implementation** - AuthGatePage exists but only calls `startOnboarding()`, no actual Firebase auth
2. **Onboarding Steps** - Referenced files don't exist (`onboarding_step1.dart`, `onboarding_step2.dart`)
3. **Profile Completion** - Missing gender field, needs enhanced validation
4. **Localization** - Only English exists, need Spanish, French, Arabic (RTL)
5. **Tonight Pool Logic** - `fetchTonightPool()` filters by `lastActive` only, no geohash queries or timezone-based 6 PM refresh
6. **Firestore Rules** - Missing rules for `tonight_pool`, `user_preferences` collections
7. **Language Selector** - No UI component for changing language
8. **Tests** - No unit or integration tests

---

## Implementation Plan

### Phase 1: Authentication & Onboarding (Priority 1)

#### 1.1 Firebase Auth Integration
**Objective**: Implement real authentication with email, Google, and Apple Sign-In

**Files to Modify**:
- `lib/main.dart` (AuthGatePage._start method)

**Implementation**:
```dart
// Update AuthGatePage._start method
Future<void> _signInWithApple() async {
  final credential = await SignInWithApple.getAppleIDCredential(...);
  final oauthCredential = OAuthProvider("apple.com").credential(...);
  await FirebaseAuth.instance.signInWithCredential(oauthCredential);
  flow.startOnboarding();
}

Future<void> _signInWithGoogle() async {
  final googleUser = await GoogleSignIn().signIn();
  final googleAuth = await googleUser?.authentication;
  final credential = GoogleAuthProvider.credential(...);
  await FirebaseAuth.instance.signInWithCredential(credential);
  flow.startOnboarding();
}

Future<void> _signInWithEmail(String email, String password) async {
  await FirebaseAuth.instance.signInWithEmailAndPassword(...);
  flow.startOnboarding();
}
```

**Changes**:
- Add 3 auth methods to AuthGatePage: Apple, Google, Email
- Update UI to show all 3 buttons (Apple, Google, Email)
- Add email/password dialog for email sign-in
- Handle auth errors and display user-friendly messages

**Testing**:
- Unit test: Mock Firebase Auth, verify auth flow
- Manual test: Sign in with each provider on iOS device

---

#### 1.2 Onboarding Tutorial Screens
**Objective**: Create engaging tutorial screens explaining app features

**Files to Create**:
- `lib/ui/onboarding/onboarding_step1.dart`
- `lib/ui/onboarding/onboarding_step2.dart`

**Content**:
- **Step 1**: "Spontaneous Connections" - Explain Tonight Algorithm
- **Step 2**: "Vibe Check" - Explain matching based on current energy

**Design**:
```dart
// onboarding_step1.dart
class OnboardingStep1 extends StatelessWidget {
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Illustration (use SVG or Lottie animation)
        Image.asset('assets/onboarding/tonight.png'),
        Text('Spontaneous Connections'),
        Text('Find people who are free tonight, not just someday.'),
      ],
    );
  }
}
```

**Assets Needed**:
- `assets/onboarding/tonight.png`
- `assets/onboarding/vibe_check.png`

**Localization**:
- Add strings to `app_en.arb`:
  - `onboardingStep1Title`
  - `onboardingStep1Desc`
  - `onboardingStep2Title`
  - `onboardingStep2Desc`

---

#### 1.3 Enhanced Profile Completion
**Objective**: Add missing fields (gender, location) and improve validation

**Files to Modify**:
- `lib/ui/profile/profile_completion_page.dart`
- `lib/data/freezme_repository.dart` (update createProfile signature if needed)

**New Fields**:
1. **Gender** - Dropdown: Male, Female, Non-binary, Prefer not to say
2. **Looking For** - Checkbox: Men, Women, Everyone
3. **Location** - Auto-detect via LocationService, allow manual override

**Enhanced Validation**:
- Name: 2-50 characters
- Age: 18-99
- Bio: Optional, max 500 characters
- Photo: Required (at least 1)
- Gender: Required
- Looking For: At least 1 selected

**UI Improvements**:
- Add progress indicator (Step 1 of 3)
- Multi-step form instead of single long page
- Skip button (with warning)

---

### Phase 2: Localization (Priority 2)

#### 2.1 Additional Language Files
**Objective**: Support 4 languages: English, Spanish, French, Arabic

**Files to Create**:
- `lib/l10n/app_es.arb` (Spanish)
- `lib/l10n/app_fr.arb` (French)
- `lib/l10n/app_ar.arb` (Arabic - RTL)

**Translation Keys** (from existing app_en.arb + new):
```json
{
  "appTitle": "Freezme",
  "authApple": "Continue with Apple",
  "authGoogle": "Continue with Google",
  "authEmail": "Continue with Email",
  "onboardingStep1Title": "Spontaneous Connections",
  "profileGender": "Gender",
  "profileLookingFor": "Looking For",
  // ... add all UI strings
}
```

**RTL Support** (Arabic):
- Test with `Directionality(textDirection: TextDirection.rtl)`
- Ensure all layouts use `TextDirection.ltr/rtl`

---

#### 2.2 Language Selector UI
**Objective**: Allow users to change language in settings

**Files to Create**:
- `lib/ui/settings/language_selector.dart`

**Implementation**:
```dart
class LanguageSelector extends StatelessWidget {
  final List<Locale> supportedLocales = [
    Locale('en', 'US'),
    Locale('es', 'ES'),
    Locale('fr', 'FR'),
    Locale('ar', 'SA'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: supportedLocales.length,
      itemBuilder: (context, index) {
        final locale = supportedLocales[index];
        return ListTile(
          title: Text(_getLanguageName(locale)),
          trailing: locale == Localizations.localeOf(context)
              ? Icon(Icons.check)
              : null,
          onTap: () => _changeLanguage(context, locale),
        );
      },
    );
  }

  void _changeLanguage(BuildContext context, Locale locale) {
    // Update app locale
    AppFlowScope.of(context).setLocale(locale);
  }
}
```

**Integration**:
- Add language selector to ProfileSettings page
- Save selected language in SharedPreferences
- Load on app startup

---

### Phase 3: Tonight Pool with Geo & Timezone Logic (Priority 3)

#### 3.1 Enhanced fetchTonightPool Implementation
**Objective**: Implement proper geo-queries and timezone-based 6 PM refresh

**Files to Modify**:
- `lib/data/firestore_freezme_repository.dart` (fetchTonightPool method)

**Current Implementation** (lines 1043-1074):
```dart
// Only filters by lastActive in last 3 hours
final snapshot = await _firestore
    .collection('profiles')
    .where('lastActive', isGreaterThan: threeHoursAgo)
    .limit(50)
    .get();
```

**New Implementation**:
```dart
Future<List<VibeProfile>> fetchTonightPool({
  required double lat,
  required double lng,
  required String timezone,
}) async {
  final geoService = GeoService();

  // 1. Calculate geohash for user location (precision 5 for ~25km radius)
  final geohash = geoService.encodeGeohash(lat, lng, precision: 5);
  final geohashPrefix = geohash.substring(0, 4); // ~40km radius

  // 2. Calculate timezone offset to determine local 6 PM
  final now = DateTime.now();
  final userTimezone = tz.getLocation(timezone);
  final userNow = tz.TZDateTime.from(now, userTimezone);
  final last6PM = tz.TZDateTime(userTimezone, userNow.year, userNow.month, userNow.day, 18);

  // If current time is before 6 PM today, use yesterday's 6 PM
  final cutoffTime = userNow.hour < 18 ? last6PM.subtract(Duration(days: 1)) : last6PM;

  // 3. Query Firestore with geo + time constraints
  final snapshot = await _firestore
      .collection('profiles')
      .where('geohash', isGreaterThanOrEqualTo: geohashPrefix)
      .where('geohash', isLessThan: geohashPrefix + '\uf8ff')
      .where('lastActive', isGreaterThan: cutoffTime.toUtc().toIso8601String())
      .orderBy('lastActive', descending: true)
      .limit(100)
      .get();

  // 4. Filter by distance client-side (Firestore can't do geo + time in one query)
  final profiles = snapshot.docs
      .map((doc) => VibeProfile.fromJson(doc.data(), documentId: doc.id))
      .where((profile) {
        final distance = geoService.distanceBetween(lat, lng, profile.lat, profile.lng);
        return distance <= 50; // 50km radius
      })
      .toList();

  // 5. Sort by recency + proximity (Tonight Algorithm)
  profiles.sort((a, b) {
    final aScore = _calculateTonightScore(a, lat, lng, userNow);
    final bScore = _calculateTonightScore(b, lat, lng, userNow);
    return bScore.compareTo(aScore);
  });

  return profiles.take(50).toList();
}

double _calculateTonightScore(VibeProfile profile, double userLat, double userLng, DateTime now) {
  // Recency score (0-100): Active in last hour = 100, 24 hours ago = 0
  final hoursSinceActive = now.difference(profile.lastActive).inHours;
  final recencyScore = (100 - (hoursSinceActive * 4)).clamp(0, 100);

  // Proximity score (0-100): 0km = 100, 50km = 0
  final distance = GeoService().distanceBetween(userLat, userLng, profile.lat, profile.lng);
  final proximityScore = (100 - (distance * 2)).clamp(0, 100);

  // Weighted average: 60% recency, 40% proximity
  return (recencyScore * 0.6) + (proximityScore * 0.4);
}
```

**Dependencies**:
- Add `timezone` package to pubspec.yaml
- Store user's timezone in profile on signup

**Firestore Schema Updates**:
```json
// profiles collection
{
  "uid": "abc123",
  "geohash": "dr5regy", // Add this field
  "lat": 40.7128,       // Add this field
  "lng": -74.0060,      // Add this field
  "lastActive": "2025-01-05T18:00:00Z",
  "timezone": "America/New_York" // Add this field
}
```

---

#### 3.2 Automatic Tonight Pool Refresh
**Objective**: Refresh pool at 6 PM user's local time

**Implementation**:
- Use WorkManager (Android) / Background Tasks (iOS) for periodic refresh
- Schedule daily task at 6 PM local time
- Send push notification: "Tonight's pool is ready! 🎉"

**Files to Create**:
- `lib/services/tonight_refresh_service.dart`

```dart
class TonightRefreshService {
  static void scheduleRefresh(String timezone) {
    // Calculate next 6 PM in user's timezone
    final userTimezone = tz.getLocation(timezone);
    final now = tz.TZDateTime.now(userTimezone);
    var next6PM = tz.TZDateTime(userTimezone, now.year, now.month, now.day, 18);

    if (now.hour >= 18) {
      next6PM = next6PM.add(Duration(days: 1));
    }

    // Schedule notification
    flutterLocalNotificationsPlugin.zonedSchedule(
      0,
      'Tonight's pool is ready!',
      'Check out who's free tonight in your area',
      next6PM,
      NotificationDetails(...),
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation: ...,
    );
  }
}
```

---

#### 3.3 Home Page Integration
**Objective**: Update HomePage to use fetchTonightPool instead of fetchDailyProfiles

**Files to Modify**:
- `lib/ui/home/home_page.dart` (line 32)

**Current**:
```dart
final profiles = await flow.repository.fetchDailyProfiles();
```

**New**:
```dart
Future<void> _loadData() async {
  setState(() => _isLoading = true);

  // Get user location
  final locationResult = await LocationService().getCoarseLocation();
  if (locationResult.denied) {
    // Show permission dialog
    return;
  }

  // Get user timezone
  final timezone = await FlutterTimezone.getLocalTimezone();

  // Fetch Tonight Pool
  final profiles = await flow.repository.fetchTonightPool(
    lat: locationResult.lat!,
    lng: locationResult.lng!,
    timezone: timezone,
  );

  setState(() {
    _tonightPool = profiles;
    _isLoading = false;
  });
}
```

**Dependencies**:
- Add `flutter_timezone` package to pubspec.yaml

---

### Phase 4: Firestore Rules & Backend (Priority 4)

#### 4.1 Tonight Pool Firestore Rules
**Objective**: Add security rules for tonight_pool queries

**Files to Modify**:
- `backend/firestore.rules`

**New Rules**:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // ... existing rules ...

    // Profiles: read any (for tonight pool), write own
    match /profiles/{uid} {
      allow read: if isSignedIn();
      allow write: if isSignedIn() && request.auth.uid == uid;

      // Ensure geohash, lat, lng, timezone are set
      allow create, update: if request.resource.data.keys().hasAll(['geohash', 'lat', 'lng', 'timezone']);
    }

    // User Preferences
    match /users/{uid}/preferences/{doc} {
      allow read, write: if isSignedIn() && request.auth.uid == uid;
    }
  }
}
```

---

#### 4.2 Firestore Composite Indexes
**Objective**: Add indexes for tonight pool queries

**Files to Modify**:
- `backend/firestore.indexes.json`

**New Indexes**:
```json
{
  "indexes": [
    // ... existing indexes ...
    {
      "collectionGroup": "profiles",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "geohash", "order": "ASCENDING" },
        { "fieldPath": "lastActive", "order": "DESCENDING" }
      ]
    }
  ]
}
```

**Deployment**:
```bash
cd backend
firebase deploy --only firestore:rules,firestore:indexes
```

---

### Phase 5: Testing & Validation (Priority 5)

#### 5.1 Unit Tests
**Objective**: Write tests for critical business logic

**Files to Create**:
- `test/services/geo_service_test.dart`
- `test/services/tonight_algorithm_test.dart`
- `test/data/firestore_repository_test.dart`

**Test Coverage**:
1. **Geo Service**:
   - Geohash encoding accuracy
   - Distance calculation
   - Edge cases (poles, date line)

2. **Tonight Algorithm**:
   - Score calculation
   - Timezone handling
   - 6 PM cutoff logic

3. **Repository**:
   - fetchTonightPool with mock Firestore
   - Auth flow with mock Firebase Auth
   - Error handling

**Example Test**:
```dart
// test/services/tonight_algorithm_test.dart
void main() {
  group('Tonight Algorithm', () {
    test('calculates recency score correctly', () {
      final now = DateTime(2025, 1, 5, 20, 0);
      final profile = VibeProfile(
        lastActive: DateTime(2025, 1, 5, 19, 0), // 1 hour ago
        ...
      );
      final score = _calculateTonightScore(profile, 40.7, -74.0, now);
      expect(score, greaterThan(90)); // Should be high score
    });
  });
}
```

---

#### 5.2 Integration Tests
**Objective**: Test full user flow from auth to tonight pool

**Files to Create**:
- `integration_test/app_flow_test.dart`

**Test Scenarios**:
1. Sign in with Apple → Complete profile → See tonight pool
2. Change language → Verify UI updates
3. Like profile → Match → Chat

**Example Test**:
```dart
// integration_test/app_flow_test.dart
void main() {
  testWidgets('Complete onboarding flow', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    // 1. Auth
    await tester.tap(find.text('Continue with Apple'));
    await tester.pumpAndSettle();

    // 2. Onboarding
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    // 3. Profile Completion
    await tester.enterText(find.byType(TextField).first, 'John Doe');
    await tester.tap(find.text('Save & Continue'));
    await tester.pumpAndSettle();

    // 4. Verify Tonight Pool
    expect(find.text("TONIGHT'S POOL"), findsOneWidget);
  });
}
```

**Run Command**:
```bash
flutter test integration_test/app_flow_test.dart
```

---

#### 5.3 iOS Device Testing
**Objective**: Build and test on Sumit's iPhone (00008110-0018451A1EE0401E)

**Prerequisites**:
1. Connect iPhone to Mac
2. Trust developer certificate
3. Enable Developer Mode on iPhone

**Build Command**:
```bash
flutter build ios --release
open ios/Runner.xcworkspace
# In Xcode: Select device, Product → Run
```

**Manual Test Checklist**:
- [ ] Sign in with Apple works
- [ ] Location permission requested
- [ ] Tonight pool shows nearby users
- [ ] Language selector works
- [ ] RTL layout for Arabic
- [ ] Profile completion saves correctly
- [ ] Photos upload successfully
- [ ] Push notification at 6 PM

---

## Implementation Timeline

### Week 1: Authentication & Onboarding
- Days 1-2: Implement Firebase Auth (Apple, Google, Email)
- Days 3-4: Create onboarding tutorial screens
- Day 5: Enhance profile completion page

### Week 2: Localization & Tonight Pool
- Days 1-2: Add Spanish, French, Arabic translations
- Day 3: Implement language selector
- Days 4-5: Enhance fetchTonightPool with geo & timezone logic

### Week 3: Backend & Testing
- Days 1-2: Update Firestore rules and indexes
- Days 3-4: Write unit and integration tests
- Day 5: iOS device testing and bug fixes

**Total: 3 weeks**

---

## Risk Assessment

### Technical Risks

1. **Geohash Query Limitations**
   - Risk: Firestore can't do geo + time + other filters in one query
   - Mitigation: Fetch broader geohash range, filter client-side

2. **Timezone Complexity**
   - Risk: Edge cases with DST, timezone changes
   - Mitigation: Use `timezone` package, comprehensive tests

3. **Apple Sign-In on iOS**
   - Risk: Requires Apple Developer account setup
   - Mitigation: Test with TestFlight before App Store submission

4. **Location Permission**
   - Risk: Users may deny location access
   - Mitigation: Show compelling explanation, allow manual city entry

### Non-Technical Risks

1. **Translation Quality**
   - Risk: Poor translations reduce user experience
   - Mitigation: Use professional translation service (Lokalise, Phrase)

2. **iOS Provisioning**
   - Risk: Certificate/provisioning profile issues
   - Mitigation: Follow Apple's documentation carefully

---

## Success Metrics

### Functional Metrics
- [ ] All 3 auth methods work (Apple, Google, Email)
- [ ] 4 languages supported with RTL
- [ ] Tonight pool updates at 6 PM local time
- [ ] Geo-queries return users within 50km
- [ ] 80%+ test coverage
- [ ] App builds and runs on iPhone

### Performance Metrics
- [ ] Tonight pool loads in < 2 seconds
- [ ] Geohash queries return in < 500ms
- [ ] Auth flow completes in < 5 seconds

### User Experience Metrics
- [ ] Profile completion rate > 90%
- [ ] Location permission grant rate > 70%
- [ ] App crash rate < 0.1%

---

## Dependencies

### New Packages (add to pubspec.yaml)
```yaml
dependencies:
  timezone: ^0.9.0          # For timezone handling
  flutter_timezone: ^2.0.0  # Get device timezone
  flutter_local_notifications: ^17.0.0  # For 6 PM reminder
```

### External Services
- Firebase Authentication (already configured)
- Firebase Firestore (already configured)
- Apple Developer Account (for Sign in with Apple)
- Google Cloud Console (for Google Sign-In)

---

## Appendix: File Manifest

### Files to Create (15 new files)
1. `lib/ui/onboarding/onboarding_step1.dart`
2. `lib/ui/onboarding/onboarding_step2.dart`
3. `lib/ui/settings/language_selector.dart`
4. `lib/services/tonight_refresh_service.dart`
5. `lib/l10n/app_es.arb`
6. `lib/l10n/app_fr.arb`
7. `lib/l10n/app_ar.arb`
8. `assets/onboarding/tonight.png`
9. `assets/onboarding/vibe_check.png`
10. `test/services/geo_service_test.dart`
11. `test/services/tonight_algorithm_test.dart`
12. `test/data/firestore_repository_test.dart`
13. `integration_test/app_flow_test.dart`
14. `.github/workflows/ci.yml` (optional CI/CD)
15. `IMPLEMENTATION_PLAN.md` (this document)

### Files to Modify (8 existing files)
1. `lib/main.dart` - Add real auth methods to AuthGatePage
2. `lib/ui/profile/profile_completion_page.dart` - Add gender, location fields
3. `lib/ui/home/home_page.dart` - Use fetchTonightPool instead of fetchDailyProfiles
4. `lib/data/firestore_freezme_repository.dart` - Enhance fetchTonightPool
5. `backend/firestore.rules` - Add tonight pool & preferences rules
6. `backend/firestore.indexes.json` - Add geo + time composite index
7. `pubspec.yaml` - Add timezone, flutter_timezone, notifications packages
8. `lib/l10n/app_en.arb` - Add missing translation keys

---

## Next Steps

1. **Review & Approval**: User reviews this plan and approves approach
2. **Environment Setup**: Ensure Firebase project is configured for all auth providers
3. **Start Phase 1**: Begin with authentication implementation
4. **Daily Standup**: Quick sync on progress, blockers
5. **Deploy & Test**: Deploy to TestFlight for UAT

---

**Document Version**: 1.0
**Last Updated**: 2025-01-05
**Author**: Claude (Code Assistant)
**Status**: Pending Approval
