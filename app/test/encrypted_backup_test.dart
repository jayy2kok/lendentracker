import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lenden_tracker/core/security/encrypted_backup.dart';

void main() {
  final snapshot = <int>[
    ...'{"format":"lenden-tracker-logical-db","version":1,"dbVersion":2,"tables":{"people":[],"loans":[],"loan_amendments":[],"scheduled_dues":[],"payments":[],"waivers":[],"app_settings":[],"payment_audit":[]}}'
        .codeUnits,
  ];

  test('encrypted logical backup round-trips with passphrase', () async {
    final encoded = await EncryptedBackup.encrypt(
      snapshot,
      'correct horse battery',
    );
    expect(
      String.fromCharCodes(encoded),
      isNot(contains('lenden-tracker-logical-db')),
    );
    expect(
      await EncryptedBackup.decrypt(encoded, 'correct horse battery'),
      snapshot,
    );
  });

  test('rejects backup inputs above the configured size bound', () async {
    expect(EncryptedBackup.maxBackupBytes, 64 * 1024 * 1024);
    await expectLater(
      EncryptedBackup.decrypt(
        List<int>.filled(EncryptedBackup.maxBackupBytes + 1, 0),
        'passphrase',
      ),
      throwsFormatException,
    );
  });

  test('rejects invalid passphrase length and wrong key', () async {
    await expectLater(
      EncryptedBackup.encrypt(snapshot, 'short'),
      throwsFormatException,
    );
    final encoded = await EncryptedBackup.encrypt(
      snapshot,
      'correct horse battery',
    );
    await expectLater(
      EncryptedBackup.decrypt(encoded, 'wrong passphrase'),
      throwsFormatException,
    );
  });

  test(
    'rejects tampering, corruption, and unknown envelope versions',
    () async {
      final encoded = await EncryptedBackup.encrypt(
        snapshot,
        'strong passphrase',
      );
      final envelope =
          jsonDecode(String.fromCharCodes(encoded)) as Map<String, dynamic>;
      final tampered = Map<String, dynamic>.from(envelope);
      tampered['ciphertext'] = base64Encode(
        base64Decode(envelope['ciphertext'] as String)..[0] ^= 1,
      );
      await expectLater(
        EncryptedBackup.decrypt(
          utf8.encode(jsonEncode(tampered)),
          'strong passphrase',
        ),
        throwsFormatException,
      );
      final unknownVersion = Map<String, dynamic>.from(envelope)
        ..['version'] = 99;
      await expectLater(
        EncryptedBackup.decrypt(
          utf8.encode(jsonEncode(unknownVersion)),
          'strong passphrase',
        ),
        throwsFormatException,
      );
      final unknownSnapshot = utf8.encode(
        '{"format":"lenden-tracker-logical-db","version":1,"dbVersion":4,"tables":{}}',
      );
      final encryptedUnknown = await EncryptedBackup.encrypt(
        unknownSnapshot,
        'strong passphrase',
      );
      await expectLater(
        EncryptedBackup.decrypt(encryptedUnknown, 'strong passphrase'),
        throwsFormatException,
      );
    },
  );

  test('rejects malformed and corrupted snapshot payloads', () async {
    await expectLater(
      EncryptedBackup.decrypt([1, 2, 3], 'passphrase'),
      throwsFormatException,
    );
    final encoded = await EncryptedBackup.encrypt(
      utf8.encode('not a logical database snapshot'),
      'passphrase',
    );
    await expectLater(
      EncryptedBackup.decrypt(encoded, 'passphrase'),
      throwsFormatException,
    );
  });
}
