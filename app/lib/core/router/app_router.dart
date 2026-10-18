import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../presentation/screens/welcome/welcome_screen.dart';
import '../../presentation/screens/home/home_screen.dart';
import '../../presentation/screens/loans/loans_screen.dart';
import '../../presentation/screens/loan_detail/loan_detail_screen.dart';
import '../../presentation/screens/add_loan/add_loan_flow.dart';
import '../../presentation/screens/record_payment/record_payment_screen.dart';
import '../../presentation/screens/reminder/reminder_preview_screen.dart';
import '../../presentation/screens/settings/settings_screen.dart';
import '../../presentation/widgets/scaffold_with_nav.dart';

abstract final class AppRoutes {
  static const welcome = '/welcome';
  static const home = '/home';
  static const loans = '/loans';
  static const loanDetail = '/loans/:id';
  static const addLoan = '/loans/add';
  static const recordPayment = '/loans/:id/payment';
  static const reminder = '/loans/:id/reminder';
  static const settings = '/settings';
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    redirect: (context, state) async {
      final prefs = await SharedPreferences.getInstance();
      final hasLedger = prefs.getBool('ledger_created') ?? false;
      if (!hasLedger && state.matchedLocation != AppRoutes.welcome) {
        return AppRoutes.welcome;
      }
      if (hasLedger && state.matchedLocation == AppRoutes.welcome) {
        return AppRoutes.home;
      }
      return null;
    },
    debugLogDiagnostics: false,
    routes: [
      GoRoute(
        path: AppRoutes.welcome,
        builder: (_, st) => const WelcomeScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            ScaffoldWithNav(state: state, child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            pageBuilder: (_, st) => NoTransitionPage(child: const HomeScreen()),
          ),
          GoRoute(
            path: AppRoutes.loans,
            pageBuilder: (_, st) =>
                NoTransitionPage(child: const LoansScreen()),
            routes: [
              GoRoute(path: 'add', builder: (_, st) => const AddLoanFlow()),
              GoRoute(
                path: ':id',
                builder: (ctx, state) => LoanDetailScreen(
                  loanId: int.parse(state.pathParameters['id']!),
                ),
                routes: [
                  GoRoute(
                    path: 'payment',
                    builder: (ctx, state) => RecordPaymentScreen(
                      loanId: int.parse(state.pathParameters['id']!),
                    ),
                  ),
                  GoRoute(
                    path: 'reminder',
                    builder: (ctx, state) => ReminderPreviewScreen(
                      loanId: int.parse(state.pathParameters['id']!),
                    ),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.settings,
            pageBuilder: (_, st) =>
                NoTransitionPage(child: const SettingsScreen()),
          ),
        ],
      ),
    ],
  );
});
