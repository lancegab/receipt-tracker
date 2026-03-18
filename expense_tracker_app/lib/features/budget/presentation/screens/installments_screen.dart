import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../shared/models/installment_model.dart';
import '../../../../shared/models/account_model.dart';
import '../../../accounts/presentation/providers/accounts_provider.dart';
import '../providers/installments_provider.dart';

class InstallmentsScreen extends ConsumerWidget {
  const InstallmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final installments = ref.watch(installmentsProvider);
    final accounts = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Credit Card Installments')),
      body: installments.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.credit_card,
                      size: 64,
                      color: context.colorScheme.outline),
                  const SizedBox(height: 16),
                  Text('No installments yet',
                      style: context.textTheme.bodyLarge),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () =>
                        context.push('/add-installment'),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Installment'),
                  ),
                ],
              ),
            );
          }

          // Group by account
          final grouped = <String, List<InstallmentModel>>{};
          for (final inst in list) {
            grouped
                .putIfAbsent(inst.accountId, () => [])
                .add(inst);
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: grouped.entries.map((entry) {
              final accountName = accounts.maybeWhen(
                data: (accts) {
                  final acct = accts
                      .where((a) => a.id == entry.key)
                      .firstOrNull;
                  return acct?.name ?? 'Unknown Card';
                },
                orElse: () => 'Credit Card',
              );

              // Total monthly across all installments for this card
              final totalMonthly = entry.value
                  .where((i) => i.isActive)
                  .fold(0.0, (sum, i) => sum + i.monthlyAmount);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.credit_card, size: 20),
                        const SizedBox(width: 8),
                        Text(accountName,
                            style:
                                context.textTheme.titleMedium),
                        const Spacer(),
                        Text(
                          '${totalMonthly.toStringAsFixed(2)}/mo',
                          style:
                              context.textTheme.titleSmall?.copyWith(
                            color: context.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...entry.value.map((inst) =>
                      _InstallmentCard(installment: inst)),
                  const SizedBox(height: 16),
                ],
              );
            }).toList(),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/add-installment'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _InstallmentCard extends ConsumerWidget {
  final InstallmentModel installment;

  const _InstallmentCard({required this.installment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(installment.description,
                      style: context.textTheme.titleSmall),
                ),
                if (!installment.isActive)
                  Chip(
                    label: const Text('Inactive'),
                    labelStyle: const TextStyle(fontSize: 10),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize:
                        MaterialTapTargetSize.shrinkWrap,
                  ),
                PopupMenuButton<String>(
                  iconSize: 20,
                  onSelected: (action) {
                    if (action == 'deactivate') {
                      ref
                          .read(installmentsProvider.notifier)
                          .deactivateInstallment(installment.id);
                    }
                  },
                  itemBuilder: (context) => [
                    if (installment.isActive)
                      const PopupMenuItem(
                          value: 'deactivate',
                          child: Text('Deactivate')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: installment.progressPercent.toDouble(),
                backgroundColor:
                    context.colorScheme.surfaceContainerHighest,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total: ${installment.totalAmount.toStringAsFixed(2)}',
                  style: context.textTheme.bodySmall,
                ),
                Text(
                  '${installment.monthlyAmount.toStringAsFixed(2)}/mo x ${installment.totalMonths}',
                  style: context.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Text(
              '${installment.startMonth} - ${installment.endMonth}  (${installment.monthsRemaining} months left)',
              style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}
