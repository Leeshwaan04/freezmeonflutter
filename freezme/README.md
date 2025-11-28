# Freezme – Mindful Dating App

Freezme is a Flutter application built around nightly matchmaking, video dates, and a guided onboarding flow. The project now includes Firebase authentication, Cloud Functions integration, and Google Play Billing in-app purchases for Freezme+.

---

## Project Structure

- `lib/main.dart` – App navigation, flows, and UI screens.
- `lib/data/` – Data layer, repositories, and integrations (Firestore, Cloud Functions, payments).
- `backend/functions` – Firebase Cloud Functions used for matchmaking, profile creation, and purchase verification (stubbed fallbacks included in the Flutter client).
- `ios`, `android`, `web`, etc. – Platform-specific project scaffolding produced by Flutter.

---

## Firebase & Cloud Functions

1. Create a Firebase project and add iOS + Android apps.
2. Download the configuration files (`GoogleService-Info.plist` and `google-services.json`) into the respective platform folders.
3. From `backend/functions`, install dependencies and start the emulator or deploy functions once your Firebase project is on the Blaze plan:
   ```bash
   cd backend/functions
   npm install
   npm run build
   firebase emulators:start
   ```
4. When ready to deploy callable functions (create profile, daily pool, likes, matches, `verifyAndroidPurchase`), run:
   ```bash
   firebase deploy --only functions
   ```

---

## Freezme+ Subscription (Google Play Billing)

Freezme+ powers premium features (extra matches, global visibility, etc.). Internally we use the `in_app_purchase` plugin and a new `PremiumPaywallController` to query products, launch the billing flow, and send purchase tokens to Cloud Functions for verification.

### Configure Google Play Billing

1. **Create a product** in Google Play Console  
   - Open **Monetize → Products → Subscriptions**  
   - Add a subscription with the ID `freezme_plus_monthly` (this matches the constant in code).  
   - Set the price, free trial, intro offers, etc. as desired.

2. **Enable license testers**  
   - Under **Setup → License testing**, add the Gmail accounts you use on test devices.

3. **Upload a build**  
   - Build a release bundle:  
     ```bash
     flutter build appbundle --release
     ```  
   - Upload to an internal test track so Billing Client can return real responses.

4. **Test purchases**  
   - On your test device (logged into a license tester account), open the internal track build.  
   - Navigate to *Freezme+* → purchase or restore.  
   - Successful purchases unlock the membership banner in the daily pool and update the paywall state.

> **Note:** The Flutter client includes a generous fallback: if the Cloud Function `verifyAndroidPurchase` is not yet deployed it still unlocks Freezme+ locally for testing, but you should publish the verification endpoint before launch.

### Restore & Entitlements

- The paywall exposes “Restore purchases”, which calls `InAppPurchase.restorePurchases()` and re-validates any existing entitlements.
- `AppFlowController` persists a `plus_member` flag and optional expiry to `SharedPreferences`, so membership survives app restarts.
- The daily pool header now shows a “Freezme+ active” badge when your subscription is detected.

### Backend verification

Deploy the callable Cloud Function `verifyAndroidPurchase` so every purchase token is validated against the Google Play Developer API. It requires two environment variables:

```bash
# Set a service-account JSON (with Android Publisher scope) as a single-line string
firebase functions:config:set \
  play.service_account="$(cat service-account.json | tr -d '\n')"

# Or when using the local emulator / Cloud Run:
export PLAY_SERVICE_ACCOUNT="$(cat service-account.json)"
export PLAY_BILLING_PACKAGE_NAME="com.example.freezme" # update to your package id
```

The function updates the `memberships/{uid}` Firestore document with the latest status and returns an ISO expiry date to the app. Remember to redeploy functions after setting the environment variables:

```bash
cd backend/functions
npm run build
firebase deploy --only functions
```

---

## Launch Checklist (Android)

1. **App configuration**
   - Update `android/app/src/main/AndroidManifest.xml` with the release application ID.
   - Configure app signing (upload key and Play signing) in `android/app/build.gradle.kts`.
   - Bump the `version` in `pubspec.yaml` for every release.

2. **Billing readiness**
   - Ensure every premium SKU used in code exists in Play Console.
   - Provide localized price and description for each market.
   - Verify the `verifyAndroidPurchase` Cloud Function (or your own server) validates purchase tokens.

3. **Store listing**
   - Supply localized descriptions, screenshots (phone/tablet), feature graphic, icons.
   - Upload privacy policy URL (must include how you handle subscriptions and user data).
   - Complete Data safety and Content rating questionnaires.

4. **Quality gates**
   - Run `flutter analyze` and address blockers.
   - Exercise the onboarding → profile creation → daily pool → Freezme+ flows on physical and virtual devices.
   - Use Play Console’s Pre-launch report to catch crashes on a matrix of devices.

---

## Running Locally

```
flutter pub get
flutter run
```

To connect to Firebase emulators during development, ensure you launched `firebase emulators:start` and leave the debug `FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);` flag enabled (already handled in `main.dart` when `kDebugMode` is `true`).

---

## Next Steps

- Implement the `verifyAndroidPurchase` Cloud Function that validates purchase tokens via the Google Play Developer API.
- Define your backend contract for push notifications, chat/video, and payment receipts so the `CloudFunctionsFreezmeRepository` can transition from fallbacks to production data.
- When you’re ready for iOS, integrate `in_app_purchase_storekit` and configure App Store Connect subscriptions using the same product IDs.

Feel free to extend the documentation as more backend services, experiments, or release procedures come online.
