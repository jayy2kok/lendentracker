import 'package:flutter_test/flutter_test.dart';
import 'package:lenden_tracker/domain/entities/entities.dart';
import 'package:lenden_tracker/domain/services/interest_calculator.dart';

void main() {
  const calculator = InterestCalculator();

  test(
    'monthly schedule preserves end-of-month anchor and appends maturity',
    () {
      final dates = calculator.monthlyDueDates(
        firstDueDate: DateTime(2026, 1, 31),
        maturityDate: DateTime(2026, 5, 15),
      );
      expect(dates, [
        DateTime(2026, 1, 31),
        DateTime(2026, 2, 28),
        DateTime(2026, 3, 31),
        DateTime(2026, 4, 30),
        DateTime(2026, 5, 15),
      ]);
    },
  );

  test('fixed portions distribute remainder exactly', () {
    final portions = calculator.allocateFixedInterest(1001, 3);
    expect(portions, [334, 334, 333]);
    expect(portions.fold<int>(0, (sum, value) => sum + value), 1001);
  });

  test(
    'monthly interest-only dues charge 1% and preserve month-end anchor',
    () {
      final dates = calculator.monthlyDueDates(
        firstDueDate: DateTime(2026, 1, 31),
        maturityDate: DateTime(2026, 3, 31),
      );
      final portions = calculator.interestOnlyPortions(
        principalMinor: 100000,
        startDate: '2025-12-31',
        dueDates: dates,
        method: InterestMethod.originalPrincipal,
        rate: 0.01,
        ratePeriod: RatePeriod.monthly,
      );
      expect(portions, [1000, 1000, 1000]);
    },
  );

  test(
    'remaining-principal interest-only dues include partial final month',
    () {
      final portions = calculator.interestOnlyPortions(
        principalMinor: 100000,
        startDate: '2026-01-01',
        dueDates: [DateTime(2026, 2, 1), DateTime(2026, 2, 15)],
        method: InterestMethod.remainingPrincipal,
        rate: 0.01,
        ratePeriod: RatePeriod.monthly,
      );
      expect(portions.first, 1000);
      expect(portions.last, greaterThan(0));
      expect(
        portions.reduce((a, b) => a + b),
        calculator.projectedInterest(
          principalMinor: 100000,
          fromDate: '2026-01-01',
          toDate: '2026-02-15',
          method: InterestMethod.remainingPrincipal,
          rate: 0.01,
          ratePeriod: RatePeriod.monthly,
          fixedInterestMinor: null,
          monthlyAnchorDate: '2026-01-01',
        ),
      );
    },
  );
}
