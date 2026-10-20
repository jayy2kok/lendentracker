import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

const _kDbKeyAlias = 'ldt_db_key';
const _kDbVersion = 5;
const _kDbName = 'lenden_tracker.db';

/// Opens (or creates) the encrypted SQLite database.
/// The key is generated once on first launch and stored in Keychain / Keystore;
/// it is never written to the database file or logs.
class AppDatabase {
  AppDatabase._();
  static AppDatabase? _instance;
  static AppDatabase get instance => _instance!;

  late final Database _db;
  Database get db => _db;

  static Future<void> initialize() async {
    if (_instance != null) return;
    final dbInstance = AppDatabase._();
    try {
      await dbInstance._open();
      _instance = dbInstance;
    } catch (_) {
      _instance = null;
      rethrow;
    }
  }

  Future<void> _open() async {
    final key = await _resolveKey();
    final docsDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(docsDir.path, _kDbName);

    _db = await openDatabase(
      dbPath,
      version: _kDbVersion,
      password: key,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );
  }

  static Future<String> _resolveKey() async {
    const storage = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
      ),
    );
    var key = await storage.read(key: _kDbKeyAlias);
    if (key == null) {
      key = _generateKey(32);
      await storage.write(key: _kDbKeyAlias, value: key);
    }
    return key;
  }

  static String _generateKey(int bytes) {
    final rng = Random.secure();
    final buf = List<int>.generate(bytes, (_) => rng.nextInt(256));
    // hex-encode for use as SQLCipher passphrase
    return buf.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  static Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    // ── People ──────────────────────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE people (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        display_name  TEXT    NOT NULL,
        phone_e164    TEXT    NOT NULL,
        contact_id    TEXT,               -- OS contact identifier (nullable)
        created_at    INTEGER NOT NULL    -- Unix milliseconds
      )
    ''');

    // ── Loans ────────────────────────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE loans (
        id                  INTEGER PRIMARY KEY AUTOINCREMENT,
        person_id           INTEGER NOT NULL REFERENCES people(id),
        direction           TEXT    NOT NULL CHECK(direction IN ('lent','borrowed')),
        principal_minor     INTEGER NOT NULL,  -- in minor currency units
        currency            TEXT    NOT NULL DEFAULT 'INR',
        start_date          TEXT    NOT NULL,  -- ISO 8601 date YYYY-MM-DD
        maturity_date       TEXT,
        interest_method     TEXT    NOT NULL
                              CHECK(interest_method IN (
                                'none','fixed_total','original_principal','remaining_principal'
                              )),
        interest_rate       REAL,              -- NULL for none
        rate_period         TEXT CHECK(rate_period IN ('monthly','annual')),
        fixed_interest_minor INTEGER,          -- for fixed_total method
        payment_schedule    TEXT NOT NULL
                              CHECK(payment_schedule IN (
                                'flexible','at_maturity','regular','interest_only'
                              )),
        installment_amount_minor INTEGER,
        first_due_date      TEXT,
        monthly_anchor_date TEXT,
        continue_after_maturity INTEGER NOT NULL DEFAULT 0,
        notes               TEXT,
        status              TEXT NOT NULL DEFAULT 'active'
                              CHECK(status IN ('active','settled','waived')),
        created_at          INTEGER NOT NULL,
        updated_at          INTEGER NOT NULL
      )
    ''');

    // ── Loan amendments ──────────────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE loan_amendments (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        loan_id     INTEGER NOT NULL REFERENCES loans(id),
        amended_at  TEXT    NOT NULL,    -- effective date YYYY-MM-DD
        field_name  TEXT    NOT NULL,
        old_value   TEXT,
        new_value   TEXT,
        note        TEXT,
        created_at  INTEGER NOT NULL
      )
    ''');

    // ── Scheduled dues ────────────────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE scheduled_dues (
        id                  INTEGER PRIMARY KEY AUTOINCREMENT,
        loan_id             INTEGER NOT NULL REFERENCES loans(id),
        due_date            TEXT    NOT NULL,
        principal_minor     INTEGER NOT NULL DEFAULT 0,
        interest_minor      INTEGER NOT NULL DEFAULT 0,
        status              TEXT    NOT NULL DEFAULT 'upcoming'
                              CHECK(status IN ('upcoming','paid','overdue','waived'))
      )
    ''');

    // ── Payments ─────────────────────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE payments (
        id                  INTEGER PRIMARY KEY AUTOINCREMENT,
        loan_id             INTEGER NOT NULL REFERENCES loans(id),
        effective_date      TEXT    NOT NULL,
        total_minor         INTEGER NOT NULL,
        principal_minor     INTEGER NOT NULL DEFAULT 0,
        interest_minor      INTEGER NOT NULL DEFAULT 0,
        note                TEXT,
        reversed            INTEGER NOT NULL DEFAULT 0,  -- boolean 0/1
        reversal_of_id      INTEGER REFERENCES payments(id),
        reversal_reason     TEXT,
        created_at          INTEGER NOT NULL
      )
    ''');

    // ── Interest waivers ─────────────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE waivers (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        loan_id         INTEGER NOT NULL REFERENCES loans(id),
        waiver_date     TEXT    NOT NULL,
        amount_minor    INTEGER NOT NULL,
        note            TEXT,
        created_at      INTEGER NOT NULL
      )
    ''');

    // ── App settings (single-row) ─────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE app_settings (
        id                    INTEGER PRIMARY KEY CHECK(id = 1),
        theme_mode            TEXT    NOT NULL DEFAULT 'system',
        app_lock_enabled      INTEGER NOT NULL DEFAULT 0,
        last_backup_at        INTEGER,
        default_currency      TEXT    NOT NULL DEFAULT 'INR'
      )
    ''');
    batch.insert('app_settings', {'id': 1});

    // ── Indices ───────────────────────────────────────────────────────────────
    batch.execute('CREATE INDEX idx_loans_person ON loans(person_id)');
    batch.execute('CREATE INDEX idx_loans_status ON loans(status)');
    batch.execute('CREATE INDEX idx_payments_loan ON payments(loan_id)');
    batch.execute('CREATE INDEX idx_payments_date ON payments(effective_date)');
    batch.execute('CREATE INDEX idx_dues_loan ON scheduled_dues(loan_id)');
    batch.execute('CREATE INDEX idx_dues_date ON scheduled_dues(due_date)');

    await batch.commit(noResult: true);
    await _ensureLedgerSchema(db);
  }

  static Future<void> _ensureLedgerSchema(Database db) async {
    final batch = db.batch();
    batch.execute('''
      CREATE TABLE IF NOT EXISTS payment_audit (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        payment_id INTEGER NOT NULL,
        action TEXT NOT NULL,
        before_json TEXT,
        after_json TEXT,
        effective_at TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    batch.execute('''
      CREATE INDEX IF NOT EXISTS idx_payment_audit_payment
      ON payment_audit(payment_id, effective_at)
    ''');
    batch.execute('''
      CREATE INDEX IF NOT EXISTS idx_amendments_loan_date
      ON loan_amendments(loan_id, amended_at, id)
    ''');
    batch.execute('''
      CREATE INDEX IF NOT EXISTS idx_waivers_loan_date
      ON waivers(loan_id, waiver_date, id)
    ''');
    await batch.commit(noResult: true);
  }

  static Future<void> _onUpgrade(Database db, int oldV, int newV) async {
    final migrations = <int, Future<void> Function(Database)>{
      2: (db) async {
        await db.execute('''
          CREATE TABLE payment_audit (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            payment_id INTEGER NOT NULL,
            action TEXT NOT NULL,
            before_json TEXT,
            after_json TEXT,
            effective_at TEXT NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');
      },
      3: _ensureLedgerSchema,
      4: (db) async {
        await _migrateLoanTerms(db);
        await _ensureLedgerSchema(db);
      },
      5: (db) =>
          db.execute('ALTER TABLE payments ADD COLUMN reversal_reason TEXT'),
    };
    for (var version = oldV + 1; version <= newV; version++) {
      final migration = migrations[version];
      if (migration == null) {
        throw StateError('Missing database migration for version $version');
      }
      await migration(db);
    }
  }

  static Future<void> _migrateLoanTerms(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(loans)');
    final names = columns.map((column) => column['name']).toSet();
    if (!names.contains('monthly_anchor_date')) {
      await db.execute('ALTER TABLE loans ADD COLUMN monthly_anchor_date TEXT');
    }
    if (!names.contains('continue_after_maturity')) {
      await db.execute(
        'ALTER TABLE loans ADD COLUMN continue_after_maturity INTEGER NOT NULL DEFAULT 0',
      );
    }
  }

  Future<void> close() async {
    await _db.close();
    AppDatabase._instance = null;
  }

  static const _backupTables = <String>[
    'people',
    'loans',
    'loan_amendments',
    'scheduled_dues',
    'payments',
    'waivers',
    'app_settings',
    'payment_audit',
  ];

  static const _parentFirstTables = <String>[
    'people',
    'loans',
    'loan_amendments',
    'scheduled_dues',
    'payments',
    'waivers',
    'app_settings',
    'payment_audit',
  ];

  static Future<void> restoreFromBytes(List<int> bytes) async {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic> ||
        decoded['format'] != 'lenden-tracker-logical-db' ||
        decoded['version'] != 1 ||
        decoded['dbVersion'] is! int ||
        (decoded['dbVersion'] as int) < 1 ||
        (decoded['dbVersion'] as int) > _kDbVersion ||
        decoded['tables'] is! Map<String, dynamic>) {
      throw const FormatException('Unsupported or invalid database backup.');
    }
    final tables = Map<String, dynamic>.from(decoded['tables'] as Map);
    final allowed = _backupTables.toSet();
    const required = {
      'people',
      'loans',
      'loan_amendments',
      'scheduled_dues',
      'payments',
      'waivers',
      'app_settings',
    };
    if (tables.keys.toSet().difference(allowed).isNotEmpty ||
        required.any((table) => tables[table] is! List) ||
        (tables.containsKey('payment_audit') &&
            tables['payment_audit'] is! List)) {
      throw const FormatException('Backup is missing or has unknown tables.');
    }
    tables.putIfAbsent('payment_audit', () => <dynamic>[]);
    for (final table in _backupTables) {
      for (final row in tables[table] as List) {
        if (row is! Map<String, dynamic> ||
            row.keys.any(
              (key) => !RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(key),
            )) {
          throw const FormatException('Invalid row in database backup.');
        }
      }
    }
    _validateSnapshotTables(tables);
    await instance.db.transaction((txn) async {
      await txn.execute('PRAGMA defer_foreign_keys = ON');
      for (final table in _backupTables.reversed) {
        await txn.delete(table);
      }
      for (final table in _parentFirstTables) {
        for (final rawRow in tables[table] as List) {
          final row = Map<String, Object?>.from(rawRow as Map);
          await txn.insert(table, row);
        }
      }
      final violations = await txn.rawQuery('PRAGMA foreign_key_check');
      if (violations.isNotEmpty) {
        throw const FormatException(
          'Backup contains invalid record references.',
        );
      }
    });
  }

  static void _validateSnapshotTables(Map<String, dynamic> tables) {
    final people = <int, Map<String, dynamic>>{};
    final loans = <int, Map<String, dynamic>>{};
    final payments = <int, Map<String, dynamic>>{};
    void indexRows(String table, Map<int, Map<String, dynamic>> target) {
      for (final raw in tables[table] as List) {
        final row = Map<String, dynamic>.from(raw as Map);
        final id = row['id'];
        if (id is! int || id <= 0 || target.containsKey(id)) {
          throw FormatException('Invalid or duplicate $table id.');
        }
        target[id] = row;
      }
    }

    indexRows('people', people);
    indexRows('loans', loans);
    indexRows('payments', payments);
    final personPhones = <String>{};
    for (final row in people.values) {
      if ((row['display_name'] as String? ?? '').trim().isEmpty ||
          (row['phone_e164'] as String? ?? '').trim().isEmpty ||
          !personPhones.add(row['phone_e164'] as String)) {
        throw const FormatException('Invalid or duplicate contact.');
      }
    }
    final principalPaid = <int, int>{};
    for (final row in loans.values) {
      final principal = row['principal_minor'];
      if (!people.containsKey(row['person_id']) ||
          principal is! int ||
          principal <= 0 ||
          (row['currency'] as String? ?? '').length != 3 ||
          !const {'lent', 'borrowed'}.contains(row['direction']) ||
          !_validIsoDate(row['start_date']) ||
          row['maturity_date'] != null &&
              (!_validIsoDate(row['maturity_date']) ||
                  (row['maturity_date'] as String).compareTo(
                        row['start_date'] as String,
                      ) <
                      0) ||
          !const {
            'none',
            'fixed_total',
            'original_principal',
            'remaining_principal',
          }.contains(row['interest_method']) ||
          !const {
            'flexible',
            'at_maturity',
            'regular',
            'interest_only',
          }.contains(row['payment_schedule'])) {
        throw const FormatException('Invalid loan in backup.');
      }
    }
    for (final row in payments.values) {
      final loan = loans[row['loan_id']];
      final total = row['total_minor'];
      final principal = row['principal_minor'];
      final interest = row['interest_minor'];
      if (loan == null ||
          !_validIsoDate(row['effective_date']) ||
          total is! int ||
          principal is! int ||
          interest is! int ||
          total <= 0 ||
          principal < 0 ||
          interest < 0 ||
          total != principal + interest ||
          (row['reversed'] != 0 && row['reversed'] != 1) ||
          row['effective_date'].compareTo(loan['start_date']) < 0 ||
          principal > loan['principal_minor']) {
        throw const FormatException('Invalid payment in backup.');
      }
      if ((row['reversed'] as int) == 0) {
        principalPaid.update(
          row['loan_id'] as int,
          (value) => value + principal,
          ifAbsent: () => principal,
        );
      }
    }
    for (final entry in principalPaid.entries) {
      if (entry.value > (loans[entry.key]!['principal_minor'] as int)) {
        throw const FormatException(
          'Payments exceed loan principal in backup.',
        );
      }
    }
    for (final row in tables['scheduled_dues'] as List) {
      final due = Map<String, dynamic>.from(row as Map);
      final loan = loans[due['loan_id']];
      if (loan == null ||
          !_validIsoDate(due['due_date']) ||
          due['principal_minor'] is! int ||
          due['principal_minor'] < 0 ||
          due['interest_minor'] is! int ||
          due['interest_minor'] < 0 ||
          due['principal_minor'] + due['interest_minor'] <= 0 ||
          due['due_date'].compareTo(loan['start_date']) <= 0 ||
          loan['maturity_date'] != null &&
              due['due_date'].compareTo(loan['maturity_date']) > 0) {
        throw const FormatException('Invalid scheduled due in backup.');
      }
    }
    for (final table in ['loan_amendments', 'waivers']) {
      for (final raw in tables[table] as List) {
        final row = Map<String, dynamic>.from(raw as Map);
        if (!loans.containsKey(row['loan_id']) ||
            !_validIsoDate(
              table == 'waivers' ? row['waiver_date'] : row['amended_at'],
            ) ||
            table == 'waivers' &&
                (row['amount_minor'] is! int || row['amount_minor'] <= 0)) {
          throw FormatException('Invalid $table row in backup.');
        }
      }
    }
    for (final raw in tables['payment_audit'] as List) {
      final row = Map<String, dynamic>.from(raw as Map);
      if (!payments.containsKey(row['payment_id']) ||
          !_validIsoDate(row['effective_at'])) {
        throw const FormatException('Invalid payment audit row in backup.');
      }
    }
    if ((tables['app_settings'] as List).length != 1 ||
        (tables['app_settings'] as List).first['id'] != 1) {
      throw const FormatException('Invalid application settings row.');
    }
  }

  static bool _validIsoDate(Object? value) {
    if (value is! String) return false;
    final date = DateTime.tryParse(value);
    return date != null && date.toIso8601String().substring(0, 10) == value;
  }

  /// Exports logical table data, never the device-key-encrypted SQLCipher file.
  Future<List<int>> exportSnapshot() async {
    final tables = <String, List<Map<String, Object?>>>{};
    await _db.transaction((txn) async {
      for (final table in _backupTables) {
        final exists = await txn.rawQuery(
          "SELECT 1 FROM sqlite_master WHERE type='table' AND name=?",
          [table],
        );
        if (exists.isEmpty) {
          if (table == 'payment_audit') {
            tables[table] = [];
            continue;
          }
          throw StateError('Required backup table $table is missing.');
        }
        final rows = await txn.query(table);
        tables[table] = rows
            .map((row) => Map<String, Object?>.from(row))
            .toList();
      }
    });
    return utf8.encode(
      jsonEncode({
        'format': 'lenden-tracker-logical-db',
        'version': 1,
        'dbVersion': _kDbVersion,
        'tables': tables,
      }),
    );
  }
}
