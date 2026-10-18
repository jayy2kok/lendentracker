import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lenden_tracker/core/database/app_database.dart';
import 'package:lenden_tracker/data/repositories/repositories.dart';
import 'package:lenden_tracker/domain/entities/entities.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('failed schedule insert rolls back new person and loan', (
    tester,
  ) async {
    expect(
      (await getApplicationDocumentsDirectory()).path,
      contains('.acceptance'),
    );
    await AppDatabase.initialize();
    final original = await AppDatabase.instance.exportSnapshot();
    final db = AppDatabase.instance.db;
    const phone = '+12025550125';
    try {
      await db.execute('''
        CREATE TEMP TRIGGER reject_schedule_insert
        BEFORE INSERT ON scheduled_dues
        BEGIN SELECT RAISE(ABORT, 'forced schedule insert failure'); END
      ''');
      final now = DateTime.now();
      final repository = LoanRepository(db: db);
      await expectLater(
        repository.createWithPerson(
          name: 'Atomicity test contact',
          phone: phone,
          contactId: 'atomicity-test',
          loan: Loan(
            personId: 0,
            direction: LoanDirection.lent,
            principalMinor: 10000,
            currency: 'INR',
            startDate: '2026-10-01',
            maturityDate: '2026-11-01',
            interestMethod: InterestMethod.none,
            paymentSchedule: PaymentSchedule.regular,
            status: LoanStatus.active,
            createdAt: now,
            updatedAt: now,
          ),
          schedule: const [
            ScheduledDue(
              loanId: 0,
              dueDate: '2026-11-01',
              principalMinor: 10000,
              interestMinor: 0,
            ),
          ],
        ),
        throwsA(
          predicate(
            (error) =>
                error.toString().contains('forced schedule insert failure'),
          ),
        ),
      );
      expect(
        await db.query('people', where: 'phone_e164 = ?', whereArgs: [phone]),
        isEmpty,
      );
      expect(
        await db.query(
          'loans',
          where: 'principal_minor = ?',
          whereArgs: [10000],
        ),
        isEmpty,
      );
    } finally {
      await db.execute('DROP TRIGGER IF EXISTS reject_schedule_insert');
      final now = DateTime.now();
      final loanId = await LoanRepository(db: db).createWithPerson(
        name: 'Successful atomicity test contact',
        phone: '+12025550126',
        contactId: 'atomicity-success',
        loan: Loan(
          personId: 0,
          direction: LoanDirection.lent,
          principalMinor: 10000,
          currency: 'INR',
          startDate: '2026-10-01',
          maturityDate: '2026-11-01',
          interestMethod: InterestMethod.none,
          paymentSchedule: PaymentSchedule.regular,
          status: LoanStatus.active,
          createdAt: now,
          updatedAt: now,
        ),
        schedule: const [
          ScheduledDue(
            loanId: 0,
            dueDate: '2026-11-01',
            principalMinor: 10000,
            interestMinor: 0,
          ),
        ],
      );
      final savedDues = await LoanRepository(db: db).duesForLoan(loanId);
      expect(savedDues, hasLength(1));
      expect(savedDues.single.loanId, loanId);
      await AppDatabase.restoreFromBytes(original);
      await AppDatabase.instance.close();
    }
  });
}
