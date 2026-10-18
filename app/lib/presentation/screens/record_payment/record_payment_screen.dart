import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/money_utils.dart';
import '../../../data/repositories/repositories.dart';
import '../../../domain/entities/entities.dart';
import '../../../domain/services/interest_calculator.dart';
import '../home/home_screen.dart';
import '../loan_detail/loan_detail_screen.dart';
import '../loans/loans_screen.dart';

final paymentContextProvider =
    FutureProvider.family<({Loan loan, int outstandingMinor}), int>((
      ref,
      id,
    ) async {
      final loan = await ref.watch(loanRepoProvider).getById(id);
      if (loan == null) throw StateError('Loan not found');
      final outstanding = await ref
          .watch(paymentRepoProvider)
          .outstandingPrincipal(id);
      return (loan: loan, outstandingMinor: outstanding);
    });

class RecordPaymentScreen extends ConsumerStatefulWidget {
  const RecordPaymentScreen({super.key, required this.loanId});
  final int loanId;

  @override
  ConsumerState<RecordPaymentScreen> createState() =>
      _RecordPaymentScreenState();
}

class _RecordPaymentScreenState extends ConsumerState<RecordPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  final _principalAllocation = TextEditingController();
  final _interestAllocation = TextEditingController();
  DateTime _date = DateTime.now();
  bool _manualAllocation = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _amount.addListener(_updatePreview);
  }

  void _updatePreview() => setState(() {});

  @override
  void dispose() {
    _amount.removeListener(_updatePreview);
    _amount.dispose();
    _reference.dispose();
    _principalAllocation.dispose();
    _interestAllocation.dispose();
    super.dispose();
  }

  Future<void> _save(Loan loan, int outstanding) async {
    if (_saving || !_formKey.currentState!.validate()) return;
    final parsedTotal = MoneyUtils.parseToMinor(_amount.text, loan.currency)!;
    final parsedPrincipal =
        MoneyUtils.parseToMinor(_principalAllocation.text, loan.currency) ?? 0;
    final parsedInterest =
        MoneyUtils.parseToMinor(_interestAllocation.text, loan.currency) ?? 0;
    if (_manualAllocation &&
        (parsedPrincipal + parsedInterest != parsedTotal ||
            parsedPrincipal > outstanding)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Allocation must equal the payment and principal cannot exceed the outstanding balance.',
          ),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final amount = MoneyUtils.parseToMinor(_amount.text, loan.currency)!;
      final effectiveDate = DateFormat('yyyy-MM-dd').format(_date);
      if (loan.interestMethod == InterestMethod.none) {
        final payment = Payment(
          loanId: widget.loanId,
          effectiveDate: effectiveDate,
          totalMinor: amount,
          principalMinor: _manualAllocation
              ? (MoneyUtils.parseToMinor(
                      _principalAllocation.text,
                      loan.currency,
                    ) ??
                    0)
              : amount,
          interestMinor: 0,
          note: _reference.text.trim().isEmpty ? null : _reference.text.trim(),
          createdAt: DateTime.now(),
        );
        await ref.read(paymentRepoProvider).recordNoInterest(payment);
      } else {
        final preview = await ref
            .read(paymentRepoProvider)
            .previewAllocation(widget.loanId, effectiveDate, amount);
        await ref
            .read(paymentRepoProvider)
            .recordInterestBearing(
              Payment(
                loanId: widget.loanId,
                effectiveDate: effectiveDate,
                totalMinor: amount,
                principalMinor: _manualAllocation
                    ? (MoneyUtils.parseToMinor(
                            _principalAllocation.text,
                            loan.currency,
                          ) ??
                          0)
                    : preview.principalMinor,
                interestMinor: _manualAllocation
                    ? (MoneyUtils.parseToMinor(
                            _interestAllocation.text,
                            loan.currency,
                          ) ??
                          0)
                    : preview.interestMinor,
                note: _reference.text.trim().isEmpty
                    ? null
                    : _reference.text.trim(),
                createdAt: DateTime.now(),
              ),
            );
      }
      ref.invalidate(paymentContextProvider(widget.loanId));
      ref.invalidate(interestDueProvider(widget.loanId));
      ref.invalidate(paymentHistoryProvider(widget.loanId));
      ref.invalidate(loanDetailProvider(widget.loanId));
      ref.invalidate(principalBalancesProvider);
      ref.invalidate(loansProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not save payment. Check the balance and try again.',
            ),
          ),
        );
        ref.invalidate(paymentContextProvider(widget.loanId));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(paymentContextProvider(widget.loanId));
    return Scaffold(
      appBar: AppBar(title: const Text('Record payment')),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: TextButton(
            onPressed: () =>
                ref.invalidate(paymentContextProvider(widget.loanId)),
            child: const Text('Could not load loan. Retry'),
          ),
        ),
        data: (value) {
          final loan = value.loan;
          final outstanding = value.outstandingMinor;
          if (loan.status != LoanStatus.active || outstanding <= 0) {
            return const Center(
              child: Text('Payments for this loan are not available yet.'),
            );
          }
          final entered = MoneyUtils.parseToMinor(_amount.text, loan.currency);
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Outstanding principal: ${MoneyUtils.format(outstanding, loan.currency)}',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Payment amount (${loan.currency})',
                  ),
                  validator: (text) {
                    final amount = MoneyUtils.parseToMinor(
                      text ?? '',
                      loan.currency,
                    );
                    if (amount == null || amount <= 0) {
                      return 'Enter a positive amount';
                    }
                    final interest = const InterestCalculator().accruedInterest(
                      startDate: loan.startDate,
                      asOfDate: DateFormat('yyyy-MM-dd').format(_date),
                      principalMinor:
                          loan.interestMethod ==
                              InterestMethod.remainingPrincipal
                          ? outstanding
                          : loan.principalMinor,
                      method: loan.interestMethod,
                      rate: loan.interestRate,
                      ratePeriod: loan.ratePeriod,
                      fixedInterestMinor: loan.fixedInterestMinor,
                    );
                    final maximum = loan.interestMethod == InterestMethod.none
                        ? outstanding
                        : outstanding + interest;
                    if (amount > maximum) {
                      return 'Amount exceeds outstanding balance';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Payment date'),
                  subtitle: Text(DateFormat('yyyy-MM-dd').format(_date)),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime.parse(loan.startDate),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => _date = picked);
                  },
                ),
                TextField(
                  controller: _reference,
                  decoration: const InputDecoration(
                    labelText: 'Reference / note (optional)',
                  ),
                ),
                if (loan.interestMethod != InterestMethod.none) ...[
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enter allocation manually'),
                    value: _manualAllocation,
                    onChanged: (value) {
                      final amount = MoneyUtils.parseToMinor(
                        _amount.text,
                        loan.currency,
                      );
                      if (value && amount != null) {
                        final accrued = const InterestCalculator()
                            .accruedInterest(
                              startDate: loan.startDate,
                              asOfDate: DateFormat('yyyy-MM-dd').format(_date),
                              principalMinor:
                                  loan.interestMethod ==
                                      InterestMethod.remainingPrincipal
                                  ? outstanding
                                  : loan.principalMinor,
                              method: loan.interestMethod,
                              rate: loan.interestRate,
                              ratePeriod: loan.ratePeriod,
                              fixedInterestMinor: loan.fixedInterestMinor,
                            );
                        final allocation = const InterestCalculator().allocate(
                          paymentTotal: amount,
                          outstandingPrincipal: outstanding,
                          accruedInterest: accrued,
                        );
                        _interestAllocation.text = MoneyUtils.format(
                          allocation.interest,
                          loan.currency,
                        ).replaceAll(RegExp(r'[^0-9.]'), '');
                        _principalAllocation.text = MoneyUtils.format(
                          allocation.principal,
                          loan.currency,
                        ).replaceAll(RegExp(r'[^0-9.]'), '');
                      }
                      setState(() => _manualAllocation = value);
                    },
                  ),
                  if (_manualAllocation) ...[
                    TextFormField(
                      controller: _interestAllocation,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Interest portion',
                      ),
                      validator: (text) =>
                          MoneyUtils.parseToMinor(text ?? '', loan.currency) ==
                              null
                          ? 'Enter a valid amount'
                          : null,
                    ),
                    TextFormField(
                      controller: _principalAllocation,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Principal portion',
                      ),
                      validator: (text) =>
                          MoneyUtils.parseToMinor(text ?? '', loan.currency) ==
                              null
                          ? 'Enter a valid amount'
                          : null,
                    ),
                  ],
                ],
                if (entered != null &&
                    entered > 0 &&
                    (loan.interestMethod == InterestMethod.none ||
                        entered <=
                            const InterestCalculator().accruedInterest(
                              startDate: loan.startDate,
                              asOfDate: DateFormat('yyyy-MM-dd').format(_date),
                              principalMinor:
                                  loan.interestMethod ==
                                      InterestMethod.remainingPrincipal
                                  ? outstanding
                                  : loan.principalMinor,
                              method: loan.interestMethod,
                              rate: loan.interestRate,
                              ratePeriod: loan.ratePeriod,
                              fixedInterestMinor: loan.fixedInterestMinor,
                            )))
                  Builder(
                    builder: (context) {
                      final accrued = const InterestCalculator()
                          .accruedInterest(
                            startDate: loan.startDate,
                            asOfDate: DateFormat('yyyy-MM-dd').format(_date),
                            principalMinor:
                                loan.interestMethod ==
                                    InterestMethod.remainingPrincipal
                                ? outstanding
                                : loan.principalMinor,
                            method: loan.interestMethod,
                            rate: loan.interestRate,
                            ratePeriod: loan.ratePeriod,
                            fixedInterestMinor: loan.fixedInterestMinor,
                          );
                      final allocation = entered > outstanding + accrued
                          ? (principal: 0, interest: 0)
                          : const InterestCalculator().allocate(
                              paymentTotal: entered,
                              outstandingPrincipal: outstanding,
                              accruedInterest: accrued,
                            );
                      final principalShown = _manualAllocation
                          ? (MoneyUtils.parseToMinor(
                                  _principalAllocation.text,
                                  loan.currency,
                                ) ??
                                0)
                          : allocation.principal;
                      final interestShown = _manualAllocation
                          ? (MoneyUtils.parseToMinor(
                                  _interestAllocation.text,
                                  loan.currency,
                                ) ??
                                0)
                          : allocation.interest;
                      if (_manualAllocation &&
                          (principalShown + interestShown != entered ||
                              principalShown > outstanding)) {
                        return const Text(
                          'Allocation must equal payment amount; principal cannot exceed outstanding.',
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Allocation: ${MoneyUtils.format(interestShown, loan.currency)} interest · ${MoneyUtils.format(principalShown, loan.currency)} principal',
                          ),
                          Text(
                            'Remaining principal after payment: ${MoneyUtils.format(outstanding - principalShown, loan.currency)}',
                          ),
                        ],
                      );
                    },
                  ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : () => _save(loan, outstanding),
                  child: const Text('Save payment'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
