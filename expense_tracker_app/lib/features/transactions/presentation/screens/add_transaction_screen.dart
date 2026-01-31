import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/transactions_provider.dart';
import '../../../../features/accounts/presentation/providers/accounts_provider.dart';
import '../../../../features/categories/presentation/providers/categories_provider.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/date_formatter.dart';

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
  String? _categoryId;
  String? _transferToAccountId;
  DateTime _date = DateTime.now();
  bool _isLoading = false;

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
        if (_categoryId != null) 'categoryId': _categoryId,
        if (_notesController.text.isNotEmpty)
          'notes': _notesController.text.trim(),
        if (_type == 'transfer' && _transferToAccountId != null)
          'transferToAccountId': _transferToAccountId,
      };

      await ref.read(transactionsProvider.notifier).createTransaction(data);
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
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Add Transaction')),
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
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: '\$ ',
                  prefixIcon: Icon(Icons.attach_money),
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
              // Category
              if (_type != 'transfer')
                categoriesAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const Text('Error loading categories'),
                  data: (categories) {
                    final filtered = categories
                        .where((c) =>
                            c.type == (_type == 'income' ? 'income' : 'expense'))
                        .toList();
                    return DropdownButtonFormField<String>(
                      value: _categoryId,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: filtered
                          .map((c) => DropdownMenuItem(
                                value: c.id,
                                child: Text(c.name),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _categoryId = v),
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
