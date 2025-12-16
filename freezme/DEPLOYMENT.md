# Deployment Guide

## 1. Pre-Flight Check ✈️
Ensure all tests pass before building:
```bash
flutter test
```
*(Status: All Tests Passed as of Dec 16)*

## 2. Update Version 🏷️
Edit `pubspec.yaml`:
```yaml
version: 1.0.3+4  # Bump this!
```
- The first number (1.0.3) is the user-facing version.
- The second number (+4) is the build code (must strictly increase).

## 3. Build for iOS 🍏
1. Open `ios/Runner.xcworkspace` in Xcode.
2. Select "Any iOS Device (arm64)".
3. Go to **Product > Archive**.
4. Once archived, click **Distribute App** -> **App Store Connect** -> **Upload**.
   - Ensure you have your Apple Developer Account logged in.

*Command Line Alternative:*
```bash
flutter build ipa
```
(Requires valid signing setup in Xcode beforehand).

## 4. Build for Android 🤖
1. Generate a Keystore if you haven't (for signing).
2. Run:
```bash
flutter build appbundle
```
3. Upload `build/app/outputs/bundle/release/app-release.aab` to Google Play Console.

## 5. App Store Listing 📝
Use the materials prepared in `marketing-site/APP_STORE.md`:
- **Title**: Freezme
- **Subtitle**: Break the Ice, Tonight.
- **Description**: Copy from file.
- **Keywords**: Copy from file.

## 6. Post-Release 🚀
- **Monitor**: Check Firebase Crashlytics for any issues.
- **Engage**: Use the "Tonight" feature to Seed initial activity if user base is low.

---
**Good Luck! Break the Ice! ❄️**
