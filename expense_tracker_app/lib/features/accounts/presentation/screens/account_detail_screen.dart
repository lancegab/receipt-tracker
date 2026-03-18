import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/accounts_provider.dart';
import '../../../../features/transactions/presentation/providers/transactions_provider.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/models/transaction_model.dart';

class AccountDetailScreen extends ConsumerStatefulWidget {
  final String accountId;

  const AccountDetailScreen({super.key, required this.accountId});

  @override
  ConsumerState<AccountDetailScreen> createState() =>
      _AccountDetailScreenState();
}

class _AccountDetailScreenState extends ConsumerState<AccountDetailScreen> {
  List<TransactionModel> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(transactionsProvider.notifier).loadTransactions(
            accountId: widget.accountId,
          );
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);

    return accountsAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (accounts) {
        final account = accounts.where((a) => a.id == widget.accountId).firstOrNull;
        if (account == null) {
          return const Scaffold(body: Center(child: Text('Account not found')));
        }

        final txns = ref.watch(transactionsProvider);

        return Scaffold(
          appBar: AppBar(
            title: Text(account.name),
            actions: [
              PopupMenuButton(
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Text('Edit Account'),
                  ),
                  const PopupMenuItem(
                    value: 'archive',
                    child: Text('Archive Account'),
                  ),
                ],
                onSelected: (value) async {
                  if (value == 'edit') {
                    await context.push('/add-account', extra: account);
                    ref.read(accountsProvider.notifier).loadAccounts();
                  } else if (value == 'archive') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Archive Account'),
                        content: Text(
                            'Archive "${account.name}"? It will be hidden but not deleted.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Archive'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await ref
                          .read(accountsProvider.notifier)
                          .archiveAccount(account.id);
                      if (context.mounted) Navigator.of(context).pop();
                    }
                  }
                },
              ),
            ],
          ),
          body: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                child: Column(
                  children: [
                    Text(
                      'Balance',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      CurrencyFormatter.format(account.balance,
                          currency: account.currency),
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    if (account.isCreditCard && account.creditLimit != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Available: ${CurrencyFormatter.format(account.creditLimit! - account.balance.abs(), currency: account.currency)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: txns.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (transactions) {
                    if (transactions.isEmpty) {
                      return const Center(
                          child: Text('No transactions yet'));
                    }
                    return ListView.builder(
                      itemCount: transactions.length,
                      itemBuilder: (context, index) {
                        final txn = transactions[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: txn.type == 'income'
                                ? const Color(0xFF2E7D32).withOpacity(0.1)
                                : const Color(0xFFE53935).withOpacity(0.1),
                            child: Icon(
                              txn.type == 'income'
                                  ? Icons.arrow_downward
                                  : txn.type == 'transfer'
                                      ? Icons.swap_horiz
                                      : Icons.arrow_upward,
                              color: txn.type == 'income'
                                  ? const Color(0xFF2E7D32)
                                  : const Color(0xFFE53935),
                              size: 20,
                            ),
                          ),
                          title: Text(txn.description),
                          subtitle: Text(DateFormatter.formatRelative(
                              DateTime.parse(txn.date))),
                          trailing: Text(
                            '${txn.type == 'income' ? '+' : '-'}${CurrencyFormatter.format(txn.amount, currency: account.currency)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: txn.type == 'income'
                                  ? const Color(0xFF2E7D32)
                                  : null,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
