import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../shared/models/budget_group_model.dart';
import '../providers/budget_provider.dart';
import '../providers/budget_groups_provider.dart';

class BudgetScreen extends ConsumerStatefulWidget {
  const BudgetScreen({super.key});

  @override
  ConsumerState<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends ConsumerState<BudgetScreen> {
  static const _monthNames = [
    '',
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  void _changeMonth(int delta) {
    final current = ref.read(selectedMonthProvider);
    final parts = current.split('-').map(int.parse).toList();
    var year = parts[0];
    var month = parts[1] + delta;
    if (month > 12) {
      month = 1;
      year++;
    } else if (month < 1) {
      month = 12;
      year--;
    }
    ref.read(selectedMonthProvider.notifier).state =
        '$year-${month.toString().padLeft(2, '0')}';
    ref.read(budgetsProvider.notifier).loadBudgets();
  }

  @override
  Widget build(BuildContext context) {
    final budgets = ref.watch(budgetsProvider);
    final month = ref.watch(selectedMonthProvider);
    final parts = month.split('-').map(int.parse).toList();
    final invitations = ref.watch(pendingInvitationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget'),
        actions: [
          IconButton(
            icon: const Icon(Icons.credit_card),
            tooltip: 'Installments',
            onPressed: () => context.push('/installments'),
          ),
          IconButton(
            icon: const Icon(Icons.group),
            tooltip: 'Budget Groups',
            onPressed: () => context.push('/groups'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Month selector
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => _changeMonth(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  '${_monthNames[parts[1]]} ${parts[0]}',
                  style: context.textTheme.titleLarge,
                ),
                IconButton(
                  onPressed: () => _changeMonth(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),

          // Pending invitations banner
          invitations.maybeWhen(
            data: (list) {
              if (list.isEmpty) return const SizedBox.shrink();
              return _InvitationBanner(invitations: list);
            },
            orElse: () => const SizedBox.shrink(),
          ),

          // Budget list
          Expanded(
            child: budgets.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (list) {
                if (list.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calculate_outlined,
                            size: 64, color: context.colorScheme.outline),
                        const SizedBox(height: 16),
                        Text('No budgets for this month',
                            style: context.textTheme.bodyLarge),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: () => context.push('/create-budget'),
                          icon: const Icon(Icons.add),
                          label: const Text('Create Budget'),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () =>
                      ref.read(budgetsProvider.notifier).loadBudgets(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final budget = list[index];
                      return Card(
                        child: ListTile(
                          leading: Icon(
                            budget.isGroupBudget
                                ? Icons.group
                                : Icons.person,
                          ),
                          title: Text(budget.name),
                          subtitle: Text(budget.month),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () =>
                              context.push('/budget/${budget.id}'),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/create-budget'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _InvitationBanner extends ConsumerWidget {
  final List<GroupInvitationModel> invitations;

  const _InvitationBanner({required this.invitations});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        color: context.colorScheme.primaryContainer,
        child: ListTile(
          leading: const Icon(Icons.mail),
          title: Text(
              '${invitations.length} pending group invitation${invitations.length > 1 ? 's' : ''}'),
          trailing: TextButton(
            onPressed: () => context.push('/groups'),
            child: const Text('View'),
          ),
        ),
      ),
    );
  }
}
