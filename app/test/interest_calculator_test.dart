import 'package:flutter_test/flutter_test.dart';
import 'package:lenden_tracker/domain/entities/entities.dart';
import 'package:lenden_tracker/domain/services/interest_calculator.dart';

void main() {
  const calc = InterestCalculator();

  group('InterestCalculator — no interest', () {
    test('returns zero regardless of dates', () {
      final r = calc.accruedInterest(
        startDate: '2026-01-01',
        asOfDate: '2026-06-01',
        principalMinor: 100000, // ₹1,000.00
        method: InterestMethod.none,
        rate: null,
        ratePeriod: null,
        fixedInterestMinor: null,
      );
      expect(r, 0);
    });
  });

  group('InterestCalculator — fixed total', () {
    test('returns the agreed fixed amount', () {
      final r = calc.accruedInterest(
        startDate: '2026-01-01',
        asOfDate: '2026-01-02',
        principalMinor: 100000,
        method: InterestMethod.fixedTotal,
        rate: null,
        ratePeriod: null,
        fixedInterestMinor: 5000,
      );
      expect(r, 5000);
    });
  });

  group('InterestCalculator — annual rate (actual/365)', () {
    test('365 days at 10% on ₹1,00,000 = ₹10,000', () {
      // 2026-01-01 to 2027-01-01 = 365 days
      final r = calc.accruedInterest(
        startDate: '2026-01-01',
        asOfDate: '2027-01-01',
        principalMinor: 10000000, // ₹1,00,000.00
        method: InterestMethod.originalPrincipal,
        rate: 0.10,
        ratePeriod: RatePeriod.annual,
        fixedInterestMinor: null,
      );
      expect(r, 1000000); // ₹10,000.00
    });

    test('half year at 10% = ₹5,000 (183 days)', () {
      // 2026-01-01 to 2026-07-03 = 183 days
      final r = calc.accruedInterest(
        startDate: '2026-01-01',
        asOfDate: '2026-07-03',
        principalMinor: 10000000,
        method: InterestMethod.originalPrincipal,
        rate: 0.10,
        ratePeriod: RatePeriod.annual,
        fixedInterestMinor: null,
      );
      // 10000000 * 0.10 * 183/365 = 501369.86 → 501370
      expect(r, 501370);
    });

    test('leap year: 2028-02-01 to 2028-02-29 = 28 days', () {
      final r = calc.accruedInterest(
        startDate: '2028-02-01',
        asOfDate: '2028-02-29',
        principalMinor: 10000000,
        method: InterestMethod.originalPrincipal,
        rate: 0.10,
        ratePeriod: RatePeriod.annual,
        fixedInterestMinor: null,
      );
      // 10000000 * 0.10 * 28/365 = 76712.33 → 76712
      expect(r, 76712);
    });
  });

  group('InterestCalculator — monthly rate (anniversary + prorate)', () {
    test('15 January to 15 February is one full anniversary period', () {
      expect(calc.accruedInterest(
        startDate: '2026-01-15',
        asOfDate: '2026-02-15',
        principalMinor: 100000,
        method: InterestMethod.originalPrincipal,
        rate: 0.02,
        ratePeriod: RatePeriod.monthly,
        fixedInterestMinor: null,
      ), 2000);
    });

    test('31 January to 31 March keeps original month-end anchor', () {
      expect(calc.accruedInterest(
        startDate: '2026-01-31',
        asOfDate: '2026-03-31',
        principalMinor: 100000,
        method: InterestMethod.originalPrincipal,
        rate: 0.02,
        ratePeriod: RatePeriod.monthly,
        fixedInterestMinor: null,
      ), 4000);
    });

    test('one full month at 2% = full 2%', () {
      // 2026-01-01 to 2026-02-01 = full January (31 days)
      final r = calc.accruedInterest(
        startDate: '2026-01-01',
        asOfDate: '2026-02-01',
        principalMinor: 10000000,
        method: InterestMethod.originalPrincipal,
        rate: 0.02,
        ratePeriod: RatePeriod.monthly,
        fixedInterestMinor: null,
      );
      expect(r, 200000); // ₹2,000.00
    });

    test('half of January (16 days) prorates to 16/31 of 2%', () {
      final r = calc.accruedInterest(
        startDate: '2026-01-01',
        asOfDate: '2026-01-17',
        principalMinor: 10000000,
        method: InterestMethod.originalPrincipal,
        rate: 0.02,
        ratePeriod: RatePeriod.monthly,
        fixedInterestMinor: null,
      );
      // 10000000 * 0.02 * 16/31 = 103225.8 → 103226
      expect(r, 103226);
    });

    test('month-end clamp: start 31st, full month lands on 28th in Feb', () {
      // 2026-01-31 + 1 month = 2026-02-28 (clamped)
      final r = calc.accruedInterest(
        startDate: '2026-01-31',
        asOfDate: '2026-02-28',
        principalMinor: 10000000,
        method: InterestMethod.originalPrincipal,
        rate: 0.02,
        ratePeriod: RatePeriod.monthly,
        fixedInterestMinor: null,
      );
      // period = 28 days over 28-day Feb → full 2%
      expect(r, 200000);
    });
  });

  group('InterestCalculator — allocation', () {
    test('interest-first default', () {
      final r = calc.allocate(
        paymentTotal: 100000,
        outstandingPrincipal: 500000,
        accruedInterest: 30000,
      );
      expect(r.interest, 30000);
      expect(r.principal, 70000);
    });

    test('payment smaller than accrued interest goes all to interest', () {
      final r = calc.allocate(
        paymentTotal: 20000,
        outstandingPrincipal: 500000,
        accruedInterest: 30000,
      );
      expect(r.interest, 20000);
      expect(r.principal, 0);
    });

    test('explicit allocation must equal total', () {
      expect(
        () => calc.allocate(
          paymentTotal: 100000,
          outstandingPrincipal: 500000,
          accruedInterest: 30000,
          explicitPrincipal: 40000,
          explicitInterest: 50000, // sums to 90000, not 100000
        ),
        throwsArgumentError,
      );
    });

    test('principal allocation cannot exceed outstanding', () {
      expect(
        () => calc.allocate(
          paymentTotal: 100000,
          outstandingPrincipal: 50000,
          accruedInterest: 30000,
        ),
        throwsArgumentError,
      );
    });
  });
}
