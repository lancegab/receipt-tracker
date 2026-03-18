import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/accounts_provider.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';

class AddAccountScreen extends ConsumerStatefulWidget {
  const AddAccountScreen({super.key});

  @override
  ConsumerState<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends ConsumerState<AddAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController(text: '0');
  final _creditLimitController = TextEditingController();
  final _closeController = TextEditingController();
  final _dueController = TextEditingController();
  String _type = 'bank';
  String? _currency;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    _creditLimitController.dispose();
    _closeController.dispose();
    _dueController.dispose();
    super.dispose();
  }

  String get _effectiveCurrency {
    if (_currency != null) return _currency!;
    final user = ref.read(authStateProvider).valueOrNull;
    return user?.defaultCurrency ?? 'PHP';
  }

  String get _currencySymbol => CurrencyFormatter.getSymbol(_effectiveCurrency);

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final data = {
        'name': _nameController.text.trim(),
        'type': _type,
        'currency': _effectiveCurrency,
        'balance': double.tryParse(_balanceController.text) ?? 0,
      };

      if (_type == 'credit_card') {
        if (_creditLimitController.text.isNotEmpty) {
          data['creditLimit'] =
              double.tryParse(_creditLimitController.text) ?? 0;
        }
        if (_closeController.text.isNotEmpty) {
          data['statementCloseDay'] =
              int.tryParse(_closeController.text) ?? 1;
        }
        if (_dueController.text.isNotEmpty) {
          data['paymentDueDay'] = int.tryParse(_dueController.text) ?? 1;
        }
      }

      await ref.read(accountsProvider.notifier).createAccount(data);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) context.showSnackBar(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showCurrencyPicker() {
    final current = _effectiveCurrency;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Select Currency',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: CurrencyFormatter.currencies.length,
                itemBuilder: (context, index) {
                  final c = CurrencyFormatter.currencies[index];
                  final isSelected = c.code == current;
                  return ListTile(
                    leading: Text(c.flag, style: const TextStyle(fontSize: 24)),
                    title: Text(c.code,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(c.name),
                    trailing: isSelected
                        ? Icon(Icons.check,
                            color: Theme.of(context).colorScheme.primary)
                        : Text(c.symbol,
                            style: Theme.of(context).textTheme.bodyLarge),
                    onTap: () {
                      setState(() => _currency = c.code);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyData = CurrencyFormatter.getCurrency(_effectiveCurrency);

    return Scaffold(
      appBar: AppBar(title: const Text('Add Account')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Account Name'),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _type,
                decoration: const InputDecoration(labelText: 'Account Type'),
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('Cash')),
                  DropdownMenuItem(
                      value: 'bank', child: Text('Bank/Checking')),
                  DropdownMenuItem(value: 'savings', child: Text('Savings')),
                  DropdownMenuItem(
                      value: 'wallet', child: Text('Digital Wallet')),
                  DropdownMenuItem(
                      value: 'credit_card', child: Text('Credit Card')),
                ],
                onChanged: (v) => setState(() => _type = v ?? 'bank'),
              ),
              const SizedBox(height: 16),
              // Currency picker
              InkWell(
                onTap: _showCurrencyPicker,
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Currency'),
                  child: Row(
                    children: [
                      if (currencyData != null) ...[
                        Text(currencyData.flag,
                            style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 8),
                      ],
                      Text(_effectiveCurrency,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (currencyData != null) ...[
                        const SizedBox(width: 8),
                        Text('- ${currencyData.name}',
                            style: Theme.of(context).textTheme.bodyMedium),
                      ],
                      const Spacer(),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _balanceController,
                decoration: InputDecoration(
                  labelText: 'Initial Balance',
                  prefixText: '$_currencySymbol ',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              if (_type == 'credit_card') ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _creditLimitController,
                  decoration: InputDecoration(
                    labelText: 'Credit Limit',
                    prefixText: '$_currencySymbol ',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _closeController,
                        decoration: const InputDecoration(
                          labelText: 'Statement Close Day',
                          hintText: '1-31',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _dueController,
                        decoration: const InputDecoration(
                          labelText: 'Payment Due Day',
                          hintText: '1-31',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _save,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create Account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
