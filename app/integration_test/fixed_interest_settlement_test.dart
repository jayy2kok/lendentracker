import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lenden_tracker/core/database/app_database.dart';
import 'package:lenden_tracker/data/repositories/repositories.dart';
import 'package:lenden_tracker/domain/entities/entities.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'fixed interest remains outstanding through principal payoff, waiver and reversal',
    (tester) async {
      expect(
        (await getApplicationDocumentsDirectory()).path,
        contains('.acceptance'),
      );
      await AppDatabase.initialize();
      final snapshot = await AppDatabase.instance.exportSnapshot();
      try {
        final loans = LoanRepository(db: AppDatabase.instance.db);
        final payments = PaymentRepository(db: AppDatabase.instance.db);
        final today = DateTime.now();
        String date(DateTime value) => value.toIso8601String().substring(0, 10);
        final start = date(today.subtract(const Duration(days: 1)));
        final asOf = date(today);
        final maturity = date(today.add(const Duration(days: 30)));
        Future<int> create() => loans.createWithPerson(
          name: 'Synthetic fixed-interest settlement test',
          phone: '+120****0199',
          contactId: 'fixed-interest-test',
          loan: Loan(
            personId: 0,
            direction: LoanDirection.lent,
            principalMinor: 5000000,
            currency: 'INR',
            startDate: start,
            maturityDate: maturity,
            interestMethod: InterestMethod.fixedTotal,
            fixedInterestMinor: 500000,
            paymentSchedule: PaymentSchedule.flexible,
            status: LoanStatus.active,
            createdAt: today,
            updatedAt: today,
          ),
        );
        Future<Payment> pay(int loanId, String effectiveDate, int total) async {
          final preview = await payments.previewAllocation(
            loanId,
            effectiveDate,
            total,
          );
          return payments.recordInterestBearing(
            Payment(
              loanId: loanId,
              effectiveDate: effectiveDate,
              totalMinor: total,
              principalMinor: preview.principalMinor,
              interestMinor: preview.interestMinor,
              createdAt: today,
            ),
          );
        }

        Future<void> check(
          int id,
          LoanStatus status,
          int principal,
          int due,
          int future,
        ) async {
          expect((await loans.getById(id))!.status, status);
          expect(await payments.outstandingPrincipal(id), principal);
          final balance = await payments.interestBalance(id, asOf);
          expect(balance.dueMinor, due);
          expect(balance.futureMinor, future);
        }

        final id = await create();
        await pay(id, start, 2500000);
        await check(id, LoanStatus.active, 2500000, 0, 500000);
        await expectLater(loans.settle(id), throwsStateError);

        final principalPayment = await pay(id, start, 2500000);
        await check(id, LoanStatus.active, 0, 0, 500000);
        await expectLater(loans.settle(id), throwsStateError);

        final interestPayment = await pay(id, asOf, 500000);
        await check(id, LoanStatus.settled, 0, 0, 0);
        await payments.reverse(interestPayment.id!, 'Synthetic interest reversal');
        await check(id, LoanStatus.active, 0, 0, 500000);
        await payments.reverse(principalPayment.id!, 'Synthetic principal reversal');
        await check(id, LoanStatus.active, 2500000, 0, 500000);

        final waivedId = await create();
        await pay(waivedId, start, 5000000);
        await check(waivedId, LoanStatus.active, 0, 0, 500000);
        await payments.waiveInterest(
          InterestWaiver(
            loanId: waivedId,
            waiverDate: asOf,
            amountMinor: 500000,
          ),
        );
        await check(waivedId, LoanStatus.settled, 0, 0, 0);
      } finally {
        await AppDatabase.restoreFromBytes(snapshot);
        await AppDatabase.instance.close();
      }
    },
  );
}
