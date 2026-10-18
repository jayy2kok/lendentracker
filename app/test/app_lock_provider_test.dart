import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lenden_tracker/core/security/app_lock_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'app_lock_enabled': true});
  });

  test(
    'loads enabled lock and authenticate fails closed without platform auth',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(appLockProvider), isFalse);
      await container.read(appLockProvider.notifier).load();
      expect(container.read(appLockProvider), isTrue);
      expect(
        await container.read(appLockProvider.notifier).authenticate(),
        isFalse,
      );
    },
  );

  test(
    'disabled lock lets app continue without invoking platform auth',
    () async {
      SharedPreferences.setMockInitialValues({'app_lock_enabled': false});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(appLockProvider.notifier).load();
      expect(
        await container.read(appLockProvider.notifier).authenticate(),
        isTrue,
      );
    },
  );
}
