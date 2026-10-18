import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/utils/money_utils.dart';
import '../../../data/repositories/repositories.dart';
import '../../../domain/entities/entities.dart';
import '../record_payment/record_payment_screen.dart';
import 'schedule_and_audit.dart';

import 'package:intl/intl.dart';

import '../home/home_screen.dart';
import '../loans/loans_screen.dart';

final loanDetailProvider =
    FutureProvider.family<({Loan loan, Person? person}), int>((ref, id) async {
      final loan = await ref.watch(loanRepoProvider).getById(id);
      if (loan == null) throw StateError('Loan not found');
      final person = await ref.watch(personRepoProvider).getById(loan.personId);
      return (loan: loan, person: person);
    });

final paymentHistoryProvider = FutureProvider.family<List<Payment>, int>((
  ref,
  id,
) async {
  return ref.watch(paymentRepoProvider).forLoan(id);
});

final interestDueProvider = FutureProvider.family<int, int>((ref, id) {
  return ref
      .watch(paymentRepoProvider)
      .interestDue(id, DateTime.now().toIso8601String().substring(0, 10));
});

class LoanDetailScreen extends ConsumerWidget {
  const LoanDetailScreen({super.key, required this.loanId});
  final int loanId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(loanDetailProvider(loanId));
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Loan detail'),
          actions: [
            IconButton(
              tooltip: 'Reminder',
              icon: const Icon(Icons.message_outlined),
              onPressed: () => context.push('/loans/$loanId/reminder'),
            ),
          ],
        ),
        body: detail.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, stack) => Center(
            child: TextButton(
              onPressed: () => ref.invalidate(loanDetailProvider(loanId)),
              child: const Text('Could not load loan. Retry'),
            ),
          ),
          data: (data) {
            final loan = data.loan;
            return Column(
              children: [
                const TabBar(
                  tabs: [
                    Tab(text: 'Overview'),
                    Tab(text: 'Schedule'),
                    Tab(text: 'History'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      ListView(
                        key: const PageStorageKey('loan-overview'),
                        padding: const EdgeInsets.all(LdtSpacing.md),
                        children: [
                          Text(
                            data.person?.displayName ?? 'Contact unavailable',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: LdtSpacing.md),
                          Text(
                            loan.direction == LoanDirection.lent
                                ? 'You lent'
                                : 'You borrowed',
                          ),
                          Text(
                            MoneyUtils.format(
                              loan.principalMinor,
                              loan.currency,
                            ),
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: LdtSpacing.lg),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(LdtSpacing.md),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Original agreement'),
                                  const SizedBox(height: LdtSpacing.sm),
                                  Text('Started: ${loan.startDate}'),
                                  Text('Interest: ${loan.interestMethod.name}'),
                                  if (loan.interestRate != null)
                                    Text(
                                      'Rate: ${loan.interestRate! * 100}% ${loan.ratePeriod?.name ?? ''}',
                                    ),
                                  if (loan.fixedInterestMinor != null)
                                    Text(
                                      'Fixed interest: ${MoneyUtils.format(loan.fixedInterestMinor!, loan.currency)}',
                                    ),
                                  Text(
                                    'Repayment: ${loan.paymentSchedule.name}',
                                  ),
                                  if (loan.maturityDate != null)
                                    Text(
                                      'Maturity/target: ${loan.maturityDate}',
                                    ),
                                  if (loan.notes?.isNotEmpty == true)
                                    Text('Notes: ${loan.notes}'),
                                  if (loan.continueAfterMaturity)
                                    const Text(
                                      'Interest continues after maturity by agreement.',
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: LdtSpacing.md),
                          if (loan.direction == LoanDirection.lent &&
                              data.person != null)
                            OutlinedButton.icon(
                              onPressed: () =>
                                  context.push('/loans/$loanId/reminder'),
                              icon: const Icon(Icons.chat_bubble_outline),
                              label: const Text('Prepare reminder'),
                            ),
                          if (loan.interestMethod == InterestMethod.none)
                            Consumer(
                              builder: (context, ref, _) {
                                final payment = ref.watch(
                                  paymentContextProvider(loanId),
                                );
                                return payment.when(
                                  loading: () =>
                                      const CircularProgressIndicator(),
                                  error: (_, _) => TextButton(
                                    onPressed: () => ref.invalidate(
                                      paymentContextProvider(loanId),
                                    ),
                                    child: const Text(
                                      'Could not load balance. Retry',
                                    ),
                                  ),
                                  data: (value) => Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Outstanding principal: ${MoneyUtils.format(value.outstandingMinor, loan.currency)}',
                                      ),
                                      if (loan.status == LoanStatus.active &&
                                          value.outstandingMinor > 0)
                                        FilledButton(
                                          onPressed: () => context.push(
                                            '/loans/$loanId/payment',
                                          ),
                                          child: const Text('Record payment'),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            )
                          else
                            Consumer(
                              builder: (context, ref, _) {
                                final payment = ref.watch(
                                  paymentContextProvider(loanId),
                                );
                                return payment.when(
                                  loading: () =>
                                      const CircularProgressIndicator(),
                                  error: (_, _) =>
                                      const Text('Could not load balance.'),
                                  data: (value) {
                                    final interest = ref.watch(
                                      interestDueProvider(loanId),
                                    );
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Outstanding principal: ${MoneyUtils.format(value.outstandingMinor, loan.currency)}',
                                        ),
                                        interest.when(
                                          loading: () =>
                                              const CircularProgressIndicator(),
                                          error: (_, _) => const Text(
                                            'Could not load interest due.',
                                          ),
                                          data: (due) => Text(
                                            'Interest due: ${MoneyUtils.format(due, loan.currency)}',
                                          ),
                                        ),
                                        if (loan.status == LoanStatus.active &&
                                            value.outstandingMinor > 0)
                                          FilledButton(
                                            onPressed: () => context.push(
                                              '/loans/$loanId/payment',
                                            ),
                                            child: const Text('Record payment'),
                                          ),
                                        if (loan.status == LoanStatus.active)
                                          TextButton(
                                            onPressed: () =>
                                                _showWaiver(context, ref, loan),
                                            child: const Text('Waive interest'),
                                          ),
                                      ],
                                    );
                                  },
                                );
                              },
                            ),
                          const SizedBox(height: LdtSpacing.md),
                        ],
                      ),
                      if (ref.exists(loanRepoProvider))
                        SingleChildScrollView(
                          key: const PageStorageKey('loan-schedule'),
                          padding: const EdgeInsets.all(LdtSpacing.md),
                          child: ScheduleAndAudit(loan: loan),
                        )
                      else
                        const Center(child: Text('Schedule unavailable.')),
                      SingleChildScrollView(
                        key: const PageStorageKey('loan-history'),
                        padding: const EdgeInsets.all(LdtSpacing.md),
                        child: _PaymentHistory(
                          loanId: loanId,
                          currency: loan.currency,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _showWaiver(
    BuildContext context,
    WidgetRef ref,
    Loan loan,
  ) async {
    var amount = '';
    var note = '';
    final formKey = GlobalKey<FormState>();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    WaiverPreview? preview;
    String? previewError;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> updatePreview(String text) async {
            final parsed = MoneyUtils.parseToMinor(text, loan.currency);
            if (parsed == null || parsed <= 0) {
              if (!dialogContext.mounted) return;
              setDialogState(() {
                preview = null;
                previewError = null;
              });
              return;
            }
            try {
              final p = await ref
                  .read(paymentRepoProvider)
                  .previewWaiver(loan.id!, today, parsed);
                  if (!dialogContext.mounted || text != amount) return;
              setDialogState(() {
                preview = p;
                previewError = null;
              });
            } catch (e) {
              if (!dialogContext.mounted || text != amount) return;
              setDialogState(() {
                preview = null;
                previewError = e
                    .toString()
                    .replaceAll('Exception: ', '')
                    .replaceAll('StateError: ', '');
              });
            }
          }

          return AlertDialog(
            title: const Text('Waive interest'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Date: $today',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: LdtSpacing.sm),
                    TextFormField(
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Waiver amount (${loan.currency})',
                      ),
                      onChanged: (value) {
                        amount = value;
                        updatePreview(value);
                      },
                      validator: (value) {
                        final parsed = MoneyUtils.parseToMinor(
                          value ?? '',
                          loan.currency,
                        );
                        if (parsed == null || parsed <= 0) {
                          return 'Enter a valid amount';
                        }
                        if (previewError != null) {
                          return previewError;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: LdtSpacing.sm),
                    TextField(
                      onChanged: (value) => note = value,
                      decoration: const InputDecoration(
                        labelText: 'Note (optional)',
                      ),
                    ),
                    if (preview != null) ...[
                      const SizedBox(height: LdtSpacing.md),
                      Container(
                        padding: const EdgeInsets.all(LdtSpacing.sm),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(LdtRadius.sm),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Accrued interest: ${MoneyUtils.format(preview!.accruedInterestMinor, loan.currency)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Text(
                              'Waived before: ${MoneyUtils.format(preview!.waivedBeforeMinor, loan.currency)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Text(
                              'Waived after: ${MoneyUtils.format(preview!.waivedAfterMinor, loan.currency)}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              'Remaining interest: ${MoneyUtils.format(preview!.remainingInterestMinor, loan.currency)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  try {
                    await ref
                        .read(paymentRepoProvider)
                        .waiveInterest(
                          InterestWaiver(
                            loanId: loan.id!,
                            waiverDate: today,
                            amountMinor: MoneyUtils.parseToMinor(
                              amount,
                              loan.currency,
                            )!,
                            note: note.trim().isEmpty
                                ? null
                                : note.trim(),
                          ),
                        );
                    ref.invalidate(loanDetailProvider(loan.id!));
                    ref.invalidate(paymentContextProvider(loan.id!));
                    ref.invalidate(principalBalancesProvider);
                    ref.invalidate(loansProvider);
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  } catch (e) {
                    if (dialogContext.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Could not waive interest: $e')),
                      );
                    }
                  }
                },
                child: const Text('Confirm waiver'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PaymentHistory extends ConsumerWidget {
  const _PaymentHistory({required this.loanId, required this.currency});
  final int loanId;
  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(paymentHistoryProvider(loanId));
    return history.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: LdtSpacing.md),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => TextButton(
        onPressed: () => ref.invalidate(paymentHistoryProvider(loanId)),
        child: const Text('Could not load payments. Retry'),
      ),
      data: (payments) {
        if (payments.isEmpty) {
          return const Text('No payments recorded');
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final p in payments)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.receipt_long_outlined),
                title: Text(p.effectiveDate),
                subtitle: Text(
                  '${p.reversed ? 'Reversed · ' : ''}'
                  'principal ${MoneyUtils.format(p.principalMinor, currency)}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(MoneyUtils.format(p.totalMinor, currency)),
                    if (!p.reversed && p.id != null) ...[
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        tooltip: 'Edit payment',
                        onPressed: () => _editPayment(context, ref, p),
                      ),
                      IconButton(
                        icon: const Icon(Icons.undo_outlined, size: 20),
                        tooltip: 'Reverse payment',
                        onPressed: () => _reversePayment(context, ref, p),
                      ),
                    ],
                  ],
                ),
                onLongPress: p.reversed || p.id == null
                    ? null
                    : () => _reversePayment(context, ref, p),
              ),
          ],
        );
      },
    );
  }

  Future<void> _reversePayment(
    BuildContext context,
    WidgetRef ref,
    Payment p,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reverse payment?'),
        content: Text(
          'Reverse ${MoneyUtils.format(p.totalMinor, currency)} dated ${p.effectiveDate}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reverse'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(paymentRepoProvider).reverse(p.id!);
      ref.invalidate(paymentHistoryProvider(loanId));
      ref.invalidate(paymentContextProvider(loanId));
      ref.invalidate(interestDueProvider(loanId));
      ref.invalidate(loanDetailProvider(loanId));
      ref.invalidate(principalBalancesProvider);
      ref.invalidate(loansProvider);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not reverse payment.')),
        );
      }
    }
  }

  Future<void> _editPayment(
    BuildContext context,
    WidgetRef ref,
    Payment payment,
  ) async {
    final amountController = TextEditingController(
      text: (payment.totalMinor / 100).toStringAsFixed(2),
    );
    final noteController = TextEditingController(text: payment.note ?? '');
    DateTime selectedDate = DateTime.parse(payment.effectiveDate);
    final formKey = GlobalKey<FormState>();
    PaymentAllocationPreview? preview;
    String? previewError;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> updatePreview(String text) async {
            final parsed = MoneyUtils.parseToMinor(text, currency);
            if (parsed == null || parsed <= 0) {
              setDialogState(() {
                preview = null;
                previewError = null;
              });
              return;
            }
            try {
              final formattedDate = DateFormat('yyyy-MM-dd')
                  .format(selectedDate);
              final p = await ref
                  .read(paymentRepoProvider)
                  .previewAllocation(
                    loanId,
                    formattedDate,
                    parsed,
                    excludingPaymentId: payment.id,
                  );
              setDialogState(() {
                preview = p;
                previewError = null;
              });
            } catch (e) {
              setDialogState(() {
                preview = null;
                previewError = e
                    .toString()
                    .replaceAll('Exception: ', '')
                    .replaceAll('StateError: ', '');
              });
            }
          }

          final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);

          return AlertDialog(
            title: const Text('Edit payment'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Original: ${payment.effectiveDate} · ${MoneyUtils.format(payment.totalMinor, currency)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: LdtSpacing.sm),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Effective date'),
                      subtitle: Text(dateStr),
                      trailing: const Icon(Icons.calendar_today_outlined),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setDialogState(() => selectedDate = picked);
                          updatePreview(amountController.text);
                        }
                      },
                    ),
                    const SizedBox(height: LdtSpacing.sm),
                    TextFormField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Payment amount ($currency)',
                      ),
                      onChanged: updatePreview,
                      validator: (value) {
                        final parsed = MoneyUtils.parseToMinor(
                          value ?? '',
                          currency,
                        );
                        if (parsed == null || parsed <= 0) {
                          return 'Enter a positive amount';
                        }
                        if (previewError != null) {
                          return previewError;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: LdtSpacing.sm),
                    TextField(
                      controller: noteController,
                      decoration: const InputDecoration(
                        labelText: 'Note (optional)',
                      ),
                    ),
                    if (preview != null) ...[
                      const SizedBox(height: LdtSpacing.md),
                      Container(
                        padding: const EdgeInsets.all(LdtSpacing.sm),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(LdtRadius.sm),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Allocation preview:',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Principal: ${MoneyUtils.format(preview!.principalMinor, currency)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Text(
                              'Interest: ${MoneyUtils.format(preview!.interestMinor, currency)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Text(
                              'Remaining principal: ${MoneyUtils.format(preview!.outstandingPrincipalMinor - preview!.principalMinor, currency)}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate() || preview == null) {
                    return;
                  }
                  try {
                    final newTotal = MoneyUtils.parseToMinor(
                      amountController.text,
                      currency,
                    )!;
                    await ref
                        .read(paymentRepoProvider)
                        .updatePayment(
                          Payment(
                            id: payment.id,
                            loanId: payment.loanId,
                            effectiveDate: dateStr,
                            totalMinor: newTotal,
                            principalMinor: preview!.principalMinor,
                            interestMinor: preview!.interestMinor,
                            note: noteController.text.trim().isEmpty
                                ? null
                                : noteController.text.trim(),
                            createdAt: payment.createdAt,
                          ),
                        );
                    ref.invalidate(paymentHistoryProvider(loanId));
                    ref.invalidate(paymentContextProvider(loanId));
                    ref.invalidate(interestDueProvider(loanId));
                    ref.invalidate(loanDetailProvider(loanId));
                    ref.invalidate(principalBalancesProvider);
                    ref.invalidate(loansProvider);
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  } catch (e) {
                    if (dialogContext.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Could not update payment: $e')),
                      );
                    }
                  }
                },
                child: const Text('Save correction'),
              ),
            ],
          );
        },
      ),
    );
    amountController.dispose();
    noteController.dispose();
  }
}
