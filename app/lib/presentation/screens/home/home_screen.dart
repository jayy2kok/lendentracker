import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/utils/money_utils.dart';
import '../../../data/repositories/repositories.dart';
import '../../../domain/entities/entities.dart';

final homeSummariesProvider = FutureProvider<List<LoanListItem>>((ref) {
  final now = DateTime.now();
  final today = DateTime(
    now.year,
    now.month,
    now.day,
  ).toIso8601String().substring(0, 10);
  return ref.watch(loanRepoProvider).summaries(today);
});

final principalBalancesProvider = FutureProvider<List<PrincipalBalance>>(
  (ref) => ref.watch(loanRepoProvider).principalBalances(),
);

/// Home screen — currency-separated principal, due and overdue summaries.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: LdtColors.primary,
                borderRadius: BorderRadius.circular(LdtRadius.sm),
              ),
              alignment: Alignment.center,
              child: const Text(
                'LDT',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: LdtSpacing.sm),
            const Text('LenDen Tracker'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.backup_outlined),
            tooltip: 'Backup',
            onPressed: () => context.go(AppRoutes.settings),
          ),
        ],
      ),
      body: const _HomeBody(),
    );
  }
}

class _HomeBody extends ConsumerWidget {
  const _HomeBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balances = ref.watch(principalBalancesProvider);
    final loans = ref.watch(homeSummariesProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(principalBalancesProvider);
        ref.invalidate(homeSummariesProvider);
        await Future.wait([
          ref.read(principalBalancesProvider.future),
          ref.read(homeSummariesProvider.future),
        ]);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(LdtSpacing.md),
        children: [
          balances.when(
            data: (rows) => rows.isEmpty
                ? const _EmptySection(
                    'No loans yet. Add a loan to see your balances.',
                  )
                : _BalanceSummaryCard(rows: rows),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) =>
                _EmptySection('Could not load balances. Pull down to retry.'),
          ),
          const SizedBox(height: LdtSpacing.md),
          const _SectionHeader('Payments'),
          loans.when(
            data: (loanItems) {
              if (loanItems.isEmpty) {
                return const _EmptySection('No payment reminders yet.');
              }
              final dueLoans = loanItems
                  .where(
                    (item) => item.overdueCount > 0 || item.nextDueDate != null,
                  )
                  .toList();
              if (dueLoans.isEmpty) {
                return const _EmptySection('No payments due or overdue today.');
              }
              return Card(
                child: Column(
                  children: dueLoans.map((item) {
                    final overdue = item.overdueCount > 0;
                    return ListTile(
                      title: Text(item.personName),
                      subtitle: Text(
                        overdue
                            ? '${item.overdueCount} overdue payment${item.overdueCount == 1 ? '' : 's'}'
                            : 'Due ${item.nextDueDate}',
                      ),
                      trailing: Text(
                        MoneyUtils.format(
                          item.nextDueMinor,
                          item.loan.currency,
                        ),
                      ),
                      onTap: () => context.push('/loans/${item.loan.id}'),
                    );
                  }).toList(),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => const _EmptySection(
              'Could not load payment reminders. Pull down to retry.',
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceSummaryCard extends StatelessWidget {
  const _BalanceSummaryCard({required this.rows});

  final List<PrincipalBalance> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(LdtSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Outstanding principal', style: theme.textTheme.titleMedium),
            const SizedBox(height: LdtSpacing.md),
            for (final row in rows) ...[
              _BalanceRow(
                label:
                    '${row.direction == LoanDirection.lent ? 'Owed to me' : 'I owe'} · ${row.currency}',
                amount: MoneyUtils.format(row.amountMinor, row.currency),
                color: row.direction == LoanDirection.lent
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
              ),
              const SizedBox(height: LdtSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }
}

class _BalanceRow extends StatelessWidget {
  const _BalanceRow({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final String amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.bodyMedium),
        Text(amount, style: LdtTextStyles.amountMedium.copyWith(color: color)),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: LdtSpacing.sm),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
  );
}

class _EmptySection extends StatelessWidget {
  const _EmptySection(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(LdtSpacing.md),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    ),
  );
}
