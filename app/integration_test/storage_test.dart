import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lenden_tracker/core/database/app_database.dart';
import 'package:lenden_tracker/core/security/encrypted_backup.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'encrypted storage survives restart and rejects invalid restore',
    (tester) async {
      final directory = await getApplicationDocumentsDirectory();
      // Never perform restore tests in the installed personal ledger.
      expect(directory.path, contains('.acceptance'));
      await AppDatabase.initialize();
      var database = AppDatabase.instance;
      final original = await database.exportSnapshot();
      final before = jsonDecode(utf8.decode(original));
      await database.db.insert('people', {
        'display_name': 'Synthetic acceptance contact',
        'phone_e164': '+12025550123',
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
      final populated = jsonDecode(
        utf8.decode(await database.exportSnapshot()),
      );
      final cipher = await database.db.rawQuery('PRAGMA cipher_version');
      expect(cipher, isNotEmpty);
      expect(cipher.first.values.first.toString(), isNotEmpty);
      final bytes = await File(database.db.path).readAsBytes();
      expect(bytes.length, greaterThan(16));
      expect(
        utf8.decode(bytes.take(16).toList(), allowMalformed: true),
        isNot('SQLite format 3\u0000'),
      );

      await database.close();
      await AppDatabase.initialize();
      database = AppDatabase.instance;
      expect(
        jsonDecode(utf8.decode(await database.exportSnapshot())),
        populated,
      );

      final invalid = jsonDecode(utf8.decode(original)) as Map<String, dynamic>;
      invalid['dbVersion'] = 999999;
      await expectLater(
        AppDatabase.restoreFromBytes(utf8.encode(jsonEncode(invalid))),
        throwsA(isA<FormatException>()),
      );
      expect(
        jsonDecode(utf8.decode(await database.exportSnapshot())),
        populated,
      );

      const passphrase = 'Synthetic acceptance backup phrase';
      final encrypted = await EncryptedBackup.encrypt(original, passphrase);
      await expectLater(
      EncryptedBackup.decrypt(encrypted, 'Incorrect synthetic passphrase'),
      throwsA(anything),
    );
    expect(jsonDecode(utf8.decode(await database.exportSnapshot())), populated);
    final decoded = await EncryptedBackup.decrypt(encrypted, passphrase);
      await AppDatabase.restoreFromBytes(decoded);
      expect(jsonDecode(utf8.decode(await database.exportSnapshot())), before);
      await database.close();
    },
  );
}
