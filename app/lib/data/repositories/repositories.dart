import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../../domain/entities/entities.dart';
import '../../../domain/services/interest_calculator.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Person Repository
// ──────────────────────────────────────────────────────────────────────────────

final personRepoProvider = Provider<PersonRepository>((ref) {
  return PersonRepository(db: AppDatabase.instance.db);
});

class PersonRepository {
  PersonRepository({required this.db});
  final Database db;

  Future<Person> insert(Person p) async {
    final id = await db.insert('people', {
      'display_name': p.displayName,
      'phone_e164': p.phoneE164,
      'contact_id': p.contactId,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    return p.copyWith(id: id);
  }

  Future<Person?> getByPhone(String e164) async {
    final rows = await db.query(
      'people',
      where: 'phone_e164 = ?',
      whereArgs: [e164],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  Future<Person?> getById(int id) async {
    final rows = await db.query('people', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  Future<List<Person>> search(String query) async {
    final rows = await db.query(
      'people',
      where: 'display_name LIKE ? OR phone_e164 LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'display_name ASC',
    );
    return rows.map(_fromRow).toList();
  }

  Future<List<Person>> all() async {
    final rows = await db.query('people', orderBy: 'display_name ASC');
    return rows.map(_fromRow).toList();
  }

  Future<void> updatePhone(int id, String newE164) async {
    await db.update(
      'people',
      {'phone_e164': newE164},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Person _fromRow(Map<String, dynamic> row) => Person(
    id: row['id'] as int,
    displayName: row['display_name'] as String,
    phoneE164: row['phone_e164'] as String,
    contactId: row['contact_id'] as String?,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
  );
}

// ──────────────────────────────────────────────────────────────────────────────
// Loan Repository
// ──────────────────────────────────────────────────────────────────────────────

final loanRepoProvider = Provider<LoanRepository>((ref) {
  return LoanRepository(db: AppDatabase.instance.db);
});

class PrincipalBalance {
  const PrincipalBalance({
    required this.currency,
    required this.direction,
    required this.amountMinor,
  });

  final String currency;
  final LoanDirection direction;
  final int amountMinor;
}

class LoanListItem {
  const LoanListItem(
    this.loan,
    this.personName, {
    this.nextDueDate,
    this.nextDueMinor = 0,
    this.overdueCount = 0,
    this.accruedInterestMinor = 0,
    this.dueInterestMinor = 0,
  });
  final Loan loan;
  final String personName;
  final String? nextDueDate;
  final int nextDueMinor;
  final int overdueCount;
  final int accruedInterestMinor;
  final int dueInterestMinor;

  LoanListItem withSummary({
    String? nextDueDate,
    int nextDueMinor = 0,
    int overdueCount = 0,
    int accruedInterestMinor = 0,
    int dueInterestMinor = 0,
  }) => LoanListItem(
    loan,
    personName,
    nextDueDate: nextDueDate,
    nextDueMinor: nextDueMinor,
    overdueCount: overdueCount,
    accruedInterestMinor: accruedInterestMinor,
    dueInterestMinor: dueInterestMinor,
  );
}

class LoanRepository {
  LoanRepository({required this.db});
  final Database db;

  Future<int> createWithPerson({
    required String name,
    required String phone,
    required String contactId,
    required Loan loan,
    List<ScheduledDue> schedule = const [],
  }) async {
    if (name.trim().isEmpty ||
        phone.trim().isEmpty ||
        loan.principalMinor <= 0) {
      throw ArgumentError('Contact and positive principal are required');
    }
    if ((loan.paymentSchedule == PaymentSchedule.regular ||
            loan.paymentSchedule == PaymentSchedule.interestOnly) &&
        schedule.isEmpty) {
      throw ArgumentError('Recurring schedules require at least one due.');
    }
    if (loan.paymentSchedule == PaymentSchedule.regular &&
        schedule.fold<int>(0, (sum, due) => sum + due.principalMinor) !=
            loan.principalMinor) {
      throw ArgumentError('Installment principal must equal loan principal.');
    }
    if (loan.interestMethod == InterestMethod.fixedTotal &&
        schedule.isNotEmpty &&
        schedule.fold<int>(0, (sum, due) => sum + due.interestMinor) !=
            (loan.fixedInterestMinor ?? 0)) {
      throw ArgumentError('Scheduled fixed interest must equal fixed total.');
    }
    return db.transaction((txn) async {
      final existing = await txn.query(
        'people',
        columns: ['id'],
        where: 'phone_e164 = ?',
        whereArgs: [phone],
        limit: 1,
      );
      final personId = existing.isNotEmpty
          ? existing.first['id'] as int
          : await txn.insert('people', {
              'display_name': name.trim(),
              'phone_e164': phone,
              'contact_id': contactId,
              'created_at': DateTime.now().millisecondsSinceEpoch,
            });
      final now = DateTime.now().millisecondsSinceEpoch;
      final loanId = await txn.insert('loans', {
        'person_id': personId,
        'direction': loan.direction.name,
        'principal_minor': loan.principalMinor,
        'currency': loan.currency,
        'start_date': loan.startDate,
        'maturity_date': loan.maturityDate,
        'interest_method': _interestName(loan.interestMethod),
        'interest_rate': loan.interestRate,
        'rate_period': loan.ratePeriod?.name,
        'fixed_interest_minor': loan.fixedInterestMinor,
        'payment_schedule': _scheduleName(loan.paymentSchedule),
        'installment_amount_minor': loan.installmentAmountMinor,
        'first_due_date': loan.firstDueDate,
        'monthly_anchor_date': loan.monthlyAnchorDate ?? loan.startDate,
        'continue_after_maturity': loan.continueAfterMaturity ? 1 : 0,
        'notes': loan.notes,
        'status': loan.status.name,
        'created_at': now,
        'updated_at': now,
      });
      final persistedSchedule = schedule
          .map((due) => due.loanId == 0 ? _withLoanId(due, loanId) : due)
          .toList();
      _validateSchedule(
        loanId,
        loan.startDate,
        loan.maturityDate,
        persistedSchedule,
        schedule: loan.paymentSchedule,
      );
      for (final due in persistedSchedule) {
        await txn.insert('scheduled_dues', {
          'loan_id': loanId,
          'due_date': due.dueDate,
          'principal_minor': due.principalMinor,
          'interest_minor': due.interestMinor,
          'status': due.status.name,
        });
      }
      return loanId;
    });
  }

  /// Outstanding principal only; accrued/due interest is calculated separately.
  Future<List<PrincipalBalance>> principalBalances() async {
    final rows = await db.rawQuery('''
      SELECT l.currency, l.direction,
             SUM(l.principal_minor - COALESCE(p.paid_minor, 0)) AS amount_minor
      FROM loans l
      LEFT JOIN (
        SELECT loan_id, SUM(principal_minor) AS paid_minor
        FROM payments WHERE reversed = 0 GROUP BY loan_id
      ) p ON p.loan_id = l.id
      GROUP BY l.currency, l.direction
      ORDER BY l.currency, l.direction
    ''');
    return rows
        .map(
          (row) => PrincipalBalance(
            currency: row['currency'] as String,
            direction: LoanDirection.values.byName(row['direction'] as String),
            amountMinor: row['amount_minor'] as int,
          ),
        )
        .toList();
  }

  Future<Loan> insert(Loan l) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = await db.insert('loans', {
      'person_id': l.personId,
      'direction': l.direction.name,
      'principal_minor': l.principalMinor,
      'currency': l.currency,
      'start_date': l.startDate,
      'maturity_date': l.maturityDate,
      'interest_method': _interestName(l.interestMethod),
      'interest_rate': l.interestRate,
      'rate_period': l.ratePeriod?.name,
      'fixed_interest_minor': l.fixedInterestMinor,
      'payment_schedule': _scheduleName(l.paymentSchedule),
      'installment_amount_minor': l.installmentAmountMinor,
      'first_due_date': l.firstDueDate,
      'monthly_anchor_date': l.monthlyAnchorDate ?? l.startDate,
      'continue_after_maturity': l.continueAfterMaturity ? 1 : 0,
      'notes': l.notes,
      'status': l.status.name,
      'created_at': now,
      'updated_at': now,
    });
    return l.copyWith(
      id: id,
      createdAt: DateTime.fromMillisecondsSinceEpoch(now),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(now),
    );
  }

  Future<Loan?> getById(int id) async {
    final rows = await db.query('loans', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  Future<List<Loan>> all({
    LoanDirection? direction,
    LoanStatus? status,
    String? currency,
    String? search,
  }) async {
    final clauses = <String>[];
    final args = <dynamic>[];

    if (direction != null) {
      clauses.add('l.direction = ?');
      args.add(direction.name);
    }
    if (status != null) {
      clauses.add('l.status = ?');
      args.add(status.name);
    }
    if (currency != null) {
      clauses.add('l.currency = ?');
      args.add(currency);
    }
    if (search != null && search.isNotEmpty) {
      clauses.add('(p.display_name LIKE ? OR p.phone_e164 LIKE ?)');
      args.add('%$search%');
      args.add('%$search%');
    }

    final where = clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}';
    final rows = await db.rawQuery('''
      SELECT l.*, p.display_name, p.phone_e164
      FROM loans l JOIN people p ON l.person_id = p.id
      $where
      ORDER BY l.updated_at DESC
    ''', args);
    return rows.map(_fromRow).toList();
  }

  Future<List<LoanListItem>> listWithPeople() async {
    final rows = await db.rawQuery('''
      SELECT l.*, p.display_name FROM loans l
      JOIN people p ON p.id = l.person_id
      ORDER BY l.updated_at DESC
    ''');
    return rows
        .map(
          (row) => LoanListItem(_fromRow(row), row['display_name'] as String),
        )
        .toList();
  }

  Future<void> update(Loan l) async {
    if (l.id == null ||
        l.principalMinor <= 0 ||
        l.maturityDate != null && l.maturityDate!.compareTo(l.startDate) < 0) {
      throw ArgumentError('Invalid loan update');
    }
    PaymentRepository._validateDate(l.startDate);
    if (l.maturityDate != null) {
      PaymentRepository._validateDate(l.maturityDate!);
    }
    await db.transaction((txn) async {
      final rows = await txn.query('loans', where: 'id = ?', whereArgs: [l.id]);
      if (rows.isEmpty) throw StateError('Loan not found');
      final old = rows.first;
      final updated = <String, Object?>{
        'status': l.status.name,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        'notes': l.notes,
        'maturity_date': l.maturityDate,
        'monthly_anchor_date': l.monthlyAnchorDate ?? l.startDate,
        'continue_after_maturity': l.continueAfterMaturity ? 1 : 0,
      };
      for (final entry in updated.entries) {
        if (old[entry.key] != entry.value) {
          await txn.insert('loan_amendments', {
            'loan_id': l.id,
            'amended_at': DateTime.now().toIso8601String().substring(0, 10),
            'field_name': entry.key,
            'old_value': old[entry.key]?.toString(),
            'new_value': entry.value?.toString(),
            'created_at': DateTime.now().millisecondsSinceEpoch,
          });
        }
      }
      await txn.update('loans', updated, where: 'id = ?', whereArgs: [l.id]);
    });
  }

  Future<void> settle(int loanId) async {
    await db.transaction((txn) async {
      final rows = await txn.query(
        'loans',
        where: 'id = ?',
        whereArgs: [loanId],
      );
      if (rows.isEmpty) throw StateError('Loan not found');
      final principal = await PaymentRepository(db: db)
          ._paidPrincipal(txn, loanId);
      final unpaidInterest = await PaymentRepository(db: db)
          ._unpaidInterest(txn, rows.first, loanId);
      if (principal != (rows.first['principal_minor'] as int) ||
          unpaidInterest > 0) {
        throw StateError(
          'Loan cannot be settled until principal and interest are paid or waived',
        );
      }
      await txn.update(
        'loans',
        {
          'status': LoanStatus.settled.name,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [loanId],
      );
    });
  }

  ScheduledDue _withLoanId(ScheduledDue due, int loanId) => ScheduledDue(
    id: due.id,
    loanId: loanId,
    dueDate: due.dueDate,
    principalMinor: due.principalMinor,
    interestMinor: due.interestMinor,
    status: due.status,
  );

  void _validateSchedule(
    int loanId,
    String startDate,
    String? maturityDate,
    List<ScheduledDue> dues, {
    required PaymentSchedule schedule,
  }) {
    var previousDate = startDate;
    var first = true;
    for (final due in dues) {
      PaymentRepository._validateDate(due.dueDate);
      final dateOutOfOrder = first
          ? due.dueDate.compareTo(previousDate) < 0
          : due.dueDate.compareTo(previousDate) <= 0;
      if (due.loanId != loanId ||
          dateOutOfOrder ||
          due.principalMinor < 0 ||
          due.interestMinor < 0 ||
          (schedule != PaymentSchedule.interestOnly && due.totalMinor == 0)) {
        throw ArgumentError('Invalid or unordered schedule due');
      }
      previousDate = due.dueDate;
      first = false;
    }
    if (dues.isNotEmpty &&
        maturityDate != null &&
        dues.last.dueDate.compareTo(maturityDate) > 0) {
      throw ArgumentError('Schedule extends past maturity');
    }
  }

  Future<void> saveSchedule(int loanId, List<ScheduledDue> dues) async {
    final loanRows = await db.query(
      'loans',
      where: 'id = ?',
      whereArgs: [loanId],
    );
    if (loanRows.isEmpty) throw StateError('Loan not found');
    final loan = loanRows.first;
    _validateSchedule(
      loanId,
      loan['start_date'] as String,
      loan['maturity_date'] as String?,
      dues,
      schedule: PaymentSchedule.values.byName(
        _camelName(loan['payment_schedule'] as String),
      ),
    );
    await db.transaction((txn) async {
      await txn.delete(
        'scheduled_dues',
        where: 'loan_id = ?',
        whereArgs: [loanId],
      );
      for (final due in dues) {
        await txn.insert('scheduled_dues', {
          'loan_id': loanId,
          'due_date': due.dueDate,
          'principal_minor': due.principalMinor,
          'interest_minor': due.interestMinor,
          'status': due.status.name,
        });
      }
    });
  }

  Future<List<ScheduledDue>> duesForLoan(int loanId) async {
    final rows = await db.query(
      'scheduled_dues',
      where: 'loan_id = ?',
      whereArgs: [loanId],
      orderBy: 'due_date ASC, id ASC',
    );
    return rows
        .map(
          (row) => ScheduledDue(
            id: row['id'] as int,
            loanId: row['loan_id'] as int,
            dueDate: row['due_date'] as String,
            principalMinor: row['principal_minor'] as int,
            interestMinor: row['interest_minor'] as int,
            status: DueStatus.values.byName(row['status'] as String),
          ),
        )
        .toList();
  }

  Future<List<LoanListItem>> summaries(String asOfDate) async {
    PaymentRepository._validateDate(asOfDate);
    final loans = await listWithPeople();
    final active = loans.where((item) => item.loan.status == LoanStatus.active);
    final output = <LoanListItem>[];
    final payments = PaymentRepository(db: db);
    for (final item in active) {
      final dues = await duesForLoan(item.loan.id!);
      final paidInterest = await db.rawQuery(
        'SELECT COALESCE(SUM(interest_minor),0) AS total FROM payments WHERE loan_id = ? AND reversed = 0 AND effective_date <= ?',
        [item.loan.id, asOfDate],
      );
      var paymentInterestRemaining = paidInterest.first['total'] as int;
      final waivedInterest = await db.rawQuery(
        'SELECT COALESCE(SUM(amount_minor),0) AS amount FROM waivers WHERE loan_id = ? AND waiver_date <= ?',
        [item.loan.id, asOfDate],
      );
      var remainingWaivedInterest = waivedInterest.first['amount'] as int;
      final orderedDues = dues.toList()
        ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
      var interestDue = 0;
      for (final due in orderedDues.where(
        (due) =>
            due.dueDate.compareTo(asOfDate) <= 0 &&
            due.status != DueStatus.paid &&
            due.status != DueStatus.waived,
      )) {
        final paid = paymentInterestRemaining < due.interestMinor
            ? paymentInterestRemaining
            : due.interestMinor;
        paymentInterestRemaining -= paid;
        final waived = remainingWaivedInterest < due.interestMinor - paid
            ? remainingWaivedInterest
            : due.interestMinor - paid;
        remainingWaivedInterest -= waived;
        interestDue += due.interestMinor - paid - waived;
      }
      final outstanding = await payments.outstandingPrincipal(item.loan.id!);
      final accrued = outstanding <= 0
          ? 0
          : await payments.accruedInterest(item.loan.id!, asOfDate);
      final eligible = dues
          .where(
            (due) =>
                due.status == DueStatus.upcoming ||
                due.status == DueStatus.overdue,
          )
          .toList();
      final upcoming = eligible.where(
        (due) => due.dueDate.compareTo(asOfDate) >= 0,
      );
      final nextDue = upcoming.isEmpty ? null : upcoming.first;
      final overdueCount = eligible
          .where((due) => due.dueDate.compareTo(asOfDate) < 0)
          .length;
      output.add(
        item.withSummary(
          nextDueDate: nextDue?.dueDate,
          nextDueMinor: nextDue?.totalMinor ?? 0,
          overdueCount: overdueCount,
          accruedInterestMinor: accrued,
          dueInterestMinor: interestDue < 0 ? 0 : interestDue,
        ),
      );
    }
    output.sort((a, b) {
      final ad = a.nextDueDate ?? '9999-12-31';
      final bd = b.nextDueDate ?? '9999-12-31';
      return ad.compareTo(bd);
    });
    return output;
  }

  Future<List<LoanAmendment>> amendmentsForLoan(int loanId) async {
    final rows = await db.query(
      'loan_amendments',
      where: 'loan_id = ?',
      whereArgs: [loanId],
      orderBy: 'amended_at ASC, id ASC',
    );
    return rows
        .map(
          (row) => LoanAmendment(
            id: row['id'] as int,
            loanId: row['loan_id'] as int,
            amendedAt: row['amended_at'] as String,
            fieldName: row['field_name'] as String,
            oldValue: row['old_value'] as String?,
            newValue: row['new_value'] as String?,
            note: row['note'] as String?,
          ),
        )
        .toList();
  }

  Future<List<LoanAmendment>> previewAmendment(
    int loanId,
    Loan amendedLoan,
    String effectiveDate, {
    String? note,
  }) async {
    PaymentRepository._validateDate(effectiveDate);
    final current = await getById(loanId);
    if (current == null) throw StateError('Loan not found');
    final before = <String, String?>{
      'maturity_date': current.maturityDate,
      'interest_method': _interestName(current.interestMethod),
      'interest_rate': current.interestRate?.toString(),
      'rate_period': current.ratePeriod?.name,
      'fixed_interest_minor': current.fixedInterestMinor?.toString(),
      'installment_amount_minor': current.installmentAmountMinor?.toString(),
      'notes': current.notes,
    };
    final after = <String, String?>{
      'maturity_date': amendedLoan.maturityDate,
      'interest_method': _interestName(amendedLoan.interestMethod),
      'interest_rate': amendedLoan.interestRate?.toString(),
      'rate_period': amendedLoan.ratePeriod?.name,
      'fixed_interest_minor': amendedLoan.fixedInterestMinor?.toString(),
      'installment_amount_minor': amendedLoan.installmentAmountMinor
          ?.toString(),
      'notes': amendedLoan.notes,
    };
    return [
      for (final field in before.keys)
        if (before[field] != after[field])
          LoanAmendment(
            loanId: loanId,
            amendedAt: effectiveDate,
            fieldName: field,
            oldValue: before[field],
            newValue: after[field],
            note: note,
          ),
    ];
  }

  Future<void> applyAmendment(
    int loanId,
    Loan amendedLoan,
    String effectiveDate, {
    String? note,
  }) async {
    PaymentRepository._validateDate(effectiveDate);
    await db.transaction((txn) async {
      final rows = await txn.query(
        'loans',
        where: 'id = ?',
        whereArgs: [loanId],
      );
      if (rows.isEmpty) throw StateError('Loan not found');
      final old = rows.first;
      if (effectiveDate.compareTo(old['start_date'] as String) < 0) {
        throw ArgumentError('Amendment predates loan');
      }
      final oldValues = <String, Object?>{
        'maturity_date': old['maturity_date'],
        'interest_method': old['interest_method'],
        'interest_rate': old['interest_rate'],
        'rate_period': old['rate_period'],
        'fixed_interest_minor': old['fixed_interest_minor'],
        'installment_amount_minor': old['installment_amount_minor'],
        'notes': old['notes'],
      };
      final newValues = <String, Object?>{
        'maturity_date': amendedLoan.maturityDate,
        'interest_method': _interestName(amendedLoan.interestMethod),
        'interest_rate': amendedLoan.interestRate,
        'rate_period': amendedLoan.ratePeriod?.name,
        'fixed_interest_minor': amendedLoan.fixedInterestMinor,
        'installment_amount_minor': amendedLoan.installmentAmountMinor,
        'notes': amendedLoan.notes,
      };
      for (final field in oldValues.keys) {
        if (oldValues[field] != newValues[field]) {
          await txn.insert('loan_amendments', {
            'loan_id': loanId,
            'amended_at': effectiveDate,
            'field_name': field,
            'old_value': oldValues[field]?.toString(),
            'new_value': newValues[field]?.toString(),
            'note': note,
            'created_at': DateTime.now().millisecondsSinceEpoch,
          });
        }
      }
      await txn.update(
        'loans',
        {...newValues, 'updated_at': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [loanId],
      );
    });
  }

  Loan _fromRow(Map<String, dynamic> row) => Loan(
    id: row['id'] as int,
    personId: row['person_id'] as int,
    direction: LoanDirection.values.byName(row['direction']),
    principalMinor: row['principal_minor'] as int,
    currency: row['currency'] as String,
    startDate: row['start_date'] as String,
    maturityDate: row['maturity_date'] as String?,
    interestMethod: InterestMethod.values.byName(
      _camelName(row['interest_method'] as String),
    ),
    interestRate: (row['interest_rate'] as num?)?.toDouble(),
    ratePeriod: row['rate_period'] != null
        ? RatePeriod.values.byName(row['rate_period'] as String)
        : null,
    fixedInterestMinor: row['fixed_interest_minor'] as int?,
    paymentSchedule: PaymentSchedule.values.byName(
      _camelName(row['payment_schedule'] as String),
    ),
    installmentAmountMinor: row['installment_amount_minor'] as int?,
    firstDueDate: row['first_due_date'] as String?,
    monthlyAnchorDate:
        row['monthly_anchor_date'] as String? ?? row['start_date'] as String,
    continueAfterMaturity: (row['continue_after_maturity'] as int? ?? 0) == 1,
    notes: row['notes'] as String?,
    status: LoanStatus.values.byName(row['status'] as String),
    createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
  );
}

String _interestName(InterestMethod method) => switch (method) {
  InterestMethod.fixedTotal => 'fixed_total',
  InterestMethod.originalPrincipal => 'original_principal',
  InterestMethod.remainingPrincipal => 'remaining_principal',
  InterestMethod.none => 'none',
};

String _scheduleName(PaymentSchedule schedule) => switch (schedule) {
  PaymentSchedule.atMaturity => 'at_maturity',
  PaymentSchedule.interestOnly => 'interest_only',
  PaymentSchedule.flexible => 'flexible',
  PaymentSchedule.regular => 'regular',
};

String _camelName(String name) => name.replaceAllMapped(
  RegExp(r'_([a-z])'),
  (match) => match[1]!.toUpperCase(),
);

// ──────────────────────────────────────────────────────────────────────────────
// Payment Repository
// ──────────────────────────────────────────────────────────────────────────────

final paymentRepoProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepository(db: AppDatabase.instance.db);
});

class PaymentRepository {
  PaymentRepository({required this.db});
  final Database db;

  Future<PaymentAllocationPreview> previewAllocation(
    int loanId,
    String effectiveDate,
    int totalMinor, {
    int? excludingPaymentId,
  }) async {
    _validateDate(effectiveDate);
    if (totalMinor <= 0) throw ArgumentError('Payment must be positive');
    return db.transaction((txn) async {
      final loanRows = await txn.query(
        'loans',
        where: 'id = ?',
        whereArgs: [loanId],
      );
      if (loanRows.isEmpty) throw StateError('Loan not found');
      final loan = loanRows.first;
      if (effectiveDate.compareTo(loan['start_date'] as String) < 0 ||
          effectiveDate.compareTo(
                DateTime.now().toIso8601String().substring(0, 10),
              ) >
              0 ||
          (loan['status'] as String) != 'active') {
        throw ArgumentError(
          'Payment date is outside the loan period or loan is inactive',
        );
      }
      final outstanding = await _outstandingPrincipal(
        txn,
        loan,
        loanId,
        excludingPaymentId: excludingPaymentId,
      );
      final accrued = loan['interest_method'] == 'fixed_total'
          ? await _fixedInterestAvailable(
              txn,
              loan,
              loanId,
              effectiveDate,
              outstanding,
            )
          : await _accruedInterestThrough(
              txn,
              loan: loan,
              loanId: loanId,
              asOfDate: effectiveDate,
              calculator: const InterestCalculator(),
              excludingPaymentId: excludingPaymentId,
            );
      final allocation = const InterestCalculator().allocate(
        paymentTotal: totalMinor,
        outstandingPrincipal: outstanding,
        accruedInterest: accrued,
      );
      return PaymentAllocationPreview(
        accruedInterestMinor: accrued,
        outstandingPrincipalMinor: outstanding,
        principalMinor: allocation.principal,
        interestMinor: allocation.interest,
        totalMinor: totalMinor,
      );
    });
  }

  Future<int> accruedInterest(int loanId, String asOfDate) async {
    _validateDate(asOfDate);
    final loans = await db.query('loans', where: 'id = ?', whereArgs: [loanId]);
    if (loans.isEmpty) throw StateError('Loan not found');
    final loan = loans.first;
    if (asOfDate.compareTo(loan['start_date'] as String) < 0) return 0;
    return _accruedInterestThrough(
      db,
      loan: loan,
      loanId: loanId,
      asOfDate: asOfDate,
      calculator: const InterestCalculator(),
    );
  }

  /// Separate currently payable fixed interest from the agreed balance not yet due.
  Future<({int dueMinor, int futureMinor})> interestBalance(
    int loanId,
    String asOfDate,
  ) async {
    _validateDate(asOfDate);
    final rows = await db.query('loans', where: 'id = ?', whereArgs: [loanId]);
    if (rows.isEmpty) throw StateError('Loan not found');
    final loan = rows.first;
    if (loan['interest_method'] != 'fixed_total') {
      return (dueMinor: await interestDue(loanId, asOfDate), futureMinor: 0);
    }
    final paid = await _paidInterest(db, loanId);
    final waived = await _waivedInterest(db, loanId);
    final remaining =
        ((loan['fixed_interest_minor'] as int? ?? 0) - paid - waived).clamp(
          0,
          1 << 62,
        );
    final dueTotal = await _fixedInterestDue(db, loan, loanId, asOfDate);
    final due = (dueTotal - paid - waived).clamp(0, remaining);
    return (dueMinor: due, futureMinor: remaining - due);
  }

  Future<int> interestDue(int loanId, String asOfDate) async {
    final accrued = await accruedInterest(loanId, asOfDate);
    final loans = await db.query(
      'loans',
      columns: ['interest_method'],
      where: 'id = ?',
      whereArgs: [loanId],
    );
    final loan = loans.first;
    if (loan['interest_method'] == 'fixed_total') {
      return (await interestBalance(loanId, asOfDate)).dueMinor;
    }
    final paid = await db.rawQuery(
      'SELECT COALESCE(SUM(interest_minor), 0) AS total FROM payments '
      'WHERE loan_id = ? AND reversed = 0 AND effective_date <= ?',
      [loanId, asOfDate],
    );
    // Remaining-principal accrual already applies waivers while replaying events.
    var waivedMinor = 0;
    if (loans.first['interest_method'] != 'remaining_principal') {
      final waived = await db.rawQuery(
        'SELECT COALESCE(SUM(amount_minor), 0) AS total FROM waivers '
        'WHERE loan_id = ? AND waiver_date <= ?',
        [loanId, asOfDate],
      );
      waivedMinor = waived.first['total'] as int;
    }
    final remaining = accrued - (paid.first['total'] as int) - waivedMinor;
    return remaining < 0 ? 0 : remaining;
  }

  Future<int> _outstandingPrincipal(
    DatabaseExecutor executor,
    Map<String, Object?> loan,
    int loanId, {
    int? excludingPaymentId,
  }) async {
    final query = await executor.rawQuery(
      'SELECT COALESCE(SUM(principal_minor),0) AS paid FROM payments '
      'WHERE loan_id = ? AND reversed = 0'
      '${excludingPaymentId == null ? '' : ' AND id != ?'}',
      [loanId, ?excludingPaymentId],
    );
    return (loan['principal_minor'] as int) - (query.first['paid'] as int);
  }

  static void _validateDate(String date) {
    if (DateTime.tryParse(date)?.toIso8601String().substring(0, 10) != date) {
      throw ArgumentError('Date must be YYYY-MM-DD');
    }
  }

  Future<int> _accruedInterestThrough(
    DatabaseExecutor txn, {
    required Map<String, Object?> loan,
    required int loanId,
    required String asOfDate,
    required InterestCalculator calculator,
    int? excludingPaymentId,
  }) async {
    final method = InterestMethod.values.byName(
      _camelName(loan['interest_method'] as String),
    );
    final startDate = loan['start_date'] as String;
    final maturityDate = loan['maturity_date'] as String?;
    final continueAfterMaturity =
        (loan['continue_after_maturity'] as int? ?? 0) == 1;
    final endDate =
        maturityDate != null &&
            !continueAfterMaturity &&
            maturityDate.compareTo(asOfDate) <= 0
        ? maturityDate
        : asOfDate;
    if (asOfDate.compareTo(startDate) <= 0 ||
        endDate.compareTo(startDate) <= 0) {
      return 0;
    }
    if (maturityDate != null &&
        !continueAfterMaturity &&
        maturityDate.compareTo(startDate) < 0) {
      return 0;
    }
    if (method == InterestMethod.fixedTotal) {
      return loan['fixed_interest_minor'] as int? ?? 0;
    }
    if (method != InterestMethod.remainingPrincipal) {
      return calculator.accruedInterest(
        startDate: startDate,
        asOfDate: endDate,
        principalMinor: loan['principal_minor'] as int,
        method: method,
        rate: (loan['interest_rate'] as num?)?.toDouble(),
        ratePeriod: loan['rate_period'] == null
            ? null
            : RatePeriod.values.byName(loan['rate_period'] as String),
        fixedInterestMinor: loan['fixed_interest_minor'] as int?,
        monthlyAnchorDate: loan['monthly_anchor_date'] as String? ?? startDate,
        maturityDate: maturityDate,
        continueAfterMaturity: continueAfterMaturity,
      );
    }
    final paymentEvents = await txn.query(
      'payments',
      columns: ['effective_date', 'principal_minor'],
      where:
          'loan_id = ? AND reversed = 0 AND effective_date < ?'
          '${excludingPaymentId == null ? '' : ' AND id != ?'}',
      whereArgs: [loanId, endDate, ?excludingPaymentId],
      orderBy: 'effective_date ASC, id ASC',
    );
    final waivers = await txn.query(
      'waivers',
      columns: ['waiver_date', 'amount_minor'],
      where: 'loan_id = ? AND waiver_date < ?',
      whereArgs: [loanId, endDate],
      orderBy: 'waiver_date ASC, id ASC',
    );
    final events = <({String date, int principal, int waiver})>[
      for (final row in paymentEvents)
        (
          date: row['effective_date'] as String,
          principal: row['principal_minor'] as int,
          waiver: 0,
        ),
      for (final row in waivers)
        (
          date: row['waiver_date'] as String,
          principal: 0,
          waiver: row['amount_minor'] as int,
        ),
    ]..sort((a, b) => a.date.compareTo(b.date));
    var interest = 0;
    var principal = loan['principal_minor'] as int;
    var cursor = startDate;
    final monthlyAnchor = loan['monthly_anchor_date'] as String? ?? startDate;
    for (final event in events) {
      final date = event.date;
      if (date.compareTo(cursor) > 0 && principal > 0) {
        interest += calculator.accruedInterest(
          startDate: cursor,
          asOfDate: date,
          principalMinor: principal,
          method: method,
          rate: (loan['interest_rate'] as num?)?.toDouble(),
          ratePeriod: loan['rate_period'] == null
              ? null
              : RatePeriod.values.byName(loan['rate_period'] as String),
          fixedInterestMinor: null,
          monthlyAnchorDate: monthlyAnchor,
        );
      }
      if (event.waiver > 0) {
        interest = (interest - event.waiver).clamp(0, 1 << 62);
      } else {
        principal -= event.principal;
        if (principal <= 0) break;
      }
      cursor = date;
    }
    if (endDate.compareTo(cursor) > 0 && principal > 0) {
      interest += calculator.accruedInterest(
        startDate: cursor,
        asOfDate: endDate,
        principalMinor: principal,
        method: method,
        rate: (loan['interest_rate'] as num?)?.toDouble(),
        ratePeriod: loan['rate_period'] == null
            ? null
            : RatePeriod.values.byName(loan['rate_period'] as String),
        fixedInterestMinor: null,
        monthlyAnchorDate: monthlyAnchor,
      );
    }
    return interest < 0 ? 0 : interest;
  }

  Future<int> outstandingPrincipal(int loanId) async {
    final rows = await db.rawQuery(
      '''
      SELECT l.principal_minor - COALESCE(SUM(p.principal_minor), 0) AS remaining
      FROM loans l LEFT JOIN payments p ON p.loan_id = l.id AND p.reversed = 0
      WHERE l.id = ? GROUP BY l.id
    ''',
      [loanId],
    );
    if (rows.isEmpty) throw StateError('Loan not found');
    return rows.first['remaining'] as int;
  }

  /// Recheck the balance inside the write transaction to prevent overpayment.
  Future<Payment> updatePayment(Payment p) async {
    if (p.id == null ||
        p.reversed ||
        p.reversalOfId != null ||
        p.totalMinor <= 0 ||
        p.principalMinor < 0 ||
        p.interestMinor < 0 ||
        p.totalMinor != p.principalMinor + p.interestMinor) {
      throw ArgumentError('Invalid payment correction');
    }
    _validateDate(p.effectiveDate);
    return db.transaction((txn) async {
      final rows = await txn.query(
        'payments',
        where: 'id = ?',
        whereArgs: [p.id],
      );
      if (rows.isEmpty ||
          rows.first['reversed'] == 1 ||
          rows.first['loan_id'] != p.loanId) {
        throw StateError('Payment cannot be edited');
      }
      final before = rows.first;
      final loans = await txn.query(
        'loans',
        where: 'id = ?',
        whereArgs: [p.loanId],
      );
      if (loans.isEmpty ||
          p.effectiveDate.compareTo(loans.first['start_date'] as String) < 0 ||
          p.effectiveDate.compareTo(
                DateTime.now().toIso8601String().substring(0, 10),
              ) >
              0) {
        throw ArgumentError('Invalid payment date');
      }
      final preview = await previewAllocationInTransaction(
        txn,
        p.loanId,
        p.effectiveDate,
        p.totalMinor,
        excludingPaymentId: p.id,
      );
      if (preview.principalMinor != p.principalMinor ||
          preview.interestMinor != p.interestMinor) {
        throw StateError(
          'Payment changed since preview; review the updated allocation',
        );
      }
      final after = {
        'effective_date': p.effectiveDate,
        'total_minor': p.totalMinor,
        'principal_minor': p.principalMinor,
        'interest_minor': p.interestMinor,
        'note': p.note,
      };
      final now = DateTime.now().millisecondsSinceEpoch;
      await txn.update('payments', after, where: 'id = ?', whereArgs: [p.id]);
      await txn.insert('payment_audit', {
        'payment_id': p.id,
        'action': 'updated',
        'before_json': jsonEncode(before),
        'after_json': jsonEncode(after),
        'effective_at': p.effectiveDate,
        'created_at': now,
      });
      await _refreshLoanStatus(txn, p.loanId, now);
      return Payment(
        id: p.id,
        loanId: p.loanId,
        effectiveDate: p.effectiveDate,
        totalMinor: p.totalMinor,
        principalMinor: p.principalMinor,
        interestMinor: p.interestMinor,
        note: p.note,
        createdAt: p.createdAt,
      );
    });
  }

  Future<PaymentAllocationPreview> previewAllocationInTransaction(
    Transaction txn,
    int loanId,
    String date,
    int total, {
    int? excludingPaymentId,
  }) async {
    final loanRows = await txn.query(
      'loans',
      where: 'id = ?',
      whereArgs: [loanId],
    );
    if (loanRows.isEmpty) throw StateError('Loan not found');
    final loan = loanRows.first;
    final outstanding = await _outstandingPrincipal(
      txn,
      loan,
      loanId,
      excludingPaymentId: excludingPaymentId,
    );
    final accrued = loan['interest_method'] == 'fixed_total'
        ? await _fixedInterestAvailable(txn, loan, loanId, date, outstanding)
        : await _accruedInterestThrough(
            txn,
            loan: loan,
            loanId: loanId,
            asOfDate: date,
            calculator: const InterestCalculator(),
            excludingPaymentId: excludingPaymentId,
          );
    final allocation = const InterestCalculator().allocate(
      paymentTotal: total,
      outstandingPrincipal: outstanding,
      accruedInterest: accrued,
    );
    return PaymentAllocationPreview(
      accruedInterestMinor: accrued,
      outstandingPrincipalMinor: outstanding,
      principalMinor: allocation.principal,
      interestMinor: allocation.interest,
      totalMinor: total,
    );
  }

  Future<void> _refreshLoanStatus(Transaction txn, int loanId, int now) async {
    final loanRows = await txn.query(
      'loans',
      where: 'id = ?',
      whereArgs: [loanId],
    );
    if (loanRows.isEmpty) return;
    final principal = await _paidPrincipal(txn, loanId);
    final unpaidInterest = await _unpaidInterest(txn, loanRows.first, loanId);
    await txn.update(
      'loans',
      {
        'status':
            principal >= (loanRows.first['principal_minor'] as int) &&
                unpaidInterest == 0
            ? 'settled'
            : 'active',
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [loanId],
    );
  }

  Future<int> _fixedInterestDue(
    DatabaseExecutor executor,
    Map<String, Object?> loan,
    int loanId,
    String asOfDate,
  ) async {
    final dues = await executor.rawQuery(
      'SELECT COALESCE(SUM(interest_minor), 0) AS amount FROM scheduled_dues '
      'WHERE loan_id = ? AND due_date <= ?',
      [loanId, asOfDate],
    );
    final totalDues = await executor.rawQuery(
      'SELECT COUNT(*) AS count FROM scheduled_dues WHERE loan_id = ?',
      [loanId],
    );
    if ((totalDues.first['count'] as int) > 0) {
      return dues.first['amount'] as int;
    }
    final maturity = loan['maturity_date'] as String?;
    return maturity == null || maturity.compareTo(asOfDate) > 0
        ? 0
        : loan['fixed_interest_minor'] as int? ?? 0;
  }

  Future<int> _fixedInterestAvailable(
    DatabaseExecutor executor,
    Map<String, Object?> loan,
    int loanId,
    String asOfDate,
    int outstandingPrincipal,
  ) async {
    final due = await _fixedInterestDue(executor, loan, loanId, asOfDate);
    // Once principal is paid, allow collection of the remaining agreed fixed
    // interest before maturity without treating it as already due.
    return outstandingPrincipal == 0
        ? loan['fixed_interest_minor'] as int? ?? 0
        : due;
  }

  Future<int> _unpaidInterest(
    DatabaseExecutor executor,
    Map<String, Object?> loan,
    int loanId,
  ) async {
    final method = loan['interest_method'] as String;
    if (method == 'none') return 0;
    final paid = await _paidInterest(executor, loanId);
    final waived = await _waivedInterest(executor, loanId);
    if (method == 'fixed_total') {
      return ((loan['fixed_interest_minor'] as int? ?? 0) - paid - waived)
          .clamp(0, 1 << 62);
    }
    final accrued = await _accruedInterestThrough(
      executor,
      loan: loan,
      loanId: loanId,
      asOfDate: DateTime.now().toIso8601String().substring(0, 10),
      calculator: const InterestCalculator(),
    );
    final applicableWaiver = method == 'remaining_principal' ? 0 : waived;
    return (accrued - paid - applicableWaiver).clamp(0, 1 << 62);
  }

  Future<Payment> recordNoInterest(Payment p) async {
    if (p.totalMinor <= 0 ||
        p.totalMinor != p.principalMinor ||
        p.interestMinor != 0 ||
        p.reversed ||
        p.reversalOfId != null ||
        DateTime.tryParse(p.effectiveDate)
                ?.toIso8601String()
                .substring(0, 10) !=
            p.effectiveDate) {
      throw ArgumentError('Invalid principal payment');
    }
    return db.transaction((txn) async {
      final loans = await txn.query(
        'loans',
        columns: ['principal_minor', 'interest_method', 'status', 'start_date'],
        where: 'id = ?',
        whereArgs: [p.loanId],
      );
      if (loans.isEmpty ||
          loans.first['interest_method'] != 'none' ||
          loans.first['status'] != 'active' ||
          p.effectiveDate.compareTo(loans.first['start_date'] as String) < 0) {
        throw StateError('Loan cannot accept this payment');
      }
      final paid = await txn.rawQuery(
        '''
        SELECT COALESCE(SUM(principal_minor), 0) AS paid FROM payments
        WHERE loan_id = ? AND reversed = 0
      ''',
        [p.loanId],
      );
      final remaining =
          (loans.first['principal_minor'] as int) - (paid.first['paid'] as int);
      if (p.principalMinor > remaining) {
        throw StateError('Payment exceeds outstanding principal');
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      final id = await txn.insert('payments', {
        'loan_id': p.loanId,
        'effective_date': p.effectiveDate,
        'total_minor': p.totalMinor,
        'principal_minor': p.principalMinor,
        'interest_minor': 0,
        'note': p.note,
        'created_at': now,
      });
      await _refreshLoanStatus(txn, p.loanId, now);
      if (p.principalMinor == remaining) {
        await txn.update(
          'loans',
          {'status': 'settled', 'updated_at': now},
          where: 'id = ?',
          whereArgs: [p.loanId],
        );
      }
      return Payment(
        id: id,
        loanId: p.loanId,
        effectiveDate: p.effectiveDate,
        totalMinor: p.totalMinor,
        principalMinor: p.principalMinor,
        interestMinor: 0,
        note: p.note,
        createdAt: DateTime.fromMillisecondsSinceEpoch(now),
      );
    });
  }

  Future<Payment> insert(Payment p) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = await db.insert('payments', {
      'loan_id': p.loanId,
      'effective_date': p.effectiveDate,
      'total_minor': p.totalMinor,
      'principal_minor': p.principalMinor,
      'interest_minor': p.interestMinor,
      'note': p.note,
      'reversed': p.reversed ? 1 : 0,
      'reversal_of_id': p.reversalOfId,
      'created_at': now,
    });
    return Payment(
      id: id,
      loanId: p.loanId,
      effectiveDate: p.effectiveDate,
      totalMinor: p.totalMinor,
      principalMinor: p.principalMinor,
      interestMinor: p.interestMinor,
      note: p.note,
      reversed: p.reversed,
      reversalOfId: p.reversalOfId,
      createdAt: DateTime.fromMillisecondsSinceEpoch(now),
    );
  }

  Future<List<Payment>> forLoan(int loanId) async {
    final rows = await db.query(
      'payments',
      where: 'loan_id = ?',
      whereArgs: [loanId],
      orderBy: 'effective_date DESC, created_at DESC',
    );
    return rows.map(_fromRow).toList();
  }

  Future<int> totalPaidPrincipal(int loanId) async {
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(principal_minor), 0) as total FROM payments '
      'WHERE loan_id = ? AND reversed = 0',
      [loanId],
    );
    return (result.first['total'] as int?) ?? 0;
  }

  Future<int> totalPaidInterest(int loanId) async {
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(interest_minor), 0) as total FROM payments '
      'WHERE loan_id = ? AND reversed = 0',
      [loanId],
    );
    return (result.first['total'] as int?) ?? 0;
  }

  Future<void> reverse(int paymentId, String reason) async {
    final reversalReason = reason.trim();
    if (reversalReason.isEmpty) {
      throw ArgumentError('Reversal reason is required');
    }
    await db.transaction((txn) async {
      final rows = await txn.query(
        'payments',
        columns: ['loan_id', 'reversed'],
        where: 'id = ?',
        whereArgs: [paymentId],
      );
      if (rows.isEmpty || rows.first['reversed'] == 1) {
        throw StateError('Payment cannot be reversed');
      }
      final loanId = rows.first['loan_id'] as int;
      await txn.update(
        'payments',
        {'reversed': 1, 'reversal_reason': reversalReason},
        where: 'id = ?',
        whereArgs: [paymentId],
      );
      await _refreshLoanStatus(
        txn,
        loanId,
        DateTime.now().millisecondsSinceEpoch,
      );
    });
  }

  Future<Payment> recordInterestBearing(Payment p) async {
    final calculator = const InterestCalculator();
    if (p.totalMinor <= 0 ||
        p.reversed ||
        p.reversalOfId != null ||
        p.principalMinor < 0 ||
        p.interestMinor < 0 ||
        p.totalMinor != p.principalMinor + p.interestMinor ||
        DateTime.tryParse(p.effectiveDate)
                ?.toIso8601String()
                .substring(0, 10) !=
            p.effectiveDate) {
      throw ArgumentError('Invalid payment');
    }
    return db.transaction((txn) async {
      final loans = await txn.query(
        'loans',
        where: 'id = ?',
        whereArgs: [p.loanId],
      );
      if (loans.isEmpty ||
          loans.first['interest_method'] == 'none' ||
          loans.first['status'] != 'active' ||
          p.effectiveDate.compareTo(loans.first['start_date'] as String) < 0) {
        throw StateError('Loan cannot accept this payment');
      }
      final loan = loans.first;
      final paid = await txn.rawQuery(
        'SELECT COALESCE(SUM(principal_minor), 0) AS paid FROM payments WHERE loan_id = ? AND reversed = 0',
        [p.loanId],
      );
      final outstanding =
          (loan['principal_minor'] as int) - (paid.first['paid'] as int);
      if (p.principalMinor > outstanding) {
        throw StateError('Payment exceeds outstanding principal');
      }
      final accrued = loan['interest_method'] == 'fixed_total'
          ? await _fixedInterestAvailable(
              txn,
              loan,
              p.loanId,
              p.effectiveDate,
              outstanding,
            )
          : await _accruedInterestThrough(
              txn,
              loan: loan,
              loanId: p.loanId,
              asOfDate: p.effectiveDate,
              calculator: calculator,
            );
      final allocation = calculator.allocate(
        paymentTotal: p.totalMinor,
        outstandingPrincipal: outstanding,
        accruedInterest: accrued,
      );
      if (allocation.principal != p.principalMinor ||
          allocation.interest != p.interestMinor) {
        throw ArgumentError(
          'Payment allocation does not match interest-first allocation',
        );
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      final id = await txn.insert('payments', {
        'loan_id': p.loanId,
        'effective_date': p.effectiveDate,
        'total_minor': p.totalMinor,
        'principal_minor': p.principalMinor,
        'interest_minor': p.interestMinor,
        'note': p.note,
        'created_at': now,
      });
      await txn.insert('payment_audit', {
        'payment_id': id,
        'action': 'posted',
        'after_json': jsonEncode({
          'effective_date': p.effectiveDate,
          'total_minor': p.totalMinor,
          'principal_minor': p.principalMinor,
          'interest_minor': p.interestMinor,
          'note': p.note,
        }),
        'effective_at': p.effectiveDate,
        'created_at': now,
      });
      await _refreshLoanStatus(txn, p.loanId, now);
      return Payment(
        id: id,
        loanId: p.loanId,
        effectiveDate: p.effectiveDate,
        totalMinor: p.totalMinor,
        principalMinor: p.principalMinor,
        interestMinor: p.interestMinor,
        note: p.note,
        createdAt: DateTime.fromMillisecondsSinceEpoch(now),
      );
    });
  }

  Future<WaiverPreview> previewWaiver(
    int loanId,
    String effectiveDate,
    int amountMinor,
  ) async {
    _validateDate(effectiveDate);
    if (amountMinor <= 0) throw ArgumentError('Waiver must be positive');
    return db.transaction((txn) async {
      final loans = await txn.query(
        'loans',
        where: 'id = ?',
        whereArgs: [loanId],
      );
      if (loans.isEmpty) throw StateError('Loan not found');
      final loan = loans.first;
      final accrued = loan['interest_method'] == 'fixed_total'
          ? loan['fixed_interest_minor'] as int? ?? 0
          : await _accruedInterestThrough(
              txn,
              loan: loan,
              loanId: loanId,
              asOfDate: effectiveDate,
              calculator: const InterestCalculator(),
            );
      final paid = await _paidInterestThrough(txn, loanId, effectiveDate);
      final waived = await _waivedThrough(txn, loanId, effectiveDate);
      final after = waived + amountMinor;
      return WaiverPreview(
        accruedInterestMinor: accrued,
        waivedBeforeMinor: waived,
        waivedAfterMinor: after,
        remainingInterestMinor: accrued - paid - after,
      );
    });
  }

  Future<int> waiveInterest(InterestWaiver waiver) async {
    if (waiver.amountMinor <= 0 ||
        DateTime.tryParse(waiver.waiverDate)
                ?.toIso8601String()
                .substring(0, 10) !=
            waiver.waiverDate) {
      throw ArgumentError('Invalid waiver');
    }
    return db.transaction((txn) async {
      final loans = await txn.query(
        'loans',
        where: 'id = ?',
        whereArgs: [waiver.loanId],
      );
      if (loans.isEmpty ||
          loans.first['status'] != 'active' ||
          loans.first['interest_method'] == 'none' ||
          waiver.waiverDate.compareTo(loans.first['start_date'] as String) <
              0 ||
          waiver.waiverDate.compareTo(
                DateTime.now().toIso8601String().substring(0, 10),
              ) >
              0) {
        throw StateError('Loan cannot be waived');
      }
      final accrued = loans.first['interest_method'] == 'fixed_total'
          ? loans.first['fixed_interest_minor'] as int? ?? 0
          : await _accruedInterestThrough(
              txn,
              loan: loans.first,
              loanId: waiver.loanId,
              asOfDate: waiver.waiverDate,
              calculator: const InterestCalculator(),
            );
      final paidThrough = await _paidInterestThrough(
        txn,
        waiver.loanId,
        waiver.waiverDate,
      );
      final waivedThrough = await _waivedThrough(
        txn,
        waiver.loanId,
        waiver.waiverDate,
      );
      if (waiver.amountMinor > accrued - paidThrough - waivedThrough) {
        throw StateError('Waiver exceeds uncollected accrued interest');
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      final id = await txn.insert('waivers', {
        'loan_id': waiver.loanId,
        'waiver_date': waiver.waiverDate,
        'amount_minor': waiver.amountMinor,
        'note': waiver.note,
        'created_at': now,
      });
      await _refreshLoanStatus(txn, waiver.loanId, now);
      return id;
    });
  }

  Future<int> _paidPrincipal(Transaction txn, int loanId) async {
    final rows = await txn.rawQuery(
      'SELECT COALESCE(SUM(principal_minor), 0) AS amount FROM payments WHERE loan_id = ? AND reversed = 0',
      [loanId],
    );
    return rows.first['amount'] as int;
  }

  Future<int> _paidInterestThrough(
    Transaction txn,
    int loanId,
    String date,
  ) async {
    final rows = await txn.rawQuery(
      'SELECT COALESCE(SUM(interest_minor),0) AS amount FROM payments '
      'WHERE loan_id = ? AND reversed = 0 AND effective_date <= ?',
      [loanId, date],
    );
    return rows.first['amount'] as int;
  }

  Future<int> _waivedThrough(Transaction txn, int loanId, String date) async {
    final rows = await txn.rawQuery(
      'SELECT COALESCE(SUM(amount_minor),0) AS amount FROM waivers '
      'WHERE loan_id = ? AND waiver_date <= ?',
      [loanId, date],
    );
    return rows.first['amount'] as int;
  }

  Future<int> _paidInterest(DatabaseExecutor txn, int loanId) async {
    final rows = await txn.rawQuery(
      'SELECT COALESCE(SUM(interest_minor), 0) AS amount FROM payments WHERE loan_id = ? AND reversed = 0',
      [loanId],
    );
    return rows.first['amount'] as int;
  }

  Future<int> _waivedInterest(DatabaseExecutor txn, int loanId) async {
    final rows = await txn.rawQuery(
      'SELECT COALESCE(SUM(amount_minor), 0) AS amount FROM waivers WHERE loan_id = ?',
      [loanId],
    );
    return rows.first['amount'] as int;
  }

  Payment _fromRow(Map<String, dynamic> row) => Payment(
    id: row['id'] as int,
    loanId: row['loan_id'] as int,
    effectiveDate: row['effective_date'] as String,
    totalMinor: row['total_minor'] as int,
    principalMinor: row['principal_minor'] as int,
    interestMinor: row['interest_minor'] as int,
    note: row['note'] as String?,
    reversed: (row['reversed'] as int) == 1,
    reversalOfId: row['reversal_of_id'] as int?,
    reversalReason: row['reversal_reason'] as String?,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
  );
}
