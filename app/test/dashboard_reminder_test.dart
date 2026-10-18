import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:screenshot/screenshot.dart';
import 'package:lenden_tracker/data/repositories/repositories.dart';
import 'package:lenden_tracker/domain/entities/entities.dart';
import 'package:lenden_tracker/presentation/screens/home/home_screen.dart';
import 'package:lenden_tracker/presentation/screens/loans/loans_screen.dart';
import 'package:lenden_tracker/presentation/screens/reminder/reminder_preview_screen.dart';

void main() {
  final now = DateTime(2026, 10, 18);
  final loanInr = Loan(
    id: 1,
    personId: 1,
    direction: LoanDirection.lent,
    principalMinor: 100000,
    currency: 'INR',
    startDate: '2026-01-01',
    maturityDate: '2026-10-01',
    interestMethod: InterestMethod.none,
    paymentSchedule: PaymentSchedule.atMaturity,
    status: LoanStatus.active,
    createdAt: now,
    updatedAt: now,
  );
  final loanUsd = Loan(
    id: 2,
    personId: 2,
    direction: LoanDirection.borrowed,
    principalMinor: 25000,
    currency: 'USD',
    startDate: '2026-02-01',
    maturityDate: '2026-12-01',
    interestMethod: InterestMethod.none,
    paymentSchedule: PaymentSchedule.atMaturity,
    status: LoanStatus.active,
    createdAt: now,
    updatedAt: now,
  );
  final items = [
    LoanListItem(loanInr, 'Alice', overdueCount: 1, nextDueMinor: 100000),
    LoanListItem(
      loanUsd,
      'Bob',
      nextDueDate: '2026-12-01',
      nextDueMinor: 25000,
    ),
  ];

  testWidgets('dashboard separates currencies and shows due and overdue rows', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          principalBalancesProvider.overrideWith(
            (ref) async => const [
              PrincipalBalance(
                currency: 'INR',
                direction: LoanDirection.lent,
                amountMinor: 100000,
              ),
              PrincipalBalance(
                currency: 'USD',
                direction: LoanDirection.borrowed,
                amountMinor: 25000,
              ),
            ],
          ),
          homeSummariesProvider.overrideWith((ref) async => items),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
    final aliceDueTile = find.ancestor(
      of: find.text('1 overdue payment'),
      matching: find.byType(ListTile),
    );
    expect(
      find.descendant(of: aliceDueTile, matching: find.text('₹1,000.00')),
      findsOneWidget,
    );
    expect(find.textContaining('₹1,000.00'), findsNWidgets(2));
    final bobDueTile = find.ancestor(
      of: find.text('Due 2026-12-01'),
      matching: find.byType(ListTile),
    );
    expect(
      find.descendant(of: bobDueTile, matching: find.text('\$250.00')),
      findsOneWidget,
    );
    expect(find.text('1 overdue payment'), findsOneWidget);
    expect(find.text('Due 2026-12-01'), findsOneWidget);
  });

  testWidgets('loan filters narrow by direction, status, currency and search', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [loansProvider.overrideWith((ref) async => items)],
        child: const MaterialApp(home: LoansScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    await tester.tap(find.text('All').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Borrowed'));
    await tester.pumpAndSettle();
    expect(find.text('Alice'), findsNothing);
    expect(find.text('Bob'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'no match');
    await tester.pumpAndSettle();
    expect(find.text('No matching loans.'), findsOneWidget);
  });

  testWidgets(
    'reminder image omits phone and private notes and preview identifies recipient',
    (tester) async {
      final privateLoan = loanInr.copyWith(notes: 'SECRET PRIVATE NOTE');
      final item = LoanListItem(privateLoan, 'Alice');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            reminderLoanProvider(1).overrideWith(
              (ref) async => ReminderPreviewData(
                item: item,
                phone: '+15551234567',
                outstandingPrincipalMinor: 50000,
                nextDueDate: '2026-12-01',
                duePrincipalMinor: 50000,
                scheduledPrincipalMinor: 50000,
                scheduledInterestMinor: 0,
                dueInterestMinor: 0,
                currentDueMinor: 100000,
              ),
            ),
          ],
          child: const MaterialApp(home: ReminderPreviewScreen(loanId: 1)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('To: Alice'), findsOneWidget);
      expect(find.textContaining('SECRET PRIVATE NOTE'), findsNothing);
      expect(find.textContaining('+15551234567'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(Screenshot),
          matching: find.textContaining('+15551234567'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(Screenshot),
          matching: find.textContaining('SECRET PRIVATE NOTE'),
        ),
        findsNothing,
      );
      expect(find.textContaining('Loan reference #1'), findsOneWidget);
      expect(find.textContaining('Outstanding principal'), findsOneWidget);
      expect(find.textContaining('Current due:'), findsWidgets);
      expect(find.text('Optional caption'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Save image'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Save image'), findsOneWidget);
      expect(find.text('Share reminder'), findsOneWidget);
    },
  );
}
