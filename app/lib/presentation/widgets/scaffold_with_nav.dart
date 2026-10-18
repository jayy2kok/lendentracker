import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../core/router/app_router.dart';

class ScaffoldWithNav extends StatelessWidget {
  const ScaffoldWithNav({
    super.key,
    required this.state,
    required this.child,
  });

  final GoRouterState state;
  final Widget child;

  static const _tabs = [
    (path: AppRoutes.home, label: 'Home', icon: Icons.account_balance_wallet_outlined, selectedIcon: Icons.account_balance_wallet),
    (path: AppRoutes.loans, label: 'Loans', icon: Icons.swap_horiz_outlined, selectedIcon: Icons.swap_horiz),
    (path: AppRoutes.settings, label: 'Settings', icon: Icons.settings_outlined, selectedIcon: Icons.settings),
  ];

  int _selectedIndex(GoRouterState state) {
    final loc = state.matchedLocation;
    if (loc.startsWith(AppRoutes.loans)) return 1;
    if (loc.startsWith(AppRoutes.settings)) return 2;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final idx = _selectedIndex(state);
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected: (i) => context.go(_tabs[i].path),
        destinations: [
          for (final tab in _tabs)
            NavigationDestination(
              icon: Icon(tab.icon),
              selectedIcon: Icon(tab.selectedIcon, color: LdtColors.primary),
              label: tab.label,
            ),
        ],
      ),
    );
  }
}
