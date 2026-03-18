import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../providers/budget_provider.dart';
import '../providers/budget_groups_provider.dart';

class CreateBudgetScreen extends ConsumerStatefulWidget {
  const CreateBudgetScreen({super.key});

  @override
  ConsumerState<CreateBudgetScreen> createState() =>
      _CreateBudgetScreenState();
}

class _CreateBudgetScreenState
    extends ConsumerState<CreateBudgetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  late int _year;
  late int _month;
  String? _selectedGroupId;
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
    _year = now.year;
    _month = now.month;
    _nameController.text = '${_monthNames[_month]} $_year Budget';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String get _monthString =>
      '$_year-${_month.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(budgetGroupsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Create Budget')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration:
                  const InputDecoration(labelText: 'Budget Name'),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: 16),

            // Month picker
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Month'),
              subtitle:
                  Text('${_monthNames[_month]} $_year'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _month--;
                        if (_month < 1) {
                          _month = 12;
                          _year--;
                        }
                      });
                    },
                    icon: const Icon(Icons.chevron_left),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _month++;
                        if (_month > 12) {
                          _month = 1;
                          _year++;
                        }
                      });
                    },
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Group selector
            groups.maybeWhen(
              data: (groupList) {
                if (groupList.isEmpty) return const SizedBox.shrink();
                return DropdownButtonFormField<String?>(
                  value: _selectedGroupId,
                  decoration: const InputDecoration(
                    labelText: 'Budget Group (optional)',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Personal Budget'),
                    ),
                    ...groupList.map((g) => DropdownMenuItem(
                          value: g.id,
                          child: Text(g.name),
                        )),
                  ],
                  onChanged: (v) =>
                      setState(() => _selectedGroupId = v),
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
            const SizedBox(height: 32),

            FilledButton(
              onPressed: _isLoading ? null : _createBudget,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create Budget'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createBudget() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final budget =
          await ref.read(budgetsProvider.notifier).createBudget({
        'name': _nameController.text.trim(),
        'month': _monthString,
        'currency': 'PHP',
        if (_selectedGroupId != null) 'groupId': _selectedGroupId,
      });
      if (budget != null && mounted) {
        context.pop();
        context.push('/budget/${budget.id}');
      }
    } catch (e) {
      if (mounted) context.showSnackBar('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
