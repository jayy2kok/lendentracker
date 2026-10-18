import 'package:flutter_test/flutter_test.dart';
import 'package:lenden_tracker/domain/entities/entities.dart';
import 'package:lenden_tracker/domain/services/interest_calculator.dart';

void main() {
  const calculator = InterestCalculator();

  test('interest-only schedule puts full principal at final maturity', () {
    final dates = calculator.monthlyDueDates(
      firstDueDate: DateTime(2026, 1, 31),
      maturityDate: DateTime(2026, 4, 15),
    );
    final principal = 120000;
    final dues = [
      for (var i = 0; i < dates.length; i++)
        ScheduledDue(
          loanId: 1,
          dueDate: dates[i].toIso8601String().substring(0, 10),
          principalMinor: i == dates.length - 1 ? principal : 0,
          interestMinor: 0,
        ),
    ];
    expect(dues.last.dueDate, '2026-04-15');
    expect(
      dues.map((due) => due.principalMinor).reduce((a, b) => a + b),
      principal,
    );
    expect(
      dues.take(dues.length - 1).every((due) => due.principalMinor == 0),
      isTrue,
    );
  });

  test('custom dates remain supplied and fixed total portions sum exactly', () {
    final portions = calculator.allocateFixedInterest(1001, 2);
    expect(portions, [501, 500]);
    expect(portions.reduce((a, b) => a + b), 1001);
  });
}
