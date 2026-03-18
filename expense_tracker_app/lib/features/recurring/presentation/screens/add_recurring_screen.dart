import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/recurring_provider.dart';
import '../../../../features/accounts/presentation/providers/accounts_provider.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/models/recurring_transaction_model.dart';

class AddRecurringScreen extends ConsumerStatefulWidget {
  const AddRecurringScreen({super.key});

  @override
  ConsumerState<AddRecurringScreen> createState() => _AddRecurringScreenState();
}

class _AddRecurringScreenState extends ConsumerState<AddRecurringScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();

  String _type = 'expense';
  String _frequency = 'monthly';
  String? _accountId;
  DateTime _startDate = DateTime.now();
  RecurringTransactionModel? _editingItem;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final extra = GoRouterState.of(context).extra;
    if (extra is RecurringTransactionModel && _editingItem == null) {
      _editingItem = extra;
      _descriptionController.text = extra.description;
      _amountController.text = extra.amount.toStringAsFixed(2);
      _type = extra.type;
      _frequency = extra.frequency;
      _accountId = extra.accountId;
      _startDate =
          DateTime.tryParse(extra.startDate) ?? DateTime.now();
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_accountId == null) {
      context.showSnackBar('Please select an account', isError: true);
      return;
    }

    try {
      final data = {
        'accountId': _accountId,
        'type': _type,
        'amount': double.parse(_amountController.text),
        'description': _descriptionController.text.trim(),
        'frequency': _frequency,
        'startDate':
            '${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}',
      };
      if (_editingItem != null) {
        await ref
            .read(recurringProvider.notifier)
            .updateRecurring(_editingItem!.id, data);
      } else {
        await ref.read(recurringProvider.notifier).createRecurring(data);
      }
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) context.showSnackBar(e.toString(), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsState = ref.watch(accountsProvider);
    final isEditing = _editingItem != null;
    final userCurrency =
        ref.watch(authStateProvider).valueOrNull?.defaultCurrency ?? 'PHP';
    final currencySymbol = CurrencyFormatter.getSymbol(userCurrency);

    return Scaffold(
      appBar: AppBar(
          title: Text(isEditing
              ? 'Edit Recurring Transaction'
              : 'Add Recurring Transaction')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Type
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'expense', label: Text('Expense')),
                ButtonSegment(value: 'income', label: Text('Income')),
              ],
              selected: {_type},
              onSelectionChanged: (set) =>
                  setState(() => _type = set.first),
            ),
            const SizedBox(height: 16),

            // Account
            accountsState.when(
              loading: () =>
                  const LinearProgressIndicator(),
              error: (e, _) => Text('Error loading accounts: $e'),
              data: (accounts) => DropdownButtonFormField<String>(
                value: _accountId,
                decoration: const InputDecoration(
                  labelText: 'Account',
                  prefixIcon: Icon(Icons.account_balance_wallet),
                ),
                items: accounts
                    .map((a) => DropdownMenuItem(
                          value: a.id,
                          child: Text(a.name),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _accountId = v),
                validator: (v) => v == null ? 'Required' : null,
              ),
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                prefixIcon: Icon(Icons.description),
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),

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
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (double.tryParse(v) == null) return 'Invalid amount';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Frequency
            DropdownButtonFormField<String>(
              value: _frequency,
              decoration: const InputDecoration(
                labelText: 'Frequency',
                prefixIcon: Icon(Icons.repeat),
              ),
              items: const [
                DropdownMenuItem(value: 'daily', child: Text('Daily')),
                DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                DropdownMenuItem(value: 'biweekly', child: Text('Bi-weekly')),
                DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                DropdownMenuItem(
                    value: 'quarterly', child: Text('Quarterly')),
                DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
              ],
              onChanged: (v) =>
                  setState(() => _frequency = v ?? 'monthly'),
            ),
            const SizedBox(height: 16),

            // Start date
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: const Text('Start Date'),
              subtitle: Text(
                '${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}',
              ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _startDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (picked != null) setState(() => _startDate = picked);
              },
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _submit,
              child: Text(
                  isEditing ? 'Save Changes' : 'Create Recurring Transaction'),
            ),
          ],
        ),
      ),
    );
  }
}
