import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/utils/money_utils.dart';
import '../../../data/repositories/repositories.dart';
import '../../../domain/entities/entities.dart';

final loansProvider = FutureProvider<List<LoanListItem>>((ref) {
  final now = DateTime.now();
  final today = DateTime(
    now.year,
    now.month,
    now.day,
  ).toIso8601String().substring(0, 10);
  return ref.watch(loanRepoProvider).summaries(today);
});

class LoansScreen extends ConsumerStatefulWidget {
  const LoansScreen({super.key});

  @override
  ConsumerState<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends ConsumerState<LoansScreen> {
  String _search = '';
  LoanDirection? _direction;
  LoanStatus? _status;
  String? _currency;

  @override
  Widget build(BuildContext context) {
    final loans = ref.watch(loansProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Loans')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(LdtSpacing.md),
            child: Column(
              children: [
                TextField(
                  textInputAction: TextInputAction.search,
                  onChanged: (value) =>
                      setState(() => _search = value.trim().toLowerCase()),
                  decoration: const InputDecoration(
                    labelText: 'Search by person',
                    hintText: 'Name or phone number',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: LdtSpacing.sm),
                Wrap(
                  spacing: LdtSpacing.sm,
                  runSpacing: LdtSpacing.sm,
                  children: [
                    DropdownButton<LoanStatus?>(
                      value: _status,
                      hint: const Text('Any status'),
                      items: const [
                        DropdownMenuItem(
                          value: null,
                          child: Text('Any status'),
                        ),
                        DropdownMenuItem(
                          value: LoanStatus.active,
                          child: Text('Active'),
                        ),
                        DropdownMenuItem(
                          value: LoanStatus.settled,
                          child: Text('Settled'),
                        ),
                        DropdownMenuItem(
                          value: LoanStatus.waived,
                          child: Text('Waived'),
                        ),
                      ],
                      onChanged: (value) => setState(() => _status = value),
                    ),
                    DropdownButton<String?>(
                      value: _currency,
                      hint: const Text('Any currency'),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Any currency'),
                        ),
                        ...loans
                            .maybeWhen(
                              data: (items) =>
                                  items
                                      .map((item) => item.loan.currency)
                                      .toSet()
                                      .toList()
                                    ..sort(),
                              orElse: () => <String>[],
                            )
                            .map(
                              (currency) => DropdownMenuItem(
                                value: currency,
                                child: Text(currency),
                              ),
                            ),
                      ],
                      onChanged: (value) => setState(() => _currency = value),
                    ),
                  ],
                ),
                const SizedBox(height: LdtSpacing.sm),
                SegmentedButton<LoanDirection?>(
                  segments: const [
                    ButtonSegment(value: null, label: Text('All')),
                    ButtonSegment(
                      value: LoanDirection.lent,
                      label: Text('Lent'),
                    ),
                    ButtonSegment(
                      value: LoanDirection.borrowed,
                      label: Text('Borrowed'),
                    ),
                  ],
                  selected: {_direction},
                  onSelectionChanged: (value) =>
                      setState(() => _direction = value.first),
                ),
              ],
            ),
          ),
          Expanded(
            child: loans.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, stack) => Center(
                child: TextButton.icon(
                  onPressed: () => ref.invalidate(loansProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Could not load loans. Retry'),
                ),
              ),
              data: (rows) {
                final filtered = rows
                    .where(
                      (item) =>
                          (_direction == null ||
                              item.loan.direction == _direction) &&
                          (_status == null || item.loan.status == _status) &&
                          (_currency == null ||
                              item.loan.currency == _currency) &&
                          (_search.isEmpty ||
                              item.personName.toLowerCase().contains(_search) ||
                              item.loan.currency.toLowerCase().contains(
                                _search,
                              )),
                    )
                    .toList();
                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          rows.isEmpty
                              ? 'No loans yet. Tap Add loan to get started.'
                              : 'No matching loans.',
                        ),
                        if (rows.isEmpty) ...[
                          const SizedBox(height: LdtSpacing.sm),
                          FilledButton.icon(
                            onPressed: () => context.push('/loans/add'),
                            icon: const Icon(Icons.add),
                            label: const Text('Add loan'),
                          ),
                        ],
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(loansProvider);
                    await ref.read(loansProvider.future);
                  },
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      final loan = item.loan;
                      return ListTile(
                        minVerticalPadding: 16,
                        title: Text(item.personName),
                        subtitle: Text(
                          '${loan.direction == LoanDirection.lent ? 'Lent' : 'Borrowed'} · ${loan.status.name} · ${item.overdueCount > 0
                              ? '${item.overdueCount} overdue'
                              : item.nextDueDate == null
                              ? 'No scheduled due'
                              : 'Next due ${item.nextDueDate}'}',
                        ),
                        trailing: Text(
                          MoneyUtils.format(loan.principalMinor, loan.currency),
                        ),
                        onTap: () => context.push('/loans/${loan.id}'),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/loans/add');
          ref.invalidate(loansProvider);
        },
        icon: const Icon(Icons.add),
        label: const Text('Add loan'),
      ),
    );
  }
}
