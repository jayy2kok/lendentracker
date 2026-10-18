import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

class EncryptedBackup {
  static const maxBackupBytes = 64 * 1024 * 1024;
  static const _format = 'lenden-tracker-backup';
  static const _version = 1;

  static void _validateLogicalSnapshot(List<int> clear) {
    try {
      final value = jsonDecode(utf8.decode(clear));
      if (value is! Map<String, dynamic> ||
          value['format'] != 'lenden-tracker-logical-db' ||
          value['version'] != 1 ||
          value['dbVersion'] is! int ||
          (value['dbVersion'] as int) < 1 ||
          (value['dbVersion'] as int) > 4 ||
          value['tables'] is! Map<String, dynamic>) {
        throw const FormatException('Unsupported database backup.');
      }
      const required = {
        'people',
        'loans',
        'loan_amendments',
        'scheduled_dues',
        'payments',
        'waivers',
        'app_settings',
      };
      const allowed = {...required, 'payment_audit'};
      final tables = value['tables'] as Map<String, dynamic>;
      if (tables.keys.toSet().difference(allowed).isNotEmpty ||
          required.any((table) => tables[table] is! List) ||
          (tables.containsKey('payment_audit') &&
              tables['payment_audit'] is! List)) {
        throw const FormatException('Backup tables are incomplete or unknown.');
      }
      for (final rows in tables.values) {
        for (final row in rows as List) {
          if (row is! Map<String, dynamic>) {
            throw const FormatException('Invalid database backup row.');
          }
        }
      }
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Invalid database backup.');
    }
  }

  static const _iterations = 310000;
  static final _pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: _iterations,
    bits: 256,
  );
  static final _cipher = AesGcm.with256bits();

  static Future<Uint8List> encrypt(
    List<int> databaseBytes,
    String passphrase, {
    Random? random,
  }) async {
    if (passphrase.length < 8) {
      throw const FormatException('Passphrase must be at least 8 characters.');
    }
    final rng = random ?? Random.secure();
    final salt = List<int>.generate(16, (_) => rng.nextInt(256));
    final nonce = List<int>.generate(12, (_) => rng.nextInt(256));
    final key = await _pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: salt,
    );
    final box = await _cipher.encrypt(
      databaseBytes,
      secretKey: key,
      nonce: nonce,
      aad: utf8.encode('$_format:$_version'),
    );
    return Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'format': _format,
          'version': _version,
          'kdf': 'pbkdf2-sha256',
          'iterations': _iterations,
          'salt': base64Encode(salt),
          'nonce': base64Encode(nonce),
          'ciphertext': base64Encode(box.cipherText),
          'mac': base64Encode(box.mac.bytes),
        }),
      ),
    );
  }

  static Future<Uint8List> decrypt(
    List<int> backupBytes,
    String passphrase,
  ) async {
    if (backupBytes.isEmpty || backupBytes.length > maxBackupBytes) {
      throw const FormatException('Backup file is empty or too large.');
    }
    try {
      final json = jsonDecode(utf8.decode(backupBytes)) as Map<String, dynamic>;
      if (json['format'] != _format ||
          json['version'] != _version ||
          json['kdf'] != 'pbkdf2-sha256' ||
          json['iterations'] != _iterations) {
        throw const FormatException('Unsupported backup format.');
      }
      List<int> bytes(String key, int length) {
        final value = base64Decode(json[key] as String);
        if (value.length != length) {
          throw const FormatException('Invalid backup data.');
        }
        return value;
      }

      final salt = bytes('salt', 16);
      final nonce = bytes('nonce', 12);
      final ciphertext = base64Decode(json['ciphertext'] as String);
      final mac = bytes('mac', 16);
      final key = await _pbkdf2.deriveKey(
        secretKey: SecretKey(utf8.encode(passphrase)),
        nonce: salt,
      );
      final clear = await _cipher.decrypt(
        SecretBox(ciphertext, nonce: nonce, mac: Mac(mac)),
        secretKey: key,
        aad: utf8.encode('$_format:$_version'),
      );
      if (clear.length < 100 || clear.length > 512 * 1024 * 1024) {
        throw const FormatException('Backup size is invalid.');
      }
      _validateLogicalSnapshot(clear);
      return Uint8List.fromList(clear);
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException(
        'Backup is invalid or the passphrase is incorrect.',
      );
    }
  }
}
