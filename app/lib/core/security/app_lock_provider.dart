import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kAppLockKey = 'app_lock_enabled';

class AppLockNotifier extends Notifier<bool> {
  final LocalAuthentication _auth = LocalAuthentication();

  @override
  bool build() => false;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_kAppLockKey) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    if (enabled) {
      // Test if device can authenticate before enabling
      try {
        final canAuth =
            await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
        if (!canAuth) return;
        final authenticated = await _auth.authenticate(
          localizedReason: 'Authenticate to enable App Lock',
          options: const AuthenticationOptions(stickyAuth: true),
        );
        if (!authenticated) return;
      } catch (_) {
        return;
      }
    }
    state = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAppLockKey, enabled);
  }

  Future<bool> authenticate() async {
    if (!state) return true;
    try {
      return await _auth.authenticate(
        localizedReason: 'Unlock LenDen Tracker',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}

final appLockProvider = NotifierProvider<AppLockNotifier, bool>(
  AppLockNotifier.new,
);
