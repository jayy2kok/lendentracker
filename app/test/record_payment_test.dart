import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lenden_tracker/data/repositories/repositories.dart';
import 'package:lenden_tracker/domain/entities/entities.dart';
import 'package:lenden_tracker/presentation/screens/record_payment/record_payment_screen.dart';

void main() {
  final now = DateTime(2026, 10, 17);
  final loan = Loan(
    id: 1,
    personId: 1,
    direction: LoanDirection.lent,
    principalMinor: 10000,
    currency: 'INR',
    startDate: '2026-10-01',
    interestMethod: InterestMethod.none,
    paymentSchedule: PaymentSchedule.flexible,
    status: LoanStatus.active,
    createdAt: now,
    updatedAt: now,
  );

  testWidgets('shows remaining principal preview and saves a payment', (
    tester,
  ) async {
    final repo = _PaymentRepositoryFake();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          paymentRepoProvider.overrideWithValue(repo),
          paymentContextProvider(
            1,
          ).overrideWith((ref) async => (loan: loan, outstandingMinor: 10000)),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const RecordPaymentScreen(loanId: 1),
                  ),
                ),
                child: const Text('Open payment'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open payment'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '25.50');
    await tester.pump();
    expect(find.textContaining('₹74.50'), findsOneWidget);
    await tester.tap(find.text('Save payment'));
    await tester.pumpAndSettle();
    expect(repo.saved?.principalMinor, 2550);
    expect(repo.saved?.interestMinor, 0);
    expect(find.text('Open payment'), findsOneWidget);
  });

  testWidgets('records interest-bearing payment using allocation preview', (
    tester,
  ) async {
    final interestLoan = Loan(
      id: 2,
      personId: 1,
      direction: LoanDirection.lent,
      principalMinor: 10000,
      currency: 'INR',
      startDate: '2026-10-01',
      interestMethod: InterestMethod.originalPrincipal,
      interestRate: 0.10,
      ratePeriod: RatePeriod.annual,
      paymentSchedule: PaymentSchedule.flexible,
      status: LoanStatus.active,
      createdAt: now,
      updatedAt: now,
    );

    final repo = _PaymentRepositoryFake();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          paymentRepoProvider.overrideWithValue(repo),
          paymentContextProvider(
            2,
          ).overrideWith((ref) async => (loan: interestLoan, outstandingMinor: 10000)),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const RecordPaymentScreen(loanId: 2),
                  ),
                ),
                child: const Text('Open interest payment'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open interest payment'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '25.50');
    await tester.pump();
    await tester.tap(find.text('Enter allocation manually'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'Interest portion'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Principal portion'), findsOneWidget);
    await tester.tap(find.text('Enter allocation manually'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save payment'));
    await tester.pumpAndSettle();
    expect(repo.saved?.totalMinor, 2550);
    expect(repo.saved?.principalMinor, 2500);
    expect(repo.saved?.interestMinor, 50);
  });

  testWidgets('rejects payment above outstanding principal', (tester) async {
    final repo = _PaymentRepositoryFake();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          paymentRepoProvider.overrideWithValue(repo),
          paymentContextProvider(
            1,
          ).overrideWith((ref) async => (loan: loan, outstandingMinor: 10000)),
        ],
        child: const MaterialApp(home: RecordPaymentScreen(loanId: 1)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '101');
    await tester.tap(find.text('Save payment'));
    await tester.pumpAndSettle();
    expect(repo.saved, isNull);
    expect(find.textContaining('outstanding'), findsWidgets);
  });
}

class _PaymentRepositoryFake implements PaymentRepository {
  Payment? saved;

  @override
  Future<Payment> recordNoInterest(Payment payment) async {
    saved = payment;
    return payment;
  }

  @override
  Future<PaymentAllocationPreview> previewAllocation(
    int loanId,
    String effectiveDate,
    int totalMinor, {
    int? excludingPaymentId,
  }) async {
    return PaymentAllocationPreview(
      accruedInterestMinor: 50,
      outstandingPrincipalMinor: 10000,
      principalMinor: totalMinor > 50 ? totalMinor - 50 : 0,
      interestMinor: totalMinor > 50 ? 50 : totalMinor,
      totalMinor: totalMinor,
    );
  }

  @override
  Future<Payment> recordInterestBearing(Payment payment) async {
    saved = payment;
    return payment;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
