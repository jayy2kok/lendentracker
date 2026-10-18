# LenDen Tracker

Private offline loan ledger for Android and iOS. Requirements: [PLAN.md](../PLAN.md), [UI_UX.md](../UI_UX.md). Implementation and verification status: [TODO.md](../design/TODO.md).

## Verification

From this directory:

- `flutter test`: calculator, backup and widget regression tests.
- `flutter analyze`: static analysis.
- `flutter build apk --debug`: Android development build, not a production-signed release.
- `flutter devices`: discover the VS Code-connected Android emulator.

Storage integration tests in `integration_test` require an isolated application ID ending in `.acceptance`. Build from `android` with explicit quoted Gradle properties:

```powershell
.\gradlew.bat assembleDebug '-Ptarget=integration_test/storage_test.dart' '-Ptarget-platform=android-x64' '-PldtTestApplicationIdSuffix=.acceptance'
```

Verify the APK application ID with Android SDK `aapt dump badging` before installing `build\app\outputs\apk\debug\app-debug.apk`. It must be `com.lendentracker.lenden_tracker.acceptance`. Launch its `com.lendentracker.lenden_tracker.MainActivity` and inspect app-PID logcat for the integration test result. Repeat with `integration_test/ledger_test.dart` for native payment/reversal/restart checks. Both tests passed on the Android emulator.

Do not rely on an environment-variable suffix: it did not produce an isolated APK in an earlier build. Flutter may automatically uninstall an existing app after an installation failure; use direct `adb install -r` only after checking the built identity.

The optional Gradle suffix must be verified in the built artifact, not assumed from configuration. Never clear or replace the personal installed ledger for testing. Windows/emulator results do not establish iOS, physical-device authentication, cross-platform restore, or release-signing acceptance.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
