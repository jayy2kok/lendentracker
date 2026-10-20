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

## Android release delivery

`.github/workflows/android-release.yml` checks out the source and runs `flutter analyze` and `flutter test test` on pull requests and manual dispatches. **Only** a manually dispatched run on `main` proceeds to the `production-release` environment after verification; configure that GitHub environment with required reviewers and restrict deployment branches to `main`. Never approve a release from an unreviewed commit. The environment must contain four **environment secrets**: `RELEASE_KEYSTORE_BASE64` (base64 of the authorized, existing stable production JKS), `RELEASE_KEYSTORE_PASSWORD`, `RELEASE_KEY_ALIAS`, and `RELEASE_KEY_PASSWORD`. Do not create a new production identity merely to make CI green. The key is decoded to runner temporary storage, never to a tracked file or uploaded artifact. Protect access to the keystore and its backup out of band; losing or changing this key breaks in-place upgrades. PR jobs have no signing secrets and cannot upload release APKs. Verify GitHub environment protection and repository Actions permissions before enabling release dispatch.

The app's `standard` release build requires all four signing variables (the base64 secret is decoded first into `RELEASE_KEYSTORE_PATH`); missing variables or a nonexistent key file stop release packaging. Debug and acceptance test builds do not require them. There is **no debug-key fallback**. From `app/`, maintainers with authorized credentials may build locally using `flutter build apk --release --flavor standard`, with `RELEASE_KEYSTORE_PATH`, `RELEASE_KEYSTORE_PASSWORD`, `RELEASE_KEY_ALIAS`, and `RELEASE_KEY_PASSWORD` supplied privately in the environment. Do not paste credentials into commands, logs, issues, or commits. `version: 1.0.0+1` in `pubspec.yaml` maps to Android versionName `1.0.0` and versionCode `1`; increment the build number for each upgrade, preserving the standard application ID `com.lendentracker.lenden_tracker` and its signing certificate. The `.acceptance` package is separate and is never the deliverable.

After an approved run succeeds, an authorized collaborator opens the Actions run, downloads artifact `lenden-tracker-standard-release-<run_id>` (retained **30 days**), and extracts `lenden-tracker-standard-release.apk` and `SHA256SUMS`. Run `sha256sum -c SHA256SUMS` in the extracted directory before copying the APK to the device. Obtain a fresh approved artifact if retention expired; do not substitute a debug APK. Enable Android's install-from-this-source permission for the trusted installer, then open the APK on a test device (or run `adb install -r lenden-tracker-standard-release.apk`). Disable that installer permission afterward. Check the signing certificate and package ID against the previously authorized release before an upgrade. A signed APK is not itself proof that installation or database migration succeeds.

**Release gate:** test a fresh installation and an in-place upgrade on a physical Android device using the real stable signing identity and higher versionCode; check launch, encrypted ledger continuity, and migration with a backed-up, consented test ledger. Do not erase a personal ledger or run destructive acceptance tests in the standard package. If the stable key, environment approval, actual artifact, or physical-device verification is absent, record the prerequisite and leave the release gate **unpassed**. iOS signing and distribution are separate and not covered by this workflow.
