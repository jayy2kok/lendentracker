import 'package:csv/csv.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class CsvExportService {
  static String sanitize(dynamic value) {
    if (value == null) return '';
    final str = value.toString();
    if (str.isEmpty) return '';
    final normalized = str.replaceFirst(RegExp(r'^[\u0000-\u0020]+'), '');
    const formulaTriggers = ['=', '+', '-', '@'];
    if (normalized != str ||
        formulaTriggers.any((t) => normalized.startsWith(t))) {
      return "'$str";
    }
    return str;
  }

  static Future<String> generateLoansAndPaymentsCsv(Database db) async {
    final loanRows = await db.rawQuery('''
      SELECT l.id, p.display_name, l.direction, l.principal_minor, l.currency,
             l.start_date, l.maturity_date, l.interest_method, l.interest_rate,
             l.rate_period, l.fixed_interest_minor, l.payment_schedule, l.status, l.notes
      FROM loans l
      JOIN people p ON p.id = l.person_id
      ORDER BY l.id ASC
    ''');

    final paymentRows = await db.rawQuery('''
      SELECT p.id, p.loan_id, p.effective_date, p.total_minor, p.principal_minor,
             p.interest_minor, p.note, p.reversed, p.reversal_reason
      FROM payments p
      ORDER BY p.id ASC
    ''');

    final List<List<dynamic>> rows = [];

    // Loans section header
    rows.add(['--- LOANS ---']);
    rows.add([
      'Loan ID',
      'Person',
      'Direction',
      'Principal',
      'Currency',
      'Start Date',
      'Maturity Date',
      'Interest Method',
      'Interest Rate',
      'Rate Period',
      'Fixed Interest',
      'Schedule',
      'Status',
      'Notes',
    ]);

    for (final l in loanRows) {
      rows.add([
        l['id'],
        sanitize(l['display_name']),
        l['direction'],
        l['principal_minor'],
        l['currency'],
        l['start_date'],
        sanitize(l['maturity_date']),
        l['interest_method'],
        l['interest_rate'],
        sanitize(l['rate_period']),
        l['fixed_interest_minor'],
        l['payment_schedule'],
        l['status'],
        sanitize(l['notes']),
      ]);
    }

    rows.add([]);
    rows.add(['--- PAYMENTS ---']);
    rows.add([
      'Payment ID',
      'Loan ID',
      'Effective Date',
      'Total Minor',
      'Principal Minor',
      'Interest Minor',
      'Note',
      'Reversed',
      'Reversal reason',
    ]);

    for (final p in paymentRows) {
      rows.add([
        p['id'],
        p['loan_id'],
        p['effective_date'],
        p['total_minor'],
        p['principal_minor'],
        p['interest_minor'],
        sanitize(p['note']),
        p['reversed'],
        sanitize(p['reversal_reason']),
      ]);
    }

    return Csv().encode(rows);
  }
}
