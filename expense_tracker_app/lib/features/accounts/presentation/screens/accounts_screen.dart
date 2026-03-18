import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/accounts_provider.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/models/account_model.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsProvider);
    final totalBalance = ref.watch(totalBalanceProvider);
    final totalCredit = ref.watch(totalCreditPayableProvider);
    final userCurrency =
        ref.watch(authStateProvider).valueOrNull?.defaultCurrency ?? 'PHP';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Recalculate balances',
            onPressed: () async {
              try {
                await ref
                    .read(accountsProvider.notifier)
                    .recalculateBalances();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Balances recalculated')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/add-account'),
          ),
        ],
      ),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(accountsProvider.notifier).loadAccounts(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (accounts) {
          final active = accounts.where((a) => !a.isArchived).toList();
          final cashAccounts = active.where((a) => a.type != 'credit_card').toList();
          final creditCards = active.where((a) => a.type == 'credit_card').toList();

          return RefreshIndicator(
            onRefresh: () => ref.read(accountsProvider.notifier).loadAccounts(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Summary cards
                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        title: 'Total Balance',
                        amount: totalBalance,
                        color: context.colorScheme.primary,
                        currency: userCurrency,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryCard(
                        title: 'Credit Payable',
                        amount: totalCredit,
                        color: context.colorScheme.error,
                        currency: userCurrency,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (cashAccounts.isNotEmpty) ...[
                  Text('Accounts', style: context.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ...cashAccounts.map((a) => _AccountTile(account: a)),
                  const SizedBox(height: 16),
                ],
                if (creditCards.isNotEmpty) ...[
                  Text('Credit Cards', style: context.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ...creditCards.map((a) => _AccountTile(account: a)),
                ],
                if (active.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(Icons.account_balance_wallet_outlined,
                              size: 64,
                              color: context.colorScheme.onSurfaceVariant),
                          const SizedBox(height: 16),
                          const Text('No accounts yet'),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () => context.push('/add-account'),
                            child: const Text('Add Account'),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final double amount;
  final Color color;
  final String currency;

  const _SummaryCard({
    required this.title,
    required this.amount,
    required this.color,
    this.currency = 'PHP',
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            FittedBox(
              child: Text(
                CurrencyFormatter.format(amount, currency: currency),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  final AccountModel account;

  const _AccountTile({required this.account});

  IconData get _icon {
    switch (account.type) {
      case 'cash':
        return Icons.money;
      case 'bank':
        return Icons.account_balance;
      case 'savings':
        return Icons.savings;
      case 'wallet':
        return Icons.account_balance_wallet;
      case 'credit_card':
        return Icons.credit_card;
      default:
        return Icons.account_balance_wallet;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(_icon, color: Theme.of(context).colorScheme.primary),
        ),
        title: Text(account.name),
        subtitle: Text(account.type.replaceAll('_', ' ').toUpperCase()),
        trailing: Text(
          CurrencyFormatter.format(
            account.isCreditCard ? account.balance.abs() : account.balance,
            currency: account.currency,
          ),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: account.isCreditCard && account.balance < 0
                    ? Theme.of(context).colorScheme.error
                    : null,
              ),
        ),
        onTap: () => context.push('/account/${account.id}'),
      ),
    );
  }
}
