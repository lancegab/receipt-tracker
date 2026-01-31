import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/models/receipt_model.dart';
import '../../../../features/transactions/presentation/providers/transactions_provider.dart';
import '../../../../features/accounts/presentation/providers/accounts_provider.dart';
import '../../../../features/categories/presentation/providers/categories_provider.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/extensions/context_extensions.dart';

class ReceiptReviewScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? receiptData;

  const ReceiptReviewScreen({super.key, this.receiptData});

  @override
  ConsumerState<ReceiptReviewScreen> createState() =>
      _ReceiptReviewScreenState();
}

class _ReceiptReviewScreenState extends ConsumerState<ReceiptReviewScreen> {
  late ReceiptModel _receipt;
  String? _selectedAccountId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.receiptData != null &&
        widget.receiptData!['receipt'] is ReceiptModel) {
      _receipt = widget.receiptData!['receipt'] as ReceiptModel;
    } else {
      _receipt = const ReceiptModel(id: '');
    }
  }

  Future<void> _saveAll() async {
    if (_selectedAccountId == null) {
      context.showSnackBar('Please select an account', isError: true);
      return;
    }

    final selectedItems =
        _receipt.lineItems.where((item) => item.isSelected).toList();

    if (selectedItems.isEmpty) {
      context.showSnackBar('Please select at least one item', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final transactions = selectedItems.map((item) {
        return {
          'accountId': _selectedAccountId,
          'type': 'expense',
          'amount': item.totalPrice,
          'date': _receipt.transactionDate ??
              DateFormatter.formatApiDate(DateTime.now()),
          'description': item.description,
          'merchantName': _receipt.merchantName,
          'receiptId': _receipt.id,
          if (item.selectedCategoryId != null)
            'categoryId': item.selectedCategoryId,
        };
      }).toList();

      await ref
          .read(transactionsProvider.notifier)
          .createBatchTransactions(transactions);

      ref.read(accountsProvider.notifier).loadAccounts();

      if (mounted) {
        context.showSnackBar(
            '${selectedItems.length} transactions saved');
        context.go('/dashboard');
      }
    } catch (e) {
      if (mounted) context.showSnackBar(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final selectedCount =
        _receipt.lineItems.where((i) => i.isSelected).length;
    final selectedTotal = _receipt.lineItems
        .where((i) => i.isSelected)
        .fold(0.0, (sum, i) => sum + i.totalPrice);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Receipt'),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                for (final item in _receipt.lineItems) {
                  item.isSelected = !item.isSelected;
                }
              });
            },
            child: const Text('Toggle All'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Merchant info
          if (_receipt.merchantName != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: context.colorScheme.surfaceContainerHighest.withOpacity(0.3),
              child: Column(
                children: [
                  Text(
                    _receipt.merchantName!,
                    style: context.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_receipt.transactionDate != null)
                    Text(_receipt.transactionDate!),
                  if (_receipt.confidenceScore != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Confidence: ${(_receipt.confidenceScore! * 100).toStringAsFixed(0)}%',
                        style: context.textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
          // Account selector
          Padding(
            padding: const EdgeInsets.all(16),
            child: accountsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('Error loading accounts'),
              data: (accounts) {
                final active =
                    accounts.where((a) => !a.isArchived).toList();
                return DropdownButtonFormField<String>(
                  value: _selectedAccountId,
                  decoration: const InputDecoration(
                    labelText: 'Charge to Account',
                    prefixIcon: Icon(Icons.account_balance_wallet),
                  ),
                  items: active
                      .map((a) => DropdownMenuItem(
                            value: a.id,
                            child: Text(a.name),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _selectedAccountId = v),
                );
              },
            ),
          ),
          // Line items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _receipt.lineItems.length,
              itemBuilder: (context, index) {
                final item = _receipt.lineItems[index];
                return Card(
                  child: CheckboxListTile(
                    value: item.isSelected,
                    onChanged: (v) {
                      setState(() => item.isSelected = v ?? true);
                    },
                    title: Text(
                      item.description,
                      style: TextStyle(
                        decoration: item.isSelected
                            ? null
                            : TextDecoration.lineThrough,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.quantity > 1)
                          Text(
                              '${item.quantity} x ${CurrencyFormatter.format(item.unitPrice)}'),
                        // Category selector
                        categoriesAsync.when(
                          loading: () => const SizedBox(),
                          error: (_, __) => const SizedBox(),
                          data: (categories) {
                            final expenseCats = categories
                                .where((c) => c.type == 'expense')
                                .toList();
                            return DropdownButton<String>(
                              value: item.selectedCategoryId,
                              hint: Text(
                                item.categorySuggestion ?? 'Select category',
                                style: context.textTheme.bodySmall,
                              ),
                              isExpanded: true,
                              underline: const SizedBox(),
                              isDense: true,
                              items: expenseCats
                                  .map((c) => DropdownMenuItem(
                                        value: c.id,
                                        child: Text(c.name,
                                            style:
                                                context.textTheme.bodySmall),
                                      ))
                                  .toList(),
                              onChanged: (v) {
                                setState(
                                    () => item.selectedCategoryId = v);
                              },
                            );
                          },
                        ),
                      ],
                    ),
                    secondary: Text(
                      CurrencyFormatter.format(item.totalPrice),
                      style: context.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Bottom bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('$selectedCount items selected'),
                      Text(
                        CurrencyFormatter.format(selectedTotal),
                        style: context.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveAll,
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text('Save $selectedCount Transactions'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
