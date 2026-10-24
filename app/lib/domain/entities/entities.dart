/// Core domain entities for LenDen Tracker.
///
/// All money amounts are in integer minor units (paise, cents, etc.).
/// Dates are ISO 8601 strings (YYYY-MM-DD).
library;

enum LoanDirection { lent, borrowed }

enum InterestMethod { none, fixedTotal, originalPrincipal, remainingPrincipal }

enum RatePeriod { monthly, annual }

enum PaymentSchedule { flexible, atMaturity, regular, interestOnly }

enum LoanStatus { active, settled, waived }

enum DueStatus { upcoming, paid, overdue, waived }

class Person {
  final int? id;
  final String displayName;
  final String phoneE164;
  final String? contactId;
  final DateTime createdAt;

  const Person({
    this.id,
    required this.displayName,
    required this.phoneE164,
    this.contactId,
    required this.createdAt,
  });

  Person copyWith({
    int? id,
    String? displayName,
    String? phoneE164,
    String? contactId,
    DateTime? createdAt,
  }) => Person(
    id: id ?? this.id,
    displayName: displayName ?? this.displayName,
    phoneE164: phoneE164 ?? this.phoneE164,
    contactId: contactId ?? this.contactId,
    createdAt: createdAt ?? this.createdAt,
  );
}

class Loan {
  final int? id;
  final int personId;
  final LoanDirection direction;
  final int principalMinor;
  final String currency;
  final String startDate;
  final String? maturityDate;
  final InterestMethod interestMethod;
  final double? interestRate;
  final RatePeriod? ratePeriod;
  final int? fixedInterestMinor;
  final PaymentSchedule paymentSchedule;
  final int? installmentAmountMinor;
  final String? firstDueDate;
  final String? monthlyAnchorDate;
  final bool continueAfterMaturity;
  final String? notes;
  final LoanStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Loan({
    this.id,
    required this.personId,
    required this.direction,
    required this.principalMinor,
    required this.currency,
    required this.startDate,
    this.maturityDate,
    required this.interestMethod,
    this.interestRate,
    this.ratePeriod,
    this.fixedInterestMinor,
    required this.paymentSchedule,
    this.installmentAmountMinor,
    this.firstDueDate,
    this.monthlyAnchorDate,
    this.continueAfterMaturity = false,
    this.notes,
    this.status = LoanStatus.active,
    required this.createdAt,
    required this.updatedAt,
  });

  Loan copyWith({
    int? id,
    int? personId,
    LoanDirection? direction,
    int? principalMinor,
    String? currency,
    String? startDate,
    String? maturityDate,
    InterestMethod? interestMethod,
    double? interestRate,
    RatePeriod? ratePeriod,
    int? fixedInterestMinor,
    PaymentSchedule? paymentSchedule,
    int? installmentAmountMinor,
    String? firstDueDate,
    String? monthlyAnchorDate,
    bool? continueAfterMaturity,
    String? notes,
    LoanStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Loan(
    id: id ?? this.id,
    personId: personId ?? this.personId,
    direction: direction ?? this.direction,
    principalMinor: principalMinor ?? this.principalMinor,
    currency: currency ?? this.currency,
    startDate: startDate ?? this.startDate,
    maturityDate: maturityDate ?? this.maturityDate,
    interestMethod: interestMethod ?? this.interestMethod,
    interestRate: interestRate ?? this.interestRate,
    ratePeriod: ratePeriod ?? this.ratePeriod,
    fixedInterestMinor: fixedInterestMinor ?? this.fixedInterestMinor,
    paymentSchedule: paymentSchedule ?? this.paymentSchedule,
    installmentAmountMinor:
        installmentAmountMinor ?? this.installmentAmountMinor,
    firstDueDate: firstDueDate ?? this.firstDueDate,
    monthlyAnchorDate: monthlyAnchorDate ?? this.monthlyAnchorDate,
    continueAfterMaturity: continueAfterMaturity ?? this.continueAfterMaturity,
    notes: notes ?? this.notes,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

class Payment {
  final int? id;
  final int loanId;
  final String effectiveDate;
  final int totalMinor;
  final int principalMinor;
  final int interestMinor;
  final String? note;
  final bool reversed;
  final int? reversalOfId;
  final String? reversalReason;
  final DateTime createdAt;

  const Payment({
    this.id,
    required this.loanId,
    required this.effectiveDate,
    required this.totalMinor,
    required this.principalMinor,
    required this.interestMinor,
    this.note,
    this.reversed = false,
    this.reversalOfId,
    this.reversalReason,
    required this.createdAt,
  });
}

class ScheduledDue {
  final int? id;
  final int loanId;
  final String dueDate;
  final int principalMinor;
  final int interestMinor;
  final DueStatus status;

  const ScheduledDue({
    this.id,
    required this.loanId,
    required this.dueDate,
    required this.principalMinor,
    required this.interestMinor,
    this.status = DueStatus.upcoming,
  });

  int get totalMinor => principalMinor + interestMinor;
}

class LoanAmendment {
  final int? id;
  final int loanId;
  final String amendedAt;
  final String fieldName;
  final String? oldValue;
  final String? newValue;
  final String? note;

  const LoanAmendment({
    this.id,
    required this.loanId,
    required this.amendedAt,
    required this.fieldName,
    this.oldValue,
    this.newValue,
    this.note,
  });
}

class PaymentAllocationPreview {
  final int accruedInterestMinor;
  final int outstandingPrincipalMinor;
  final int principalMinor;
  final int interestMinor;
  final int totalMinor;

  const PaymentAllocationPreview({
    required this.accruedInterestMinor,
    required this.outstandingPrincipalMinor,
    required this.principalMinor,
    required this.interestMinor,
    required this.totalMinor,
  });
}

class WaiverPreview {
  final int accruedInterestMinor;
  final int waivedBeforeMinor;
  final int waivedAfterMinor;
  final int remainingInterestMinor;

  const WaiverPreview({
    required this.accruedInterestMinor,
    required this.waivedBeforeMinor,
    required this.waivedAfterMinor,
    required this.remainingInterestMinor,
  });
}

class InterestWaiver {
  final int? id;
  final int loanId;
  final String waiverDate;
  final int amountMinor;
  final String? note;

  const InterestWaiver({
    this.id,
    required this.loanId,
    required this.waiverDate,
    required this.amountMinor,
    this.note,
  });
}
