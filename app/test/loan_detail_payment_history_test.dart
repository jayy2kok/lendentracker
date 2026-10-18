import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lenden_tracker/data/repositories/repositories.dart';
import 'package:lenden_tracker/domain/entities/entities.dart';
import 'package:lenden_tracker/presentation/screens/loan_detail/loan_detail_screen.dart';
import 'package:lenden_tracker/presentation/screens/record_payment/record_payment_screen.dart';

void main() {
  final now = DateTime(2026, 10, 17);

  Loan loan({int outstanding = 10000}) => Loan(
    id: 1,
    personId: 1,
    direction: LoanDirection.lent,
    principalMinor: 10000,
    currency: 'INR',
    startDate: '2026-10-01',
    interestMethod: InterestMethod.none,
    paymentSchedule: PaymentSchedule.flexible,
    status: outstanding <= 0 ? LoanStatus.settled : LoanStatus.active,
    createdAt: now,
    updatedAt: now,
  );

  testWidgets('shows unpaid interest instead of total accrued interest', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          paymentContextProvider(1).overrideWith(
            (ref) async => (loan: loan(), outstandingMinor: 10000),
          ),
          interestDueProvider(1).overrideWith((ref) async => 9677),
          loanDetailProvider(1).overrideWith(
            (ref) async => (
              loan: Loan(
                id: 1,
                personId: 1,
                direction: LoanDirection.lent,
                principalMinor: 20000000,
                currency: 'INR',
                startDate: '2026-01-01',
                interestMethod: InterestMethod.originalPrincipal,
                paymentSchedule: PaymentSchedule.interestOnly,
                status: LoanStatus.active,
                createdAt: now,
                updatedAt: now,
              ),
              person: null,
            ),
          ),
        ],
        child: const MaterialApp(home: LoanDetailScreen(loanId: 1)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Interest due: ₹96.77'), findsOneWidget);
    expect(find.textContaining('₹19,096.77'), findsNothing);
  });

  testWidgets('shows payment history entries', (tester) async {
    final repo = _PaymentRepoFake([
      Payment(
        id: 1,
        loanId: 1,
        effectiveDate: '2026-10-10',
        totalMinor: 3000,
        principalMinor: 3000,
        interestMinor: 0,
        createdAt: DateTime(2026),
      ),
    ]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          paymentRepoProvider.overrideWithValue(repo),
          loanDetailProvider(1).overrideWith(
            (ref) async => (
              loan: loan(outstanding: 7000),
              person: Person(
                displayName: 'Test',
                phoneE164: '+911234567890',
                createdAt: DateTime(2026),
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: LoanDetailScreen(loanId: 1)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('2026-10-10'), findsOneWidget);
    expect(find.text('principal ₹30.00'), findsOneWidget);
    expect(find.text('₹30.00'), findsOneWidget);
    expect(find.text('Reversed'), findsNothing);
  });

  testWidgets('shows empty history message', (tester) async {
    final repo = _PaymentRepoFake([]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          paymentRepoProvider.overrideWithValue(repo),
          loanDetailProvider(1).overrideWith(
            (ref) async => (
              loan: loan(),
              person: Person(
                displayName: 'Test',
                phoneE164: '+911234567890',
                createdAt: DateTime(2026),
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: LoanDetailScreen(loanId: 1)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('No payments recorded'), findsOneWidget);
  });

  testWidgets('labels reversed payments', (tester) async {
    final repo = _PaymentRepoFake([
      Payment(
        id: 2,
        loanId: 1,
        effectiveDate: '2026-10-12',
        totalMinor: 1000,
        principalMinor: 1000,
        interestMinor: 0,
        reversed: true,
        createdAt: DateTime(2026),
      ),
    ]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          paymentRepoProvider.overrideWithValue(repo),
          loanDetailProvider(1).overrideWith(
            (ref) async => (
              loan: loan(outstanding: 9000),
              person: Person(
                displayName: 'Test',
                phoneE164: '+911234567890',
                createdAt: DateTime(2026),
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: LoanDetailScreen(loanId: 1)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Reversed'), findsOneWidget);
  });
  testWidgets('shows edit and reverse buttons on active payments', (
    tester,
  ) async {
    final repo = _PaymentRepoFake([
      Payment(
        id: 1,
        loanId: 1,
        effectiveDate: '2026-10-10',
        totalMinor: 3000,
        principalMinor: 3000,
        interestMinor: 0,
        createdAt: DateTime(2026),
      ),
    ]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          paymentRepoProvider.overrideWithValue(repo),
          loanDetailProvider(1).overrideWith(
            (ref) async => (
              loan: loan(outstanding: 7000),
              person: Person(
                displayName: 'Test',
                phoneE164: '+911234567890',
                createdAt: DateTime(2026),
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: LoanDetailScreen(loanId: 1)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(find.byIcon(Icons.undo_outlined), findsOneWidget);
  });

  testWidgets('shows three loan detail tabs', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          loanDetailProvider(1).overrideWith(
            (ref) async => (
              loan: loan(),
              person: Person(
                displayName: 'Test',
                phoneE164: '+911234567890',
                createdAt: DateTime(2026),
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: LoanDetailScreen(loanId: 1)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Schedule'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Original agreement'), findsOneWidget);
  });

  testWidgets('history tab retains payment history', (tester) async {
    final repo = _PaymentRepoFake([]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          paymentRepoProvider.overrideWithValue(repo),
          loanDetailProvider(1).overrideWith(
            (ref) async => (
              loan: loan(),
              person: Person(
                displayName: 'Test',
                phoneE164: '+911234567890',
                createdAt: DateTime(2026),
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: LoanDetailScreen(loanId: 1)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('No payments recorded'), findsOneWidget);
  });

  testWidgets('confirming a waiver closes the dialog without widget errors', (
    tester,
  ) async {
    final repo = _WaiverRepoFake();
    final interestLoan = Loan(
      id: 1,
      personId: 1,
      direction: LoanDirection.lent,
      principalMinor: 10000,
      currency: 'INR',
      startDate: '2026-10-01',
      interestMethod: InterestMethod.originalPrincipal,
      paymentSchedule: PaymentSchedule.flexible,
      status: LoanStatus.active,
      createdAt: now,
      updatedAt: now,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          paymentRepoProvider.overrideWithValue(repo),
          paymentContextProvider(1).overrideWith(
            (ref) async => (loan: interestLoan, outstandingMinor: 10000),
          ),
          interestDueProvider(1).overrideWith((ref) async => 500),
          loanDetailProvider(1).overrideWith(
            (ref) async => (loan: interestLoan, person: null),
          ),
        ],
        child: const MaterialApp(home: LoanDetailScreen(loanId: 1)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Waive interest'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, '1');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm waiver'));
    await tester.pumpAndSettle();

    expect(repo.waiver?.amountMinor, 100);
    expect(find.text('Confirm waiver'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _PaymentRepoFake implements PaymentRepository {
  _PaymentRepoFake(this._payments);
  final List<Payment> _payments;

  @override
  Future<List<Payment>> forLoan(int loanId) async => _payments;

  @override
  Future<Payment> recordNoInterest(Payment payment) async {
    _payments.add(payment);
    return payment;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _WaiverRepoFake extends _PaymentRepoFake {
  _WaiverRepoFake() : super([]);

  InterestWaiver? waiver;

  @override
  Future<WaiverPreview> previewWaiver(int loanId, String date, int amountMinor) async =>
      const WaiverPreview(
        accruedInterestMinor: 500,
        waivedBeforeMinor: 0,
        waivedAfterMinor: 100,
        remainingInterestMinor: 400,
      );

  @override
  Future<int> waiveInterest(InterestWaiver value) async {
    waiver = value;
    return 1;
  }
}
