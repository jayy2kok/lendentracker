import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lenden_tracker/core/security/app_lock_provider.dart';
import 'package:lenden_tracker/core/router/app_router.dart';
import 'package:lenden_tracker/core/theme/theme_provider.dart';
import 'package:lenden_tracker/main.dart';

final _testRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/draft',
    routes: [GoRoute(path: '/draft', builder: (_, _) => const _DraftScreen())],
  );
  ref.onDispose(router.dispose);
  return router;
});

class _DraftScreen extends StatefulWidget {
  const _DraftScreen();

  @override
  State<_DraftScreen> createState() => _DraftScreenState();
}

class _DraftScreenState extends State<_DraftScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: TextField(controller: _controller, key: const ValueKey('draft')),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app lock hides and blocks UI without disposing route draft', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        routerProvider.overrideWith((ref) => ref.watch(_testRouterProvider)),
        appLockProvider.overrideWith(_LockedNotifier.new),
        themeProvider.overrideWith(_ThemeNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: LdenTrackerApp(initializeDatabase: () async {}),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('draft')), 'unsaved note');

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(find.text('unsaved note', skipOffstage: false), findsOneWidget);
    expect(find.text('Unlock LenDen Tracker'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('draft')))
          .controller!
          .text,
      'unsaved note',
    );

    await tester.tap(find.text('Unlock LenDen Tracker'));
    await tester.pumpAndSettle();
    expect(find.text('unsaved note'), findsOneWidget);
  });
}

class _LockedNotifier extends AppLockNotifier {
  @override
  bool build() => true;

  @override
  Future<void> load() async => state = true;

  @override
  Future<bool> authenticate() async => true;
}

class _ThemeNotifier extends ThemeNotifier {
  @override
  ThemeMode build() => ThemeMode.light;

  @override
  Future<void> load() async {}
}
