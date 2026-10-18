import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/security/encrypted_backup.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/security/app_lock_provider.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/csv_export.dart';

/// Settings screen â€” theme, app lock, contact help, backup/restore/export.
/// Full implementation: Phase 4.9
final _lastBackupProvider = FutureProvider<DateTime?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final value = prefs.getString('last_backup_at');
  return value == null ? null : DateTime.tryParse(value);
});

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _pruneSharedFiles() async {
    final temp = await getTemporaryDirectory();
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    await for (final entity in temp.list()) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      if (!name.startsWith('lendentracker_') ||
          !(name.endsWith('.ldtbackup') || name.endsWith('.csv'))) {
        continue;
      }
      try {
        if ((await entity.stat()).modified.isBefore(cutoff)) {
          await entity.delete();
        }
      } on FileSystemException {
        // A stale export is best-effort cleanup; do not block a new operation.
      }
    }
  }

  Future<void> _exportBackup(BuildContext context, WidgetRef ref) async {
    try {
      await _pruneSharedFiles();
    } catch (_) {
      // A transient cache cleanup failure must not prevent manual backup.
    }
    if (!context.mounted) return;
    final pass = await _passphraseDialog(context, confirmation: true);
    if (pass == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final dbBytes = await AppDatabase.instance.exportSnapshot();
      final encrypted = await EncryptedBackup.encrypt(dbBytes, pass);
      final temp = await getTemporaryDirectory();
      final file = File(
        '${temp.path}/lendentracker_${DateTime.now().millisecondsSinceEpoch}.ldtbackup',
      );
      await file.writeAsBytes(encrypted, flush: true);
      final result = await Share.shareXFiles([
        XFile(file.path),
      ], subject: 'LenDen Tracker encrypted backup');
      if (result.status == ShareResultStatus.success) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'last_backup_at',
          DateTime.now().toIso8601String(),
        );
        ref.invalidate(_lastBackupProvider);
      }
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Backup failed: $e')));
      }
    }
  }

  Future<void> _importBackup(BuildContext context) async {
    try {
      await _pruneSharedFiles();
    } catch (_) {
      // Continue; cleanup is best-effort.
    }
    final selection = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['ldtbackup'],
      withData: true,
    );
    if (selection == null || !context.mounted) return;
    final file = selection.files.single;
    if (file.size <= 0 || file.size > EncryptedBackup.maxBackupBytes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup file is empty or too large.')),
      );
      return;
    }
    if (file.bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read the selected backup.')),
      );
      return;
    }
    final pass = await _passphraseDialog(context);
    if (pass == null || !context.mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Replace ledger?'),
        content: const Text(
          'Restoring will replace all current ledger data. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Replace'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final clear = await EncryptedBackup.decrypt(file.bytes!, pass);
      final snapshot = jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
      final tables = snapshot['tables'] as Map<String, dynamic>;
      final peopleCount = (tables['people'] as List).length;
      final loansCount = (tables['loans'] as List).length;
      final paymentsCount = (tables['payments'] as List).length;
      if (!context.mounted) return;
      final restoreConfirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirm restore'),
          content: Text(
            'This backup contains $peopleCount people, $loansCount loans, and $paymentsCount payments. Restoring replaces all current data.',
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
      if (restoreConfirmed != true || !context.mounted) return;
      await AppDatabase.restoreFromBytes(clear);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('ledger_created', true);
      if (context.mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Backup restored. Restart the app to reload your ledger.',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Restore failed: $e')));
      }
    }
  }

  Future<String?> _passphraseDialog(
    BuildContext context, {
    bool confirmation = false,
  }) async {
    final first = TextEditingController();
    final second = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(confirmation ? 'Encrypt backup' : 'Decrypt backup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: first,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Passphrase (8+ characters)',
              ),
            ),
            if (confirmation)
              TextField(
                controller: second,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm passphrase',
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (first.text.length < 8 ||
                  (confirmation && first.text != second.text)) {
                return;
              }
              Navigator.pop(ctx, first.text);
            },
            child: Text(confirmation ? 'Encrypt' : 'Decrypt'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final lastBackup = ref.watch(_lastBackupProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(LdtSpacing.md),
        children: [
          // â”€â”€ Appearance â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Text(
            'Appearance',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: LdtSpacing.sm),
          Card(
            child: RadioGroup<ThemeMode>(
              groupValue: themeMode,
              onChanged: (v) {
                if (v != null) ref.read(themeProvider.notifier).setMode(v);
              },
              child: Column(
                children: [
                  RadioListTile<ThemeMode>(
                    title: const Text('System default'),
                    value: ThemeMode.system,
                    activeColor: LdtColors.primary,
                  ),
                  const Divider(height: 1),
                  RadioListTile<ThemeMode>(
                    title: const Text('Light'),
                    value: ThemeMode.light,
                    activeColor: LdtColors.primary,
                  ),
                  const Divider(height: 1),
                  RadioListTile<ThemeMode>(
                    title: const Text('Dark'),
                    value: ThemeMode.dark,
                    activeColor: LdtColors.primary,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: LdtSpacing.lg),

          // â”€â”€ Security â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Text(
            'Security',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: LdtSpacing.sm),
          Card(
            child: ListTile(
              title: const Text('App lock'),
              subtitle: const Text('Require biometric or device PIN to open'),
              trailing: Switch(
                value: ref.watch(appLockProvider),
                onChanged: (val) =>
                    ref.read(appLockProvider.notifier).setEnabled(val),
              ),
            ),
          ),
          const SizedBox(height: LdtSpacing.lg),

          // â”€â”€ Data â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Text(
            'Data',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: LdtSpacing.sm),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.backup_outlined),
                  title: const Text('Create encrypted backup'),
                  subtitle: Text(
                    lastBackup.when(
                      data: (date) => date == null
                          ? 'No backup created yet'
                          : 'Last backup: ${MaterialLocalizations.of(context).formatMediumDate(date)}',
                      loading: () => 'Loading backup history…',
                      error: (error, stackTrace) =>
                          'Backup history unavailable',
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _exportBackup(context, ref),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.restore_outlined),
                  title: const Text('Restore from backup'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _importBackup(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.table_chart_outlined),
                  title: const Text('Export to CSV'),
                  subtitle: const Text('Unencrypted â€” keep safe'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    try {
                      await _pruneSharedFiles();
                    } catch (_) {
                      // Continue; cleanup is best-effort.
                    }
                    File? exportFile;
                    try {
                      final csvData =
                          await CsvExportService.generateLoansAndPaymentsCsv(
                            AppDatabase.instance.db,
                          );
                      final tempDir = await getTemporaryDirectory();
                      final file = File(
                        '${tempDir.path}/lendentracker_export_${DateTime.now().millisecondsSinceEpoch}.csv',
                      );
                      exportFile = file;
                      await file.writeAsString(csvData, flush: true);
                      await Share.shareXFiles([
                        XFile(file.path),
                      ], subject: 'LenDen Tracker CSV Export');
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Export failed: $e')),
                        );
                      }
                    } finally {
                      if (exportFile != null && await exportFile.exists()) {
                        final result = await exportFile.stat();
                        if (DateTime.now().difference(result.modified) >
                            const Duration(days: 7)) {
                          await exportFile.delete();
                        }
                      }
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: LdtSpacing.lg),
          Text(
            'Contact access',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: LdtSpacing.sm),
          Card(
            child: ListTile(
              leading: const Icon(Icons.contacts_outlined),
              title: const Text('Contact permissions'),
              subtitle: const Text(
                'Access is requested only when selecting a borrower or lender. If denied, enable Contacts in your device app settings.',
              ),
              isThreeLine: true,
              onTap: () async {
                final opened = await openAppSettings();
                if (!opened && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Open this app’s settings to change Contacts access.',
                      ),
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
