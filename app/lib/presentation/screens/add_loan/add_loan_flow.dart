import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/utils/money_utils.dart';
import '../../../data/repositories/repositories.dart';
import '../../../domain/entities/entities.dart';
import '../../../domain/services/interest_calculator.dart';
import '../home/home_screen.dart';
import '../loans/loans_screen.dart';

class AddLoanFlow extends ConsumerStatefulWidget {
  const AddLoanFlow({super.key});

  @override
  ConsumerState<AddLoanFlow> createState() => _AddLoanFlowState();
}

class _AddLoanFlowState extends ConsumerState<AddLoanFlow> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _rate = TextEditingController();
  int _step = 0;
  Contact? _contact;
  String? _phone;
  String? _contactError;
  LoanDirection _direction = LoanDirection.lent;
  InterestMethod _method = InterestMethod.none;
  PaymentSchedule _schedule = PaymentSchedule.flexible;
  RatePeriod _period = RatePeriod.annual;
  String _currency = 'INR';
  DateTime _start = DateTime.now();
  DateTime? _maturity;
  DateTime? _firstDue;
  final List<DateTime> _customDueDates = [];
  final Map<String, TextEditingController> _duePortions = {};
  bool _continueAfterMaturity = false;
  final _notes = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _rate.dispose();
    _notes.dispose();
    for (final controller in _duePortions.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _chooseContact() async {
    try {
      if (!await FlutterContacts.requestPermission(readonly: true)) {
        if (mounted) {
          setState(
            () => _contactError = 'Contact access is required to choose a borrower or lender. Enable it in app settings and try again.',
          );
        }
        return;
      }
      if (!mounted) return;
      final contact = await FlutterContacts.openExternalPick();
      if (contact == null) return;
      final selected =
          await FlutterContacts.getContact(contact.id, withProperties: true) ??
          contact;
      if (!mounted) return;
      if (selected.phones.isEmpty) {
        setState(() => _contactError = 'This contact has no phone number.');
        return;
      }
      String? number;
      if (selected.phones.length == 1) {
        number = selected.phones.first.number;
      } else {
        number = await showModalBottomSheet<String>(
          context: context,
          builder: (context) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                const ListTile(title: Text('Choose a phone number')),
                for (final phone in selected.phones)
                  ListTile(
                    title: Text(phone.number),
                    onTap: () => Navigator.pop(context, phone.number),
                  ),
              ],
            ),
          ),
        );
      }
      if (number == null || !mounted) return;
      final normalized = number.replaceAll(RegExp(r'[\s()\-]'), '');
      setState(() {
        _contact = selected;
        _phone = normalized;
        _contactError = MoneyUtils.isValidE164(normalized) ? null : 'This number needs a country code (for example +919876543210). Edit it in Contacts first.';
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _contactError =
              'Could not open Contacts. Check contact access and try again.',
        );
      }
    }
  }

  Future<void> _pickDate({required bool maturity}) async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: maturity ? (_maturity ?? _start) : _start,
    );
    if (picked != null) {
      setState(() {
        if (maturity) {
          _maturity = picked;
        } else {
          _start = picked;
        }
      });
    }
  }

  bool _validStep() {
    if (_step == 0) {
      if (_contact == null ||
          _phone == null ||
          !MoneyUtils.isValidE164(_phone!)) {
        setState(
          () => _contactError ??=
              'Choose a contact with an international phone number.',
        );
        return false;
      }
      return _formKey.currentState!.validate();
    }
    if (_step == 1 && _method != InterestMethod.none) {
      final value = double.tryParse(_rate.text.trim());
      if (value == null ||
          value <= 0 ||
          (_method != InterestMethod.fixedTotal && value > 100)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Enter a positive interest amount or a rate up to 100%.',
            ),
          ),
        );
        return false;
      }
      if (_method == InterestMethod.fixedTotal &&
          (MoneyUtils.parseToMinor(_rate.text, _currency) ?? 0) <= 0) {
        return false;
      }
    }
    if (_step == 2 &&
        (_schedule == PaymentSchedule.atMaturity ||
            _schedule == PaymentSchedule.interestOnly) &&
        (_maturity == null || _maturity!.isBefore(_start))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose a maturity date on or after the start date.'),
        ),
      );
      return false;
    }
    if (_step == 2 && _firstDue != null && _firstDue!.isBefore(_start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('First due date must be on or after the start date.'),
        ),
      );
      return false;
    }
    if (_step == 2 &&
        (_schedule == PaymentSchedule.regular ||
            _schedule == PaymentSchedule.interestOnly) &&
        (_maturity == null || _maturity!.isBefore(_start))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose a maturity date for recurring payments.'),
        ),
      );
      return false;
    }
    if (_step == 2 && _maturity != null && _maturity!.isBefore(_start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Target date must be on or after the start date.'),
        ),
      );
      return false;
    }
    return true;
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final repo = ref.read(loanRepoProvider);
      final principal = MoneyUtils.parseToMinor(_amount.text, _currency)!;
      final dueList = _customDueDates.toList()..sort();
      final dates = _schedule == PaymentSchedule.atMaturity && _maturity != null
          ? <DateTime>[_maturity!]
          : (_schedule == PaymentSchedule.regular ||
                    _schedule == PaymentSchedule.interestOnly) &&
                _maturity != null
          ? (dueList.isNotEmpty
                ? dueList
                : const InterestCalculator().monthlyDueDates(
                    firstDueDate: _firstDue ?? _start,
                    maturityDate: _maturity!,
                  ))
          : <DateTime>[];
      if (_schedule == PaymentSchedule.regular &&
          dates.isNotEmpty &&
          dates.any(
            (date) =>
                _duePortions[DateFormat('yyyy-MM-dd').format(date)] == null ||
                (MoneyUtils.parseToMinor(
                          _duePortions[DateFormat('yyyy-MM-dd').format(date)]!
                              .text,
                          _currency,
                        ) ??
                        0) <=
                    0,
          )) {
        throw ArgumentError(
          'Enter a positive principal portion for each installment.',
        );
      }
      final interestParts =
          _method == InterestMethod.fixedTotal && dates.isNotEmpty
          ? const InterestCalculator().allocateFixedInterest(
              MoneyUtils.parseToMinor(_rate.text, _currency) ?? 0,
              dates.length,
            )
          : _schedule == PaymentSchedule.interestOnly &&
                (_method == InterestMethod.originalPrincipal ||
                    _method == InterestMethod.remainingPrincipal)
          ? const InterestCalculator().interestOnlyPortions(
              principalMinor: principal,
              startDate: DateFormat('yyyy-MM-dd').format(_start),
              dueDates: dates,
              method: _method,
              rate: double.parse(_rate.text.trim()) / 100,
              ratePeriod: _period,
            )
          : List<int>.filled(dates.length, 0);
      if (_schedule == PaymentSchedule.regular && dates.isNotEmpty) {
        final scheduledPrincipal = dates.fold<int>(0, (sum, date) {
          final controller =
              _duePortions[DateFormat('yyyy-MM-dd').format(date)];
          return sum +
              (controller == null
                  ? 0
                  : MoneyUtils.parseToMinor(controller.text, _currency) ?? 0);
        });
        if (scheduledPrincipal != principal) {
          throw ArgumentError(
            'Installment principal portions must equal the loan principal.',
          );
        }
      }
      final schedule = <ScheduledDue>[
        for (var i = 0; i < dates.length; i++)
          ScheduledDue(
            loanId: 0,
            dueDate: DateFormat('yyyy-MM-dd').format(dates[i]),
            principalMinor: _schedule == PaymentSchedule.interestOnly
                ? (i == dates.length - 1 ? principal : 0)
                : _schedule == PaymentSchedule.atMaturity
                ? principal
                : MoneyUtils.parseToMinor(
                        _duePortions[DateFormat('yyyy-MM-dd').format(dates[i])]
                                ?.text ??
                            '',
                        _currency,
                      ) ??
                      0,
            interestMinor:
                _schedule == PaymentSchedule.atMaturity &&
                    _method == InterestMethod.fixedTotal
                ? (MoneyUtils.parseToMinor(_rate.text, _currency) ?? 0)
                : interestParts[i],
          ),
      ];
      final loanId = await repo.createWithPerson(
        name: _contact!.displayName,
        phone: _phone!,
        contactId: _contact!.id,
        loan: Loan(
          personId: 0,
          direction: _direction,
          principalMinor: principal,
          currency: _currency,
          startDate: DateFormat('yyyy-MM-dd').format(_start),
          maturityDate: _maturity == null
              ? null
              : DateFormat('yyyy-MM-dd').format(_maturity!),
          interestMethod: _method,
          interestRate:
              _method == InterestMethod.none ||
                  _method == InterestMethod.fixedTotal
              ? null
              : double.parse(_rate.text.trim()) / 100,
          fixedInterestMinor: _method == InterestMethod.fixedTotal
              ? MoneyUtils.parseToMinor(_rate.text, _currency)
              : null,
          ratePeriod:
              _method == InterestMethod.none ||
                  _method == InterestMethod.fixedTotal
              ? null
              : _period,
          paymentSchedule: _schedule,
          installmentAmountMinor:
              _schedule == PaymentSchedule.regular ||
                  _schedule == PaymentSchedule.interestOnly
              ? MoneyUtils.parseToMinor(_amount.text, _currency)
              : null,
          firstDueDate:
              _schedule == PaymentSchedule.regular ||
                  _schedule == PaymentSchedule.interestOnly
              ? DateFormat('yyyy-MM-dd').format(_firstDue ?? _start)
              : null,
          monthlyAnchorDate:
              _schedule == PaymentSchedule.regular ||
                  _schedule == PaymentSchedule.interestOnly
              ? DateFormat('yyyy-MM-dd').format(_firstDue ?? _start)
              : null,
          continueAfterMaturity: _continueAfterMaturity,
          notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          createdAt: now,
          updatedAt: now,
        ),
        schedule: schedule,
      );
      ref.invalidate(principalBalancesProvider);
      ref.invalidate(loansProvider);
      if (mounted) {
        context.go('/loans/$loanId');
      }
    } catch (e, st) {
      debugPrint('SAVE LOAN ERROR: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save the loan: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Add loan')),
    body: Form(
      key: _formKey,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(LdtSpacing.md),
            child: Text(
              '${_step + 1} of 4 · ${['Basics', 'Interest', 'Repayment', 'Review'][_step]}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: LdtSpacing.md),
              child: switch (_step) {
                0 => _basics(),
                1 => _interest(),
                2 => _repayment(),
                _ => _review(),
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(LdtSpacing.md),
              child: Row(
                children: [
                  if (_step > 0)
                    TextButton(
                      onPressed: _saving ? null : () => setState(() => _step--),
                      child: const Text('Back'),
                    ),
                  const SizedBox(width: LdtSpacing.sm),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving
                          ? null
                          : () {
                              if (_step == 3) {
                                _save();
                              } else if (_validStep()) {
                                setState(() => _step++);
                              }
                            },
                      child: Text(
                        _saving
                            ? 'Saving…'
                            : _step == 3
                            ? 'Save loan'
                            : 'Continue',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _basics() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SegmentedButton<LoanDirection>(
        segments: const [
          ButtonSegment(value: LoanDirection.lent, label: Text('I lent money')),
          ButtonSegment(
            value: LoanDirection.borrowed,
            label: Text('I borrowed'),
          ),
        ],
        selected: {_direction},
        onSelectionChanged: (value) => setState(() => _direction = value.first),
      ),
      const SizedBox(height: LdtSpacing.md),
      OutlinedButton.icon(
        onPressed: _chooseContact,
        icon: const Icon(Icons.contacts_outlined),
        label: Text(
          _contact == null ? 'Choose contact' : _contact!.displayName,
        ),
      ),
      if (_phone != null) Text(_phone!),
      if (_contactError != null)
        Text(
          _contactError!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      const SizedBox(height: LdtSpacing.md),
      TextFormField(
        controller: _amount,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Principal amount'),
        validator: (value) =>
            (MoneyUtils.parseToMinor(value ?? '', _currency) ?? 0) > 0
            ? null
            : 'Enter a positive amount',
      ),
      const SizedBox(height: LdtSpacing.md),
      DropdownButtonFormField<String>(
        initialValue: _currency,
        decoration: const InputDecoration(labelText: 'Currency'),
        items: ['INR', 'USD', 'EUR', 'GBP']
            .map((code) => DropdownMenuItem(value: code, child: Text(code)))
            .toList(),
        onChanged: (value) => setState(() => _currency = value!),
      ),
      const SizedBox(height: LdtSpacing.md),
      ListTile(
        title: const Text('Start date'),
        subtitle: Text(DateFormat.yMMMd().format(_start)),
        trailing: const Icon(Icons.calendar_today_outlined),
        onTap: () => _pickDate(maturity: false),
      ),
    ],
  );

  Widget _interest() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DropdownButtonFormField<InterestMethod>(
        initialValue: _method,
        decoration: const InputDecoration(labelText: 'Interest method'),
        items: const [
          DropdownMenuItem(
            value: InterestMethod.none,
            child: Text('No interest'),
          ),
          DropdownMenuItem(
            value: InterestMethod.fixedTotal,
            child: Text('Fixed total interest'),
          ),
          DropdownMenuItem(
            value: InterestMethod.originalPrincipal,
            child: Text('On original principal'),
          ),
          DropdownMenuItem(
            value: InterestMethod.remainingPrincipal,
            child: Text('On remaining principal'),
          ),
        ],
        onChanged: (value) => setState(() => _method = value!),
      ),
      if (_method != InterestMethod.none) ...[
        const SizedBox(height: LdtSpacing.md),
        TextField(
          controller: _rate,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: _method == InterestMethod.fixedTotal
                ? 'Agreed total interest'
                : 'Rate (%)',
          ),
        ),
      ],
      if (_method == InterestMethod.originalPrincipal ||
          _method == InterestMethod.remainingPrincipal) ...[
        const SizedBox(height: LdtSpacing.md),
        DropdownButtonFormField<RatePeriod>(
          initialValue: _period,
          decoration: const InputDecoration(labelText: 'Rate period'),
          items: const [
            DropdownMenuItem(value: RatePeriod.annual, child: Text('Annual')),
            DropdownMenuItem(value: RatePeriod.monthly, child: Text('Monthly')),
          ],
          onChanged: (value) => setState(() => _period = value!),
        ),
      ],
    ],
  );

  Widget _repayment() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DropdownButtonFormField<PaymentSchedule>(
        initialValue: _schedule,
        decoration: const InputDecoration(labelText: 'Repayment plan'),
        items: const [
          DropdownMenuItem(
            value: PaymentSchedule.flexible,
            child: Text('Flexible · no installments'),
          ),
          DropdownMenuItem(
            value: PaymentSchedule.atMaturity,
            child: Text('One payment at maturity'),
          ),
          DropdownMenuItem(
            value: PaymentSchedule.regular,
            child: Text('Regular installments'),
          ),
          DropdownMenuItem(
            value: PaymentSchedule.interestOnly,
            child: Text('Interest-only, principal at maturity'),
          ),
        ],
        onChanged: (value) => setState(() => _schedule = value!),
      ),
      const SizedBox(height: LdtSpacing.md),
      ListTile(
        title: const Text('Maturity / target date'),
        subtitle: Text(
          _maturity == null ? 'Not set' : DateFormat.yMMMd().format(_maturity!),
        ),
        trailing: const Icon(Icons.calendar_today_outlined),
        onTap: () => _pickDate(maturity: true),
      ),
      if (_schedule == PaymentSchedule.regular ||
          _schedule == PaymentSchedule.interestOnly) ...[
        ListTile(
          title: const Text('First payment due'),
          subtitle: Text(
            _firstDue == null
                ? 'Choose date'
                : DateFormat.yMMMd().format(_firstDue!),
          ),
          trailing: const Icon(Icons.calendar_today_outlined),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              firstDate: _start,
              lastDate: DateTime(2100),
              initialDate: _firstDue ?? _start,
            );
            if (picked != null) {
              final key = DateFormat('yyyy-MM-dd').format(picked);
              setState(() {
                _firstDue = picked;
                if (!_customDueDates.contains(picked)) {
                  _customDueDates.add(picked);
                }
                _duePortions.putIfAbsent(
                  key,
                  () => TextEditingController(text: '0.00'),
                );
              });
            }
          },
        ),
        OutlinedButton.icon(
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              firstDate: _start,
              lastDate: _maturity ?? DateTime(2100),
              initialDate: _maturity ?? _start,
            );
            if (picked == null) return;
            final key = DateFormat('yyyy-MM-dd').format(picked);
            setState(() {
              if (!_customDueDates.contains(picked)) {
                _customDueDates.add(picked);
              }
              _duePortions.putIfAbsent(
                key,
                () => TextEditingController(text: '0.00'),
              );
            });
          },
          icon: const Icon(Icons.add),
          label: const Text('Add custom due date'),
        ),
        for (final date in (_customDueDates.toList()..sort()))
          TextFormField(
            controller: _duePortions[DateFormat('yyyy-MM-dd').format(date)],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: '${DateFormat.yMMMd().format(date)} principal portion',
            ),
            validator: (text) =>
                MoneyUtils.parseToMinor(text ?? '', _currency) == null
                ? 'Enter a valid portion'
                : null,
          ),
        Text(
          'Monthly due dates retain this day (or month-end when the anchor is month-end).',
        ),
      ],
      if (_schedule == PaymentSchedule.flexible && _maturity != null)
        TextButton(
          onPressed: () => setState(() => _maturity = null),
          child: const Text('Remove target date'),
        ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Continue interest after maturity'),
        value: _continueAfterMaturity,
        onChanged: (value) => setState(() => _continueAfterMaturity = value),
      ),
      TextFormField(
        controller: _notes,
        maxLines: 3,
        decoration: const InputDecoration(
          labelText: 'Agreement notes (optional)',
        ),
      ),
    ],
  );

  Widget _review() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        '${_direction == LoanDirection.lent ? 'You lent' : 'You borrowed'} ${MoneyUtils.format(MoneyUtils.parseToMinor(_amount.text, _currency)!, _currency)} ${_direction == LoanDirection.lent ? 'to' : 'from'} ${_contact!.displayName}.',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: LdtSpacing.md),
      Text('Phone: $_phone · Started ${DateFormat.yMMMd().format(_start)}'),
      const SizedBox(height: LdtSpacing.sm),
      Text(
        'Interest: ${_method == InterestMethod.none
            ? 'none'
            : _method == InterestMethod.fixedTotal
            ? 'fixed ${MoneyUtils.format(MoneyUtils.parseToMinor(_rate.text, _currency)!, _currency)}'
            : '${_rate.text}% ${_period.name} on ${_method == InterestMethod.originalPrincipal ? 'original' : 'remaining'} principal'}',
      ),
      const SizedBox(height: LdtSpacing.sm),
      Text(
        'Repayment: ${_schedule == PaymentSchedule.flexible ? 'flexible' : 'at maturity'}${_maturity == null ? '' : ', ${DateFormat.yMMMd().format(_maturity!)}'}',
      ),
      const SizedBox(height: LdtSpacing.lg),
      const Text('This records your agreement. No money is transferred.'),
    ],
  );
}
