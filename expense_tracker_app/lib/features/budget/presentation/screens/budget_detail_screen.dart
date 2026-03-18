import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../shared/models/budget_item_model.dart';
import '../providers/budget_provider.dart';

class BudgetDetailScreen extends ConsumerStatefulWidget {
  final String budgetId;

  const BudgetDetailScreen({super.key, required this.budgetId});

  @override
  ConsumerState<BudgetDetailScreen> createState() =>
      _BudgetDetailScreenState();
}

class _BudgetDetailScreenState
    extends ConsumerState<BudgetDetailScreen> {
  bool _showWeekly = false;

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(budgetSummaryProvider(widget.budgetId));

    return Scaffold(
      appBar: AppBar(
        title: summary.maybeWhen(
          data: (s) => Text(s.budget['name'] ?? 'Budget'),
          orElse: () => const Text('Budget'),
        ),
        actions: [
          IconButton(
            icon: Icon(
                _showWeekly ? Icons.view_list : Icons.view_week),
            tooltip: _showWeekly ? 'Monthly view' : 'Weekly view',
            onPressed: () =>
                setState(() => _showWeekly = !_showWeekly),
          ),
          PopupMenuButton<String>(
            onSelected: (value) => _handleMenuAction(value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                  value: 'copy', child: Text('Copy to next month')),
              const PopupMenuItem(
                  value: 'generate',
                  child: Text('Auto-generate items')),
              const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete budget')),
            ],
          ),
        ],
      ),
      body: summary.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(budgetSummaryProvider(widget.budgetId));
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Summary cards
              _BudgetSummaryCards(
                totalBudgeted: data.totalBudgeted,
                totalSpent: data.totalSpent,
                totalRemaining: data.totalRemaining,
              ),
              const SizedBox(height: 16),

              // Items
              if (data.items.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Text('No budget items yet',
                            style: context.textTheme.bodyLarge),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: () => context.push(
                              '/budget/${widget.budgetId}/add-item'),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Item'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...data.items.map((item) => _showWeekly
                    ? _WeeklyItemCard(
                        item: item,
                        budgetId: widget.budgetId,
                      )
                    : _MonthlyItemCard(
                        item: item,
                        budgetId: widget.budgetId,
                      )),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            context.push('/budget/${widget.budgetId}/add-item'),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _handleMenuAction(String action) async {
    switch (action) {
      case 'copy':
        await _copyToNextMonth();
        break;
      case 'generate':
        await _generateItems();
        break;
      case 'delete':
        await _deleteBudget();
        break;
    }
  }

  Future<void> _copyToNextMonth() async {
    final summary =
        ref.read(budgetSummaryProvider(widget.budgetId)).valueOrNull;
    if (summary == null) return;

    final currentMonth = summary.budget['month'] as String;
    final parts = currentMonth.split('-').map(int.parse).toList();
    var year = parts[0];
    var month = parts[1] + 1;
    if (month > 12) {
      month = 1;
      year++;
    }
    final targetMonth = '$year-${month.toString().padLeft(2, '0')}';

    try {
      final newBudget = await ref
          .read(budgetsProvider.notifier)
          .copyBudget(widget.budgetId, targetMonth);
      if (newBudget != null && mounted) {
        context.showSnackBar('Budget copied to $targetMonth');
      }
    } catch (e) {
      if (mounted) context.showSnackBar('Error: $e');
    }
  }

  Future<void> _generateItems() async {
    try {
      final result =
          await ref.read(budgetItemServiceProvider).generateItems(
        widget.budgetId,
        {
          'fromAccounts': true,
          'fromCategories': true,
          'accountTypes': ['credit_card'],
          'categoryType': 'expense',
        },
      );
      ref.invalidate(budgetSummaryProvider(widget.budgetId));
      if (mounted) {
        context.showSnackBar(
            'Generated ${result['generatedCount']} items');
      }
    } catch (e) {
      if (mounted) context.showSnackBar('Error: $e');
    }
  }

  Future<void> _deleteBudget() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Budget'),
        content: const Text(
            'This will delete the budget and all its items. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref
            .read(budgetsProvider.notifier)
            .deleteBudget(widget.budgetId);
        if (mounted) context.pop();
      } catch (e) {
        if (mounted) context.showSnackBar('Error: $e');
      }
    }
  }
}

class _BudgetSummaryCards extends StatelessWidget {
  final double totalBudgeted;
  final double totalSpent;
  final double totalRemaining;

  const _BudgetSummaryCards({
    required this.totalBudgeted,
    required this.totalSpent,
    required this.totalRemaining,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _SummaryCard(
          label: 'Budgeted',
          amount: totalBudgeted,
          color: context.colorScheme.primary,
        ),
        const SizedBox(width: 8),
        _SummaryCard(
          label: 'Spent',
          amount: totalSpent,
          color: context.colorScheme.error,
        ),
        const SizedBox(width: 8),
        _SummaryCard(
          label: 'Left',
          amount: totalRemaining,
          color: totalRemaining >= 0 ? const Color(0xFF2E7D32) : context.colorScheme.error,
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(label,
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              FittedBox(
                child: Text(
                  amount.toStringAsFixed(2),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthlyItemCard extends ConsumerWidget {
  final BudgetItemModel item;
  final String budgetId;

  const _MonthlyItemCard({
    required this.item,
    required this.budgetId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pct = item.spentPercentage;
    final progressColor = pct > 1.0
        ? context.colorScheme.error
        : pct > 0.8
            ? const Color(0xFFFFC107)
            : const Color(0xFF2E7D32);

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
                  child: Text(item.name,
                      style: context.textTheme.titleSmall),
                ),
                PopupMenuButton<String>(
                  iconSize: 20,
                  onSelected: (action) =>
                      _handleItemAction(context, ref, action),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                        value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(
                        value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct.clamp(0, 1).toDouble(),
                backgroundColor:
                    context.colorScheme.surfaceContainerHighest,
                color: progressColor,
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Spent: ${item.totalSpent.toStringAsFixed(2)}',
                  style: context.textTheme.bodySmall,
                ),
                Text(
                  'Budget: ${item.budgetedAmount.toStringAsFixed(2)}',
                  style: context.textTheme.bodySmall,
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (item.installmentAmount > 0)
                  Text(
                    'Installments: ${item.installmentAmount.toStringAsFixed(2)}',
                    style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.tertiary),
                  ),
                Text(
                  'Left: ${item.remaining.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: item.remaining >= 0
                        ? const Color(0xFF2E7D32)
                        : context.colorScheme.error,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleItemAction(
      BuildContext context, WidgetRef ref, String action) async {
    if (action == 'delete') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete Item'),
          content: Text('Remove "${item.name}" from this budget?'),
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
      if (confirm != true) return;
      try {
        await ref
            .read(budgetItemServiceProvider)
            .deleteItem(budgetId, item.id);
        ref.invalidate(budgetSummaryProvider(budgetId));
      } catch (e) {
        if (context.mounted) context.showSnackBar('Error: $e');
      }
    } else if (action == 'edit') {
      context.push('/budget/$budgetId/add-item',
          extra: item);
    }
  }
}

class _WeeklyItemCard extends StatelessWidget {
  final BudgetItemModel item;
  final String budgetId;

  const _WeeklyItemCard({
    required this.item,
    required this.budgetId,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.name, style: context.textTheme.titleSmall),
            Text(
              'Budget: ${item.budgetedAmount.toStringAsFixed(2)}',
              style: context.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(1),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(1),
                3: FlexColumnWidth(1),
              },
              children: [
                TableRow(
                  children: ['W1', 'W2', 'W3', 'W4']
                      .map((w) => Padding(
                            padding: const EdgeInsets.all(4),
                            child: Text(w,
                                textAlign: TextAlign.center,
                                style: context.textTheme.labelSmall
                                    ?.copyWith(
                                        fontWeight: FontWeight.bold)),
                          ))
                      .toList(),
                ),
                TableRow(
                  children: [1, 2, 3, 4].map((week) {
                    final wb = item.weeklyBreakdown?[week];
                    final auto = wb?.autoSpent ?? 0;
                    final manual = wb?.manualAdjustment ?? 0;
                    final total = auto + manual;
                    return Padding(
                      padding: const EdgeInsets.all(4),
                      child: Text(
                        total == 0
                            ? '-'
                            : total.toStringAsFixed(0),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: total < 0
                              ? context.colorScheme.error
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total Spent: ${item.totalSpent.toStringAsFixed(2)}',
                    style: context.textTheme.bodySmall),
                Text(
                  'Left: ${item.remaining.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: item.remaining >= 0
                        ? const Color(0xFF2E7D32)
                        : context.colorScheme.error,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
