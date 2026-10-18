import '../entities/entities.dart';

/// Deterministic interest calculation engine per PLAN.md.
///
/// Conventions:
/// - Annual rates: actual days / 365
/// - Monthly rates: full % for anniversary period, prorate partial by actual days in period
/// - All amounts in integer minor units; rates in decimal
/// - Uses local calendar dates, not elapsed timestamp hours
/// - Clamp unavailable month-end dates while preserving original schedule anchor

class InterestCalculator {
  const InterestCalculator();

  /// Generate due dates from a first-payment anchor, clamping unavailable days
  /// to month end without drifting the original day-of-month anchor.
  List<DateTime> monthlyDueDates({
    required DateTime firstDueDate,
    required DateTime maturityDate,
  }) {
    final dates = <DateTime>[];
    final anchor = DateTime(
      firstDueDate.year,
      firstDueDate.month,
      firstDueDate.day,
    );
    for (var month = 0; ; month++) {
      final due = _addMonths(anchor, month);
      if (due.isAfter(maturityDate)) break;
      dates.add(due);
      if (due.isAtSameMomentAs(maturityDate)) break;
    }
    if (dates.isEmpty || !dates.last.isAtSameMomentAs(maturityDate)) {
      dates.add(
        DateTime(maturityDate.year, maturityDate.month, maturityDate.day),
      );
    }
    return dates;
  }

  /// Split fixed interest evenly in minor units, assigning any remainder to
  /// the earliest installments so that all portions sum exactly to the total.
  List<int> allocateFixedInterest(int totalMinor, int installments) {
    if (totalMinor < 0 || installments <= 0) {
      throw ArgumentError(
        'Positive installment count and nonnegative interest required',
      );
    }
    final base = totalMinor ~/ installments;
    final remainder = totalMinor % installments;
    return List<int>.generate(
      installments,
      (i) => base + (i < remainder ? 1 : 0),
    );
  }

  /// Interest due at each interest-only payment date. Subtract cumulative
  /// accruals so rounding does not change the total due by maturity.
  List<int> interestOnlyPortions({
    required int principalMinor,
    required String startDate,
    required List<DateTime> dueDates,
    required InterestMethod method,
    required double rate,
    required RatePeriod ratePeriod,
  }) {
    final portions = <int>[];
    var previousAccrual = 0;
    for (final date in dueDates) {
      final accrued = projectedInterest(
        principalMinor: principalMinor,
        fromDate: startDate,
        toDate:
            '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        method: method,
        rate: rate,
        ratePeriod: ratePeriod,
        fixedInterestMinor: null,
        monthlyAnchorDate: startDate,
      );
      portions.add(accrued - previousAccrual);
      previousAccrual = accrued;
    }
    return portions;
  }

  /// Compute the accrued interest from [startDate] inclusive to [asOfDate] exclusive.
  /// Returns interest in minor units.
  int accruedInterest({
    required String startDate,
    required String asOfDate,
    required int principalMinor, // outstanding principal for the period
    required InterestMethod method,
    required double? rate, // 0.0..1.0, e.g. 0.15 = 15%
    required RatePeriod? ratePeriod,
    required int? fixedInterestMinor,
    String? monthlyAnchorDate,
    String? maturityDate,
    bool continueAfterMaturity = false,
  }) {
    _validateDate(startDate);
    _validateDate(asOfDate);
    if (asOfDate.compareTo(startDate) <= 0 || principalMinor <= 0) return 0;
    if (method == InterestMethod.none) return 0;
    if (method == InterestMethod.fixedTotal) return fixedInterestMinor ?? 0;

    final endDate =
        maturityDate != null &&
            !continueAfterMaturity &&
            maturityDate.compareTo(asOfDate) <= 0
        ? maturityDate
        : asOfDate;
    if (endDate.compareTo(startDate) <= 0 ||
        rate == null ||
        ratePeriod == null) {
      return 0;
    }

    return switch (ratePeriod) {
      RatePeriod.annual => _rateAmount(
        principalMinor,
        rate,
        _daysBetween(startDate, endDate),
        365,
      ),
      RatePeriod.monthly => _monthlyAccrual(
        principalMinor,
        rate,
        startDate,
        endDate,
        monthlyAnchorDate,
      ),
    };
  }

  /// Compute future scheduled interest for a given principal value.
  /// For remaining-principal method, pass the *current* outstanding principal
  /// and the schedule will project forward.
  int projectedInterest({
    required int principalMinor,
    required String fromDate,
    required String toDate,
    required InterestMethod method,
    required double? rate,
    required RatePeriod? ratePeriod,
    required int? fixedInterestMinor,
    String? monthlyAnchorDate,
    String? maturityDate,
    bool continueAfterMaturity = false,
  }) {
    _validateDate(fromDate);
    _validateDate(toDate);
    if (toDate.compareTo(fromDate) <= 0 || principalMinor <= 0) return 0;
    if (method == InterestMethod.none) return 0;
    if (method == InterestMethod.fixedTotal) return fixedInterestMinor ?? 0;
    if (rate == null || ratePeriod == null) return 0;

    final endDate =
        maturityDate != null &&
            !continueAfterMaturity &&
            maturityDate.compareTo(toDate) <= 0
        ? maturityDate
        : toDate;
    if (endDate.compareTo(fromDate) <= 0) return 0;
    final days = _daysBetween(fromDate, endDate);
    return switch (ratePeriod) {
      RatePeriod.annual => _rateAmount(principalMinor, rate, days, 365),
      RatePeriod.monthly => _monthlyAccrual(
        principalMinor,
        rate,
        fromDate,
        endDate,
        monthlyAnchorDate,
      ),
    };
  }

  /// Monthly accrual: full % for each complete monthly anniversary,
  /// prorate partial periods by actual days in that month.
  /// When a month-end date is clamped (e.g., 31st → 28th in Feb),
  /// the period still counts as one full month.
  int _monthlyAccrual(
    int principal,
    double rate,
    String start,
    String end,
    String? monthlyAnchorDate,
  ) {
    final s = DateTime.parse(start);
    final e = DateTime.parse(end);
    final anchor = DateTime.parse(monthlyAnchorDate ?? start);
    var cursor = s;
    var interest = 0;
    final monthsFromAnchor =
        (s.year - anchor.year) * 12 + s.month - anchor.month;
    var period = monthsFromAnchor + (s.day < anchor.day ? 0 : 1);
    if (period < 1) period = 1;
    var periodStart = _addMonths(anchor, period - 1);
    if (cursor.isBefore(periodStart)) periodStart = cursor;
    if (cursor.isAfter(periodStart)) periodStart = cursor;
    while (cursor.isBefore(e)) {
      var anniversary = _addMonths(anchor, period);
      while (DateTime.utc(
            anniversary.year,
            anniversary.month,
            anniversary.day,
          ).isBefore(DateTime.utc(cursor.year, cursor.month, cursor.day)) ||
          (anniversary.year == cursor.year &&
              anniversary.month == cursor.month &&
              anniversary.day == cursor.day)) {
        period++;
        anniversary = _addMonths(anchor, period);
      }
      final periodDays = anniversary.difference(periodStart).inDays;
      final endOfAccrual = anniversary.isAfter(e) ? e : anniversary;
      final elapsedDays = endOfAccrual.difference(cursor).inDays;
      interest += _rateAmount(principal, rate, elapsedDays, periodDays);
      cursor = endOfAccrual;
      if (!cursor.isBefore(anniversary)) {
        period++;
        periodStart = anniversary;
      }
    }
    return interest;
  }

  /// Allocate a payment total between interest (first) and principal.
  ({int principal, int interest}) allocate({
    required int paymentTotal,
    required int outstandingPrincipal,
    required int accruedInterest,
    int? explicitPrincipal,
    int? explicitInterest,
  }) {
    if (paymentTotal <= 0 || outstandingPrincipal < 0 || accruedInterest < 0) {
      throw ArgumentError('Payment and balances must be non-negative');
    }
    if (explicitPrincipal != null || explicitInterest != null) {
      // Explicit allocation: validate
      final p = explicitPrincipal ?? 0;
      final i = explicitInterest ?? 0;
      if (paymentTotal <= 0) {
        throw ArgumentError('Payment must be positive');
      }
      if (accruedInterest < 0 || outstandingPrincipal < 0) {
        throw ArgumentError('Balances cannot be negative');
      }
      if (i > accruedInterest) {
        throw ArgumentError('Interest allocation exceeds accrued interest');
      }
      if (p + i != paymentTotal) {
        throw ArgumentError('Principal + interest must equal total payment');
      }
      if (p < 0 || i < 0) {
        throw ArgumentError('Allocations cannot be negative');
      }
      if (p > outstandingPrincipal) {
        throw ArgumentError('Principal allocation exceeds outstanding');
      }
      return (principal: p, interest: i);
    }

    // Interest-first default
    final toInterest = paymentTotal > accruedInterest
        ? accruedInterest
        : paymentTotal;
    final toPrincipal = paymentTotal - toInterest;

    if (toPrincipal > outstandingPrincipal) {
      throw ArgumentError('Principal payment exceeds outstanding');
    }

    return (principal: toPrincipal, interest: toInterest);
  }

  // ── Date helpers ───────────────────────────────────────────────────────────

  static void _validateDate(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null || parsed.toIso8601String().substring(0, 10) != value) {
      throw ArgumentError('Date must be YYYY-MM-DD');
    }
  }

  static int _daysBetween(String a, String b) {
    final start = DateTime.parse(a);
    final end = DateTime.parse(b);
    return DateTime.utc(
      end.year,
      end.month,
      end.day,
    ).difference(DateTime.utc(start.year, start.month, start.day)).inDays;
  }

  static DateTime _addMonths(DateTime dt, int months) {
    var y = dt.year + (dt.month + months - 1) ~/ 12;
    var m = (dt.month + months - 1) % 12 + 1;
    final maxDay = _daysInMonth(y, m);
    final d = dt.day > maxDay ? maxDay : dt.day;
    return DateTime(y, m, d);
  }

  static int _daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  static int _rateAmount(
    int principal,
    double rate,
    int numerator,
    int denominator,
  ) {
    if (!rate.isFinite || rate < 0 || numerator <= 0) {
      throw ArgumentError('Rate and period must be non-negative');
    }
    final scaledRate = (rate * 1000000000000).round();
    final amount =
        BigInt.from(principal) *
        BigInt.from(scaledRate) *
        BigInt.from(numerator);
    final divisor = BigInt.from(1000000000000) * BigInt.from(denominator);
    return _roundRatio(amount, divisor);
  }

  static int _roundRatio(BigInt numerator, BigInt denominator) {
    final quotient = numerator ~/ denominator;
    final remainder = numerator % denominator;
    return (remainder * BigInt.two >= denominator
            ? quotient + BigInt.one
            : quotient)
        .toInt();
  }
}
