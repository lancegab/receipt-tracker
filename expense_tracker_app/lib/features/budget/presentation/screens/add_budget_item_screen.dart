import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../shared/models/account_model.dart';
import '../../../../shared/models/category_model.dart';
import '../../../../shared/models/budget_item_model.dart';
import '../../../accounts/presentation/providers/accounts_provider.dart';
import '../../../categories/presentation/providers/categories_provider.dart';
import '../providers/budget_provider.dart';

class AddBudgetItemScreen extends ConsumerStatefulWidget {
  final String budgetId;

  const AddBudgetItemScreen({super.key, required this.budgetId});

  @override
  ConsumerState<AddBudgetItemScreen> createState() =>
      _AddBudgetItemScreenState();
}

class _AddBudgetItemScreenState
    extends ConsumerState<AddBudgetItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  String? _linkedAccountId;
  String? _linkedCategoryId;
  bool _isLoading = false;
  BudgetItemModel? _editingItem;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final extra = GoRouterState.of(context).extra;
    if (extra is BudgetItemModel && _editingItem == null) {
      _editingItem = extra;
      _nameController.text = extra.name;
      _amountController.text = extra.budgetedAmount.toStringAsFixed(2);
      _linkedAccountId = extra.linkedAccountId;
      _linkedCategoryId = extra.linkedCategoryId;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider);
    final categories = ref.watch(categoriesProvider);
    final isEditing = _editingItem != null;

    return Scaffold(
      appBar:
          AppBar(title: Text(isEditing ? 'Edit Item' : 'Add Budget Item')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Item Name'),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Budgeted Amount',
                prefixText: '\u20B1 ',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Amount is required';
                if (double.tryParse(v) == null) return 'Invalid amount';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Link to account
            accounts.maybeWhen(
              data: (list) {
                final activeAccounts =
                    list.where((a) => !a.isArchived).toList();
                return DropdownButtonFormField<String?>(
                  value: _linkedAccountId,
                  decoration: const InputDecoration(
                    labelText: 'Link to Account (optional)',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('None'),
                    ),
                    ...activeAccounts.map((a) => DropdownMenuItem(
                          value: a.id,
                          child: Text(
                              '${a.name} (${a.type.replaceAll('_', ' ')})'),
                        )),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _linkedAccountId = v;
                      if (v != null) {
                        _linkedCategoryId = null;
                        // Auto-fill name from account
                        final acct =
                            activeAccounts.firstWhere((a) => a.id == v);
                        if (_nameController.text.isEmpty) {
                          _nameController.text = acct.name;
                        }
                      }
                    });
                  },
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),

            // Link to category
            categories.maybeWhen(
              data: (list) {
                final expenseCategories =
                    list.where((c) => c.type == 'expense' && c.isActive).toList();
                return DropdownButtonFormField<String?>(
                  value: _linkedCategoryId,
                  decoration: const InputDecoration(
                    labelText: 'Link to Category (optional)',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('None'),
                    ),
                    ...expenseCategories.map((c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(c.name),
                        )),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _linkedCategoryId = v;
                      if (v != null) {
                        _linkedAccountId = null;
                        final cat = expenseCategories
                            .firstWhere((c) => c.id == v);
                        if (_nameController.text.isEmpty) {
                          _nameController.text = cat.name;
                        }
                      }
                    });
                  },
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
            const SizedBox(height: 32),

            FilledButton(
              onPressed: _isLoading ? null : _save,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(isEditing ? 'Save Changes' : 'Add Item'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final service = ref.read(budgetItemServiceProvider);
      final data = {
        'name': _nameController.text.trim(),
        'budgetedAmount': double.parse(_amountController.text),
        'linkedAccountId': _linkedAccountId,
        'linkedCategoryId': _linkedCategoryId,
        'sortOrder': 0,
      };

      if (_editingItem != null) {
        await service.updateItem(
            widget.budgetId, _editingItem!.id, data);
      } else {
        await service.addItem(widget.budgetId, data);
      }

      ref.invalidate(budgetSummaryProvider(widget.budgetId));
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) context.showSnackBar('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
