import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/utils/money_utils.dart';
import '../../../data/repositories/repositories.dart';
import '../../../domain/entities/entities.dart';

class ScheduleAndAudit extends ConsumerWidget {
  const ScheduleAndAudit({super.key, required this.loan});
  final Loan loan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dues = ref.watch(_duesProvider(loan.id!));
    final amendments = ref.watch(_amendmentsProvider(loan.id!));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        dues.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => const Text('Could not load schedule.'),
          data: (items) => items.isEmpty
              ? const Text('No scheduled portions')
              : Column(
                  children: [
                    for (final due in items)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${due.dueDate} · ${due.status.name}'),
                        subtitle: Text(
                          'Principal ${MoneyUtils.format(due.principalMinor, loan.currency)} · interest ${MoneyUtils.format(due.interestMinor, loan.currency)}',
                        ),
                        trailing: Text(
                          MoneyUtils.format(due.totalMinor, loan.currency),
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: LdtSpacing.sm),
        amendments.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => const Text('Could not load agreement history.'),
          data: (items) => items.isEmpty
              ? const Text('No agreement amendments')
              : Column(
                  children: [
                    for (final item in items)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${item.amendedAt} · ${item.fieldName}'),
                        subtitle: Text(
                          '${item.oldValue ?? '—'} → ${item.newValue ?? '—'}${item.note == null ? '' : '\n${item.note}'}',
                        ),
                      ),
                  ],
                ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _amend(context, ref),
            icon: const Icon(Icons.edit_note),
            label: const Text('Amend agreement'),
          ),
        ),
      ],
    );
  }

  Future<void> _amend(BuildContext context, WidgetRef ref) async {
    final dateText = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final effectiveDate = TextEditingController(text: dateText);
    final maturity = TextEditingController(text: loan.maturityDate ?? '');
    final note = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Amend agreement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: effectiveDate,
              decoration: const InputDecoration(
                labelText: 'Effective date (YYYY-MM-DD)',
              ),
            ),
            TextFormField(
              controller: maturity,
              decoration: const InputDecoration(
                labelText: 'Maturity date (YYYY-MM-DD; blank to clear)',
              ),
            ),
            TextField(
              controller: note,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Reason / note (optional)',
              ),
            ),
            const SizedBox(height: LdtSpacing.sm),
            Text(
              'Current maturity: ${loan.maturityDate ?? 'not set'}\nNew maturity: ${maturity.text.isEmpty ? 'not set' : maturity.text}',
            ),
            const Text(
              'Only maturity date amendments are supported currently.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Review and apply'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      effectiveDate.dispose();
      maturity.dispose();
      note.dispose();
      return;
    }
    if (!context.mounted) {
      effectiveDate.dispose();
      maturity.dispose();
      note.dispose();
      return;
    }
    final effectiveText = effectiveDate.text.trim();
    final parsedEffective = DateTime.tryParse(effectiveText);
    if (parsedEffective == null ||
        DateFormat('yyyy-MM-dd').format(parsedEffective) != effectiveText) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid effective date in YYYY-MM-DD format.'),
        ),
      );
      effectiveDate.dispose();
      maturity.dispose();
      note.dispose();
      return;
    }
    final amendmentDate = effectiveText;
    final rawDate = maturity.text.trim();
    String? newMaturity;
    if (rawDate.isNotEmpty) {
      final parsed = DateTime.tryParse(rawDate);
      if (parsed == null ||
          DateFormat('yyyy-MM-dd').format(parsed) != rawDate) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enter a valid date in YYYY-MM-DD format.'),
          ),
        );
        effectiveDate.dispose();
        maturity.dispose();
        note.dispose();
        return;
      }
      newMaturity = rawDate;
    }
    if (newMaturity != null && newMaturity.compareTo(loan.startDate) < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maturity date cannot be before the loan start date.'),
        ),
      );
      effectiveDate.dispose();
      maturity.dispose();
      note.dispose();
      return;
    }
    final patched = loan.copyWith(maturityDate: newMaturity);
    final noteText = note.text.trim();
    final preview = await ref
        .read(loanRepoProvider)
        .previewAmendment(loan.id!, patched, amendmentDate, note: noteText);
    effectiveDate.dispose();
    maturity.dispose();
    note.dispose();
    if (!context.mounted) return;
    final apply = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Review amendment'),
        content: preview.isEmpty
            ? const Text('No agreement fields change.')
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final change in preview)
                    Text(
                      '${change.fieldName}: ${change.oldValue ?? '—'} → ${change.newValue ?? '—'}',
                    ),
                ],
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: preview.isEmpty
                ? null
                : () => Navigator.pop(dialogContext, true),
            child: const Text('Apply amendment'),
          ),
        ],
      ),
    );
    if (apply != true) return;
    try {
      await ref
          .read(loanRepoProvider)
          .applyAmendment(loan.id!, patched, amendmentDate, note: noteText);
      ref.invalidate(_amendmentsProvider(loan.id!));
      ref.invalidate(_duesProvider(loan.id!));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not apply amendment.')),
        );
      }
    }
  }
}

final _duesProvider = FutureProvider.family<List<ScheduledDue>, int>(
  (ref, id) => ref.read(loanRepoProvider).duesForLoan(id),
);
final _amendmentsProvider = FutureProvider.family<List<LoanAmendment>, int>(
  (ref, id) => ref.read(loanRepoProvider).amendmentsForLoan(id),
);
