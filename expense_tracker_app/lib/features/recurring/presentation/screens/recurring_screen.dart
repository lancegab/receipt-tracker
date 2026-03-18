import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/recurring_provider.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/models/recurring_transaction_model.dart';

class RecurringScreen extends ConsumerWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recurringState = ref.watch(recurringProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring Transactions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Process due transactions',
            onPressed: () async {
              try {
                await ref.read(recurringProvider.notifier).processRecurring();
                if (context.mounted) {
                  context.showSnackBar('Processed due transactions');
                }
              } catch (e) {
                if (context.mounted) {
                  context.showSnackBar(e.toString(), isError: true);
                }
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/add-recurring'),
        child: const Icon(Icons.add),
      ),
      body: recurringState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.repeat, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No recurring transactions',
                      style: TextStyle(fontSize: 16, color: Colors.grey)),
                  SizedBox(height: 8),
                  Text('Tap + to create one',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _RecurringCard(item: item);
            },
          );
        },
      ),
    );
  }
}

class _RecurringCard extends ConsumerWidget {
  final RecurringTransactionModel item;

  const _RecurringCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExpense = item.type == 'expense';
    final color = isExpense
        ? context.colorScheme.error
        : const Color(0xFF2E7D32);
    final userCurrency =
        ref.watch(authStateProvider).valueOrNull?.defaultCurrency ?? 'PHP';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(
            isExpense ? Icons.arrow_downward : Icons.arrow_upward,
            color: color,
          ),
        ),
        title: Text(item.description),
        subtitle: Text(
          '${item.frequencyLabel} \u2022 Next: ${item.nextOccurrence}',
        ),
        trailing: Text(
          '${isExpense ? '-' : '+'}${CurrencyFormatter.format(item.amount, currency: userCurrency)}',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        onTap: () => context.push('/add-recurring', extra: item),
        onLongPress: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Delete Recurring'),
              content: const Text(
                  'Are you sure you want to deactivate this recurring transaction?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Delete'),
                ),
              ],
            ),
          );
          if (confirmed == true) {
            await ref.read(recurringProvider.notifier).deleteRecurring(item.id);
          }
        },
      ),
    );
  }
}
