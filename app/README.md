# LenDen Tracker

Private offline loan ledger for Android and iOS. Requirements: [PLAN.md](../PLAN.md), [UI_UX.md](../UI_UX.md). Implementation and verification status: [TODO.md](../design/TODO.md).

## Verification

From this directory:

- `flutter test`: calculator, backup and widget regression tests.
- `flutter analyze`: static analysis.
- `flutter build apk --debug`: Android development build, not a production-signed release.
- `flutter devices`: discover the VS Code-connected Android emulator.

Storage integration tests in `integration_test` require an isolated application ID ending in `.acceptance`. The Gradle `assembleDebug` command only **builds** a test APK; it does not run the test or report completion. On an arm64 physical device, run the bounded ledger runner from this directory:

```powershell
python tool/run_ledger_device.py 'adb-10BFBQ133K0024U-aGMvZL._adb-tls-connect._tcp'
```

The runner invokes Flutter's integration-test harness with the `acceptance` Android flavor (application ID `com.lendentracker.lenden_tracker.acceptance`) on the specified serial. It clears stale device port forwards and logcat entries before launching, because Flutter uses both to discover its VM service; neither is used as the test verdict. Flutter reports assertions and `All tests passed!`, returning nonzero for a failed test. The runner bounds the device check to 30 seconds, each test to 90 seconds, and the entire Flutter invocation to 600 seconds. The `standard` flavor remains the default for normal builds.

For the storage integration target, use the same isolated flavor and Flutter harness, replacing the target path:

```powershell
flutter test integration_test/storage_test.dart -d '<device-serial>' --flavor acceptance --timeout 90s
```

The test asserts that the runtime documents directory belongs to `.acceptance` before touching the database. Never clear or replace the personal installed ledger for testing. Physical-device ledger verification is described above; it does not establish iOS, cross-platform restore, or release-signing acceptance.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
