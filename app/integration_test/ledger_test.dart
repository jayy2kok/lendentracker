import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lenden_tracker/core/database/app_database.dart';
import 'package:lenden_tracker/data/repositories/repositories.dart';
import 'package:lenden_tracker/domain/entities/entities.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native ledger payments reverse and survive encrypted restart', (
    tester,
  ) async {
    expect(
      (await getApplicationDocumentsDirectory()).path,
      contains('.acceptance'),
    );
    await AppDatabase.initialize();
    final original = await AppDatabase.instance.exportSnapshot();
    try {
      final loans = LoanRepository(db: AppDatabase.instance.db);
      final payments = PaymentRepository(db: AppDatabase.instance.db);
      final now = DateTime.now();
      final date = now.toIso8601String().substring(0, 10);
      for (final direction in LoanDirection.values) {
        final id = await loans.createWithPerson(
          name: 'Synthetic ledger test',
          phone: '+12025550124',
          contactId: 'test',
          loan: Loan(
            personId: 0,
            direction: direction,
            principalMinor: 10000,
            currency: 'INR',
            startDate: date,
            interestMethod: InterestMethod.none,
            paymentSchedule: PaymentSchedule.flexible,
            status: LoanStatus.active,
            createdAt: now,
            updatedAt: now,
          ),
        );
        final payment = await payments.recordNoInterest(
          Payment(
            loanId: id,
            effectiveDate: date,
            totalMinor: 2500,
            principalMinor: 2500,
            interestMinor: 0,
            createdAt: now,
          ),
        );
        expect(await payments.outstandingPrincipal(id), 7500);
        await expectLater(
          payments.reverse(payment.id!, '   '),
          throwsArgumentError,
        );
        expect(await payments.outstandingPrincipal(id), 7500);
        expect((await payments.forLoan(id)).single.reversed, isFalse);
        await payments.reverse(payment.id!, 'Duplicate entry');
        expect(await payments.outstandingPrincipal(id), 10000);
        final reversed = (await payments.forLoan(id)).single;
        expect(reversed.reversed, isTrue);
        expect(reversed.reversalReason, 'Duplicate entry');
      }
      final interestLoanId = await loans.createWithPerson(
        name: 'Synthetic interest test',
        phone: '+12025550126',
        contactId: 'interest-test',
        loan: Loan(
          personId: 0,
          direction: LoanDirection.lent,
          principalMinor: 10000,
          currency: 'INR',
          startDate: date,
          interestMethod: InterestMethod.fixedTotal,
          fixedInterestMinor: 500,
          paymentSchedule: PaymentSchedule.flexible,
          status: LoanStatus.active,
          createdAt: now,
          updatedAt: now,
        ),
      );
      final preview = await payments.previewAllocation(
        interestLoanId,
        date,
        2500,
      );
      expect(preview.outstandingPrincipalMinor, 10000);
      final interestPayment = await payments.recordInterestBearing(
        Payment(
          loanId: interestLoanId,
          effectiveDate: date,
          totalMinor: 2500,
          principalMinor: preview.principalMinor,
          interestMinor: preview.interestMinor,
          createdAt: now,
        ),
      );
      expect(interestPayment.id, isNotNull);
      expect(await payments.interestDue(interestLoanId, date), 0);
      expect(
        await payments.outstandingPrincipal(interestLoanId),
        10000 - preview.principalMinor,
      );
      final populated = jsonDecode(
        utf8.decode(await AppDatabase.instance.exportSnapshot()),
      );
      await AppDatabase.instance.close();
      await AppDatabase.initialize();
      expect(
        jsonDecode(utf8.decode(await AppDatabase.instance.exportSnapshot())),
        populated,
      );
    } finally {
      await AppDatabase.restoreFromBytes(original);
      await AppDatabase.instance.close();
    }
  });
}
