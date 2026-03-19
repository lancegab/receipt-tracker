import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/transactions_provider.dart';
import '../../../../features/accounts/presentation/providers/accounts_provider.dart';
import '../../../../features/budget/presentation/providers/budget_provider.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/models/transaction_model.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _notesController = TextEditingController();
  final _merchantController = TextEditingController();

  String _type = 'expense';
  String? _accountId;
  String? _budgetItemId;
  String? _transferToAccountId;
  DateTime _date = DateTime.now();
  bool _isLoading = false;
  TransactionModel? _editingTxn;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final extra = GoRouterState.of(context).extra;
    if (extra is TransactionModel && _editingTxn == null) {
      _editingTxn = extra;
      _amountController.text = extra.amount.toStringAsFixed(2);
      _descriptionController.text = extra.description;
      _notesController.text = extra.notes ?? '';
      _merchantController.text = extra.merchantName ?? '';
      _type = extra.type;
      _accountId = extra.accountId;
      _budgetItemId = extra.budgetItemId;
      _transferToAccountId = extra.transferToAccountId;
      _date = DateTime.tryParse(extra.date) ?? DateTime.now();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    _merchantController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_accountId == null) {
      context.showSnackBar('Please select an account', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final data = {
        'accountId': _accountId,
        'type': _type,
        'amount': double.parse(_amountController.text),
        'date': DateFormatter.formatApiDate(_date),
        'description': _descriptionController.text.trim(),
        if (_merchantController.text.isNotEmpty)
          'merchantName': _merchantController.text.trim(),
        if (_budgetItemId != null) 'budgetItemId': _budgetItemId,
        if (_notesController.text.isNotEmpty)
          'notes': _notesController.text.trim(),
        if (_type == 'transfer' && _transferToAccountId != null)
          'transferToAccountId': _transferToAccountId,
      };

      if (_editingTxn != null) {
        await ref
            .read(transactionsProvider.notifier)
            .updateTransaction(_editingTxn!.id, data);
      } else {
        await ref.read(transactionsProvider.notifier).createTransaction(data);
      }
      if (mounted) {
        ref.read(accountsProvider.notifier).loadAccounts();
        context.pop();
      }
    } catch (e) {
      if (mounted) context.showSnackBar(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final month =
        '${_date.year}-${_date.month.toString().padLeft(2, '0')}';
    final budgetItemsAsync = ref.watch(budgetItemsForMonthProvider(month));
    final userCurrency =
        ref.watch(authStateProvider).valueOrNull?.defaultCurrency ?? 'PHP';

    // Get currency symbol from selected account, fallback to user default
    final selectedCurrency = accountsAsync.maybeWhen(
      data: (accounts) {
        if (_accountId == null) return userCurrency;
        final acct = accounts.where((a) => a.id == _accountId).firstOrNull;
        return acct?.currency ?? userCurrency;
      },
      orElse: () => userCurrency,
    );
    final currencySymbol = CurrencyFormatter.getSymbol(selectedCurrency);

    return Scaffold(
      appBar: AppBar(
          title: Text(
              _editingTxn != null ? 'Edit Transaction' : 'Add Transaction')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Type selector
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'expense', label: Text('Expense')),
                  ButtonSegment(value: 'income', label: Text('Income')),
                  ButtonSegment(value: 'transfer', label: Text('Transfer')),
                ],
                selected: {_type},
                onSelectionChanged: (v) =>
                    setState(() => _type = v.first),
              ),
              const SizedBox(height: 24),
              // Amount
              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixText: '$currencySymbol ',
                  prefixIcon: const Icon(Icons.attach_money),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: context.textTheme.headlineSmall,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Amount is required';
                  if (double.tryParse(v) == null) return 'Invalid amount';
                  if (double.parse(v) <= 0) return 'Amount must be positive';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  prefixIcon: Icon(Icons.description_outlined),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Description is required' : null,
              ),
              const SizedBox(height: 16),
              // Account
              accountsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const Text('Error loading accounts'),
                data: (accounts) {
                  final active =
                      accounts.where((a) => !a.isArchived).toList();
                  return DropdownButtonFormField<String>(
                    value: _accountId,
                    decoration: const InputDecoration(
                      labelText: 'Account',
                      prefixIcon: Icon(Icons.account_balance_wallet),
                    ),
                    items: active
                        .map((a) => DropdownMenuItem(
                              value: a.id,
                              child: Text(a.name),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _accountId = v),
                    validator: (v) => v == null ? 'Select an account' : null,
                  );
                },
              ),
              if (_type == 'transfer') ...[
                const SizedBox(height: 16),
                accountsAsync.when(
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                  data: (accounts) {
                    final active =
                        accounts.where((a) => !a.isArchived && a.id != _accountId).toList();
                    return DropdownButtonFormField<String>(
                      value: _transferToAccountId,
                      decoration: const InputDecoration(
                        labelText: 'Transfer To',
                        prefixIcon: Icon(Icons.arrow_forward),
                      ),
                      items: active
                          .map((a) => DropdownMenuItem(
                                value: a.id,
                                child: Text(a.name),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _transferToAccountId = v),
                    );
                  },
                ),
              ],
              const SizedBox(height: 16),
              // Budget Item (replaces Category)
              if (_type != 'transfer')
                budgetItemsAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const Text('No budget for this month'),
                  data: (items) {
                    // Reset selection if not in the list
                    if (_budgetItemId != null &&
                        !items.any((i) => i.id == _budgetItemId)) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) setState(() => _budgetItemId = null);
                      });
                    }
                    return DropdownButtonFormField<String>(
                      value: items.any((i) => i.id == _budgetItemId)
                          ? _budgetItemId
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Budget Item',
                        prefixIcon: Icon(Icons.calculate_outlined),
                      ),
                      items: items
                          .map((i) => DropdownMenuItem(
                                value: i.id,
                                child: Text(
                                  i.budgetName.isNotEmpty
                                      ? '${i.name} (${i.budgetName})'
                                      : i.name,
                                ),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _budgetItemId = v),
                    );
                  },
                ),
              const SizedBox(height: 16),
              // Date
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: Text(DateFormatter.formatDate(_date)),
                trailing: const Icon(Icons.chevron_right),
                onTap: _selectDate,
              ),
              const SizedBox(height: 16),
              // Merchant
              TextFormField(
                controller: _merchantController,
                decoration: const InputDecoration(
                  labelText: 'Merchant (optional)',
                  prefixIcon: Icon(Icons.store),
                ),
              ),
              const SizedBox(height: 16),
              // Notes
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  prefixIcon: Icon(Icons.notes),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _save,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_type == 'transfer' ? 'Transfer' : 'Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
