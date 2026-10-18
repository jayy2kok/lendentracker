import 'package:flutter_test/flutter_test.dart';
import 'package:lenden_tracker/domain/entities/entities.dart';
import 'package:lenden_tracker/domain/services/interest_calculator.dart';

void main() {
  const calculator = InterestCalculator();

  test('monthly partial segments preserve original anchor', () {
    final split = calculator.accruedInterest(
      startDate: '2026-01-31',
      asOfDate: '2026-02-28',
      principalMinor: 100000,
      method: InterestMethod.originalPrincipal,
      rate: 0.02,
      ratePeriod: RatePeriod.monthly,
      fixedInterestMinor: null,
      monthlyAnchorDate: '2026-01-31',
    );
    expect(split, 2000);
  });

  test('interest stops at maturity unless continuation is explicit', () {
    final stopped = calculator.accruedInterest(
      startDate: '2026-01-01',
      asOfDate: '2026-04-01',
      principalMinor: 100000,
      method: InterestMethod.originalPrincipal,
      rate: 0.1,
      ratePeriod: RatePeriod.annual,
      fixedInterestMinor: null,
      maturityDate: '2026-02-01',
    );
    final continued = calculator.accruedInterest(
      startDate: '2026-01-01',
      asOfDate: '2026-04-01',
      principalMinor: 100000,
      method: InterestMethod.originalPrincipal,
      rate: 0.1,
      ratePeriod: RatePeriod.annual,
      fixedInterestMinor: null,
      maturityDate: '2026-02-01',
      continueAfterMaturity: true,
    );
    expect(stopped, 849);
    expect(continued, 2466);
  });

  test('manual allocation validates total, bounds, and interest accrued', () {
    expect(
      () => calculator.allocate(
        paymentTotal: 100,
        outstandingPrincipal: 1000,
        accruedInterest: 50,
        explicitPrincipal: 0,
        explicitInterest: 100,
      ),
      throwsArgumentError,
    );
  });
}
