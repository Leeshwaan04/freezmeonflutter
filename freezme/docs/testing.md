# Testing & QA Guide

## Local commands
- `flutter analyze` – static analysis for Dart and widget linting.
- `flutter test` – runs unit + widget tests (see `test/app_flow_widget_test.dart`).
- `flutter test integration_test/app_test.dart -d flutter-tester` – headless integration tests (see `integration_test/app_test.dart`).
- `flutter test --coverage` – optional coverage report (outputs to `coverage/lcov.info`).
- Passing `useRealtimeServices: false` to `FreezmeApp` (or using `AppFlowController.test`) forces all Firebase-dependent flows to use the in-memory mocks—handy for local UI previews without configuring Firebase.

## What’s covered now
1. **Auth Gate smoke test** – ensures splash finishes and the Apple/Google/Email buttons render.
2. **Daily Vibe Pool sanity test** – verifies the daily deck loads once onboarding is marked complete.
3. **AppFlowController unit tests** – mock the Firebase-dependent photo upload + Melt Chat invite flows so they can be validated without network access.
4. **Integration walk-through** – taps through onboarding, photo uploads, and the compatibility quiz to guarantee the navigation stack survives a full flow.

## Adding more scenarios
- Mirror every major flow (onboarding photos, quiz, daily invite, chat) in `test/` with focused widget tests that mock controllers or repositories.
- For flows that require platform services (camera, Firebase), guard them behind adapters so you can inject fakes in tests.
- Append new end-to-end checks in `integration_test/` whenever you ship a flagship feature (e.g., Melt Chat invite, recap screen, Freezme+ paywall).

## Continuous integration
GitHub Actions (`.github/workflows/flutter_ci.yml`) runs `flutter analyze`, unit/widget tests, and integration tests on every push/PR. Treat a red build as a blocker before merging to `main`.

> Tip: The runtime app now defaults to `FirebasePhotoUploadService`/`FirebaseMeltChatService`. When testing, pass `FreezmeApp(controllerBuilder: () async => AppFlowController.test(...))` and supply the mock services to keep everything deterministic.
