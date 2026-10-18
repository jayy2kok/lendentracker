import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/database/app_database.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/security/app_lock_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: LdenTrackerApp()));
}

class LdenTrackerApp extends ConsumerStatefulWidget {
  const LdenTrackerApp({super.key, this.initializeDatabase});

  final Future<void> Function()? initializeDatabase;

  @override
  ConsumerState<LdenTrackerApp> createState() => _LdenTrackerAppState();
}

class _LdenTrackerAppState extends ConsumerState<LdenTrackerApp>
    with WidgetsBindingObserver {
  bool _dbReady = false;
  bool _dbFailed = false;
  bool _lockReady = false;
  bool _locked = false;
  bool _authenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.read(themeProvider.notifier).load();
    _initApp();
  }

  Future<void> _initApp() async {
    setState(() {
      _dbReady = false;
      _dbFailed = false;
    });
    try {
      await (widget.initializeDatabase ?? AppDatabase.initialize)();
      if (!mounted) return;
      setState(() => _dbReady = true);
      await _initializeLock();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _dbReady = false;
        _dbFailed = true;
      });
    }
  }

  Future<void> _initializeLock() async {
    final notifier = ref.read(appLockProvider.notifier);
    await notifier.load();
    if (!mounted) return;
    setState(() {
      _lockReady = true;
      _locked = ref.read(appLockProvider);
    });
    if (_locked) _unlock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_lockReady || !ref.read(appLockProvider)) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      if (!_locked) setState(() => _locked = true);
    } else if (state == AppLifecycleState.resumed && _locked) {
      _unlock();
    }
  }

  Future<void> _unlock() async {
    if (_authenticating || !mounted) return;
    _authenticating = true;
    var authenticated = false;
    try {
      authenticated = await ref.read(appLockProvider.notifier).authenticate();
    } finally {
      _authenticating = false;
    }
    if (mounted && authenticated) setState(() => _locked = false);
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final router = ref.watch(routerProvider);

    if (!_dbReady) {
      return MaterialApp(
        title: 'LenDen Tracker',
        debugShowCheckedModeBanner: false,
        themeMode: themeMode,
        theme: ldtLightTheme(),
        darkTheme: ldtDarkTheme(),
        home: Scaffold(
          body: Center(
            child: !_dbFailed
                ? const CircularProgressIndicator()
                : Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Database initialization failed',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Your private ledger could not be opened. Check available storage and try again. Your saved data has not been deleted.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: _initApp,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      );
    }

    return MaterialApp.router(
      title: 'LenDen Tracker',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ldtLightTheme(),
      darkTheme: ldtDarkTheme(),
      routerConfig: router,
      builder: (context, child) {
        final content = child ?? const SizedBox.shrink();
        if (!_lockReady || _locked) {
          return Stack(
            fit: StackFit.expand,
            children: [
              AbsorbPointer(
                absorbing: true,
                child: ExcludeSemantics(child: content),
              ),
              const ColoredBox(color: Color(0xFFF7F6F2)),
              Center(
                child: !_lockReady
                    ? const CircularProgressIndicator()
                    : FilledButton.icon(
                        onPressed: _unlock,
                        icon: const Icon(Icons.lock_open),
                        label: const Text('Unlock LenDen Tracker'),
                      ),
              ),
            ],
          );
        }
        return content;
      },
    );
  }
}
