import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../accounts/presentation/providers/accounts_provider.dart';
import '../providers/installments_provider.dart';

class AddInstallmentScreen extends ConsumerStatefulWidget {
  const AddInstallmentScreen({super.key});

  @override
  ConsumerState<AddInstallmentScreen> createState() =>
      _AddInstallmentScreenState();
}

class _AddInstallmentScreenState
    extends ConsumerState<AddInstallmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _totalAmountController = TextEditingController();
  final _monthsController = TextEditingController(text: '3');
  String? _selectedAccountId;
  late int _startYear;
  late int _startMonth;
  bool _isLoading = false;

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

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startYear = now.year;
    _startMonth = now.month;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _totalAmountController.dispose();
    _monthsController.dispose();
    super.dispose();
  }

  double get _monthlyAmount {
    final total =
        double.tryParse(_totalAmountController.text) ?? 0;
    final months = int.tryParse(_monthsController.text) ?? 1;
    return months > 0 ? total / months : 0;
  }

  String get _startMonthString =>
      '$_startYear-${_startMonth.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Add Installment')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Credit card selector
            accounts.maybeWhen(
              data: (list) {
                final ccAccounts = list
                    .where((a) =>
                        a.type == 'credit_card' && !a.isArchived)
                    .toList();
                if (ccAccounts.isEmpty) {
                  return Card(
                    color: context.colorScheme.errorContainer,
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                          'No credit card accounts found. Create one first.'),
                    ),
                  );
                }
                return DropdownButtonFormField<String>(
                  value: _selectedAccountId,
                  decoration: const InputDecoration(
                    labelText: 'Credit Card',
                  ),
                  items: ccAccounts
                      .map((a) => DropdownMenuItem(
                            value: a.id,
                            child: Text(a.name),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _selectedAccountId = v),
                  validator: (v) =>
                      v == null ? 'Select a credit card' : null,
                );
              },
              orElse: () =>
                  const Center(child: CircularProgressIndicator()),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _descriptionController,
              decoration:
                  const InputDecoration(labelText: 'Description'),
              validator: (v) => v == null || v.isEmpty
                  ? 'Description is required'
                  : null,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _totalAmountController,
              decoration: const InputDecoration(
                labelText: 'Total Amount',
                prefixText: '\u20B1 ',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true),
              onChanged: (_) => setState(() {}),
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return 'Amount is required';
                }
                if (double.tryParse(v) == null) {
                  return 'Invalid amount';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _monthsController,
              decoration: const InputDecoration(
                labelText: 'Number of Months',
                suffixText: 'months',
              ),
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return 'Required';
                }
                final n = int.tryParse(v);
                if (n == null || n < 2 || n > 60) {
                  return 'Must be 2-60';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Start month
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Start Month'),
              subtitle:
                  Text('${_monthNames[_startMonth]} $_startYear'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _startMonth--;
                        if (_startMonth < 1) {
                          _startMonth = 12;
                          _startYear--;
                        }
                      });
                    },
                    icon: const Icon(Icons.chevron_left),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _startMonth++;
                        if (_startMonth > 12) {
                          _startMonth = 1;
                          _startYear++;
                        }
                      });
                    },
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Monthly amount preview
            Card(
              color: context.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Monthly Payment:'),
                    Text(
                      '\u20B1 ${_monthlyAmount.toStringAsFixed(2)}',
                      style: context.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            FilledButton(
              onPressed: _isLoading ? null : _create,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child:
                          CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Add Installment'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await ref
          .read(installmentsProvider.notifier)
          .createInstallment({
        'accountId': _selectedAccountId,
        'description': _descriptionController.text.trim(),
        'totalAmount': double.parse(_totalAmountController.text),
        'totalMonths': int.parse(_monthsController.text),
        'startMonth': _startMonthString,
      });
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) context.showSnackBar('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
