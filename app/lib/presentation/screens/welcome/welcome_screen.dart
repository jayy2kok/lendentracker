import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';

import '../../../core/security/encrypted_backup.dart';
import '../../../core/database/app_database.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/router/app_router.dart';

/// First-launch screen shown before the ledger is created.
/// Offers "Create private ledger" and "Restore backup".
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: LdtSpacing.lg,
            vertical: LdtSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // ── LDT logo ──────────────────────────────────────────────────
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: LdtColors.primary,
                    borderRadius: BorderRadius.circular(LdtRadius.xl),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'LDT',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: LdtSpacing.lg),
              Text(
                'LenDen Tracker',
                semanticsLabel: 'LenDen Tracker, private loan ledger',
                style: LdtTextStyles.displayLarge.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: LdtSpacing.sm),
              Text(
                'Your private loan ledger.\nAll data stays on this phone.',
                style: LdtTextStyles.bodyLarge.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 2),
              FilledButton(
                onPressed: () => _createLedger(context),
                child: const Text('Create private ledger'),
              ),
              const SizedBox(height: LdtSpacing.sm),
              OutlinedButton(
                onPressed: () => _restoreBackup(context),
                child: const Text('Restore from backup'),
              ),
              const SizedBox(height: LdtSpacing.lg),
              Text(
                'No account, no cloud sync, no data sharing.',
                style: LdtTextStyles.caption.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createLedger(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ledger_created', true);
    if (context.mounted) context.go(AppRoutes.home);
  }

  Future<void> _restoreBackup(BuildContext context) async {
    final selection = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['ldtbackup'],
      withData: true,
    );
    if (selection == null || !context.mounted) return;
    final backupFile = selection.files.single;
    if (backupFile.size <= 0 ||
        backupFile.size > EncryptedBackup.maxBackupBytes ||
        backupFile.bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Backup file is unreadable or too large.'),
        ),
      );
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final passphrase = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Decrypt backup'),
          content: TextField(
            controller: controller,
            obscureText: true,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Passphrase (8+ characters)',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => controller.text.length >= 8
                  ? Navigator.pop(ctx, controller.text)
                  : null,
              child: const Text('Decrypt'),
            ),
          ],
        );
      },
    );
    if (passphrase == null || !context.mounted) return;
    Uint8List clear;
    try {
      clear = await EncryptedBackup.decrypt(backupFile.bytes!, passphrase);
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Restore failed: $e')));
      }
      return;
    }
    if (!context.mounted) return;
    final snapshot = jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
    final tables = snapshot['tables'] as Map<String, dynamic>;
    final peopleCount = (tables['people'] as List).length;
    final loansCount = (tables['loans'] as List).length;
    final paymentsCount = (tables['payments'] as List).length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore backup?'),
        content: Text(
          'Backup contains $peopleCount people, $loansCount loans, and $paymentsCount payments. Restore it to this device?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await AppDatabase.restoreFromBytes(clear);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('ledger_created', true);
      if (context.mounted) context.go(AppRoutes.home);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Restore failed: $e')));
      }
    }
  }
}
