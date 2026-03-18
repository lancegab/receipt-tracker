import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/transactions_provider.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../features/accounts/presentation/providers/accounts_provider.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txnsAsync = ref.watch(transactionsProvider);
    final totalBalance = ref.watch(totalBalanceProvider);
    final userCurrency =
        ref.watch(authStateProvider).valueOrNull?.defaultCurrency ?? 'PHP';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              // TODO: Show filter bottom sheet
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Balance header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: context.colorScheme.primaryContainer.withOpacity(0.3),
            ),
            child: Column(
              children: [
                Text('Total Balance',
                    style: context.textTheme.bodyMedium),
                const SizedBox(height: 4),
                Text(
                  CurrencyFormatter.format(totalBalance,
                      currency: userCurrency),
                  style: context.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // Quick actions
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _QuickAction(
                    icon: Icons.add,
                    label: 'Add',
                    onTap: () => context.push('/add-transaction'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.camera_alt,
                    label: 'Scan',
                    onTap: () => context.push('/scan-receipt'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.swap_horiz,
                    label: 'Transfer',
                    onTap: () => context.push('/add-transaction'),
                  ),
                ),
              ],
            ),
          ),
          // Transactions list
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recent Transactions',
                    style: context.textTheme.titleMedium),
              ],
            ),
          ),
          Expanded(
            child: txnsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Error loading transactions'),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => ref
                          .read(transactionsProvider.notifier)
                          .loadTransactions(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (transactions) {
                if (transactions.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long,
                            size: 64,
                            color: context.colorScheme.onSurfaceVariant),
                        const SizedBox(height: 16),
                        const Text('No transactions yet'),
                        const SizedBox(height: 8),
                        const Text('Add a transaction or scan a receipt'),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => ref
                      .read(transactionsProvider.notifier)
                      .loadTransactions(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: transactions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final txn = transactions[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: txn.type == 'income'
                              ? const Color(0xFF2E7D32).withOpacity(0.1)
                              : txn.type == 'transfer'
                                  ? const Color(0xFFFFC107).withOpacity(0.15)
                                  : const Color(0xFFE53935).withOpacity(0.1),
                          child: Icon(
                            txn.type == 'income'
                                ? Icons.arrow_downward
                                : txn.type == 'transfer'
                                    ? Icons.swap_horiz
                                    : Icons.arrow_upward,
                            color: txn.type == 'income'
                                ? const Color(0xFF2E7D32)
                                : txn.type == 'transfer'
                                    ? const Color(0xFFF57F17)
                                    : const Color(0xFFE53935),
                            size: 20,
                          ),
                        ),
                        title: Text(
                          txn.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          DateFormatter.formatRelative(
                              DateTime.parse(txn.date)),
                        ),
                        trailing: Text(
                          '${txn.type == 'income' ? '+' : '-'}${CurrencyFormatter.format(txn.amount, currency: userCurrency)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: txn.type == 'income'
                                ? const Color(0xFF2E7D32)
                                : null,
                          ),
                        ),
                        onTap: () {
                          // TODO: Navigate to transaction detail
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
