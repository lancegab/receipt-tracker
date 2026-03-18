import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../shared/models/budget_group_model.dart';
import '../providers/budget_groups_provider.dart';
import '../providers/budget_provider.dart';

class BudgetGroupDetailScreen extends ConsumerStatefulWidget {
  final String groupId;

  const BudgetGroupDetailScreen({super.key, required this.groupId});

  @override
  ConsumerState<BudgetGroupDetailScreen> createState() =>
      _BudgetGroupDetailScreenState();
}

class _BudgetGroupDetailScreenState
    extends ConsumerState<BudgetGroupDetailScreen> {
  BudgetGroupModel? _group;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGroup();
  }

  Future<void> _loadGroup() async {
    setState(() => _isLoading = true);
    try {
      final group = await ref
          .read(budgetGroupsProvider.notifier)
          .getGroupDetail(widget.groupId);
      setState(() {
        _group = group;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) context.showSnackBar('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Group')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final group = _group;
    if (group == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Group')),
        body: const Center(child: Text('Group not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(group.name),
        actions: [
          if (group.isOwner)
            PopupMenuButton<String>(
              onSelected: (action) =>
                  _handleAction(action),
              itemBuilder: (context) => [
                const PopupMenuItem(
                    value: 'rename',
                    child: Text('Rename Group')),
                const PopupMenuItem(
                    value: 'description',
                    child: Text('Edit Description')),
                const PopupMenuItem(
                    value: 'invite',
                    child: Text('Invite Member')),
                const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete Group')),
              ],
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadGroup,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (group.description != null) ...[
              Text(group.description!,
                  style: context.textTheme.bodyMedium),
              const SizedBox(height: 16),
            ],

            // Members
            Text('Members',
                style: context.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (group.members != null)
              ...group.members!.map((member) => Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          (member.displayName ?? member.email ?? '?')
                              .substring(0, 1)
                              .toUpperCase(),
                        ),
                      ),
                      title: Text(member.displayName ??
                          member.email ??
                          'Unknown'),
                      subtitle: Text(member.role),
                      trailing: group.isOwner &&
                              !member.isOwner
                          ? IconButton(
                              icon: Icon(Icons.remove_circle,
                                  color:
                                      context.colorScheme.error),
                              onPressed: () =>
                                  _removeMember(member),
                            )
                          : null,
                    ),
                  )),

            const SizedBox(height: 24),

            // Shared budgets for this group
            Text('Shared Budgets',
                style: context.textTheme.titleMedium),
            const SizedBox(height: 8),
            _GroupBudgetsList(groupId: widget.groupId),
          ],
        ),
      ),
    );
  }

  void _handleAction(String action) async {
    switch (action) {
      case 'rename':
        _showEditFieldDialog('Rename Group', 'Group Name', _group?.name ?? '',
            (value) async {
          await ref
              .read(budgetGroupsProvider.notifier)
              .updateGroup(widget.groupId, {'name': value});
          _loadGroup();
        });
        break;
      case 'description':
        _showEditFieldDialog(
            'Edit Description', 'Description', _group?.description ?? '',
            (value) async {
          await ref
              .read(budgetGroupsProvider.notifier)
              .updateGroup(widget.groupId, {'description': value});
          _loadGroup();
        });
        break;
      case 'invite':
        _showInviteDialog();
        break;
      case 'delete':
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Group'),
            content: const Text(
                'This will delete the group and all shared budgets. Continue?'),
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
        if (confirm == true) {
          try {
            await ref
                .read(budgetGroupsProvider.notifier)
                .deleteGroup(widget.groupId);
            if (mounted) context.pop();
          } catch (e) {
            if (mounted) context.showSnackBar('Error: $e');
          }
        }
        break;
    }
  }

  void _showEditFieldDialog(String title, String label, String currentValue,
      Future<void> Function(String) onSave) {
    final controller = TextEditingController(text: currentValue);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: label),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              try {
                await onSave(controller.text.trim());
              } catch (e) {
                if (mounted) context.showSnackBar('Error: $e');
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showInviteDialog() {
    final emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Invite Member'),
        content: TextField(
          controller: emailController,
          decoration:
              const InputDecoration(labelText: 'Email Address'),
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (emailController.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              try {
                await ref
                    .read(budgetGroupsProvider.notifier)
                    .inviteMember(widget.groupId,
                        emailController.text.trim());
                if (mounted) {
                  context.showSnackBar('Invitation sent');
                }
              } catch (e) {
                if (mounted) {
                  context.showSnackBar('Error: $e');
                }
              }
            },
            child: const Text('Send Invite'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeMember(GroupMemberModel member) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text(
            'Remove ${member.displayName ?? member.email} from the group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref
            .read(budgetGroupsProvider.notifier)
            .removeMember(widget.groupId, member.id);
        _loadGroup();
      } catch (e) {
        if (mounted) context.showSnackBar('Error: $e');
      }
    }
  }
}

class _GroupBudgetsList extends ConsumerWidget {
  final String groupId;

  const _GroupBudgetsList({required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgets = ref.watch(budgetsProvider);

    return budgets.when(
      loading: () =>
          const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error: $e'),
      data: (list) {
        final groupBudgets =
            list.where((b) => b.groupId == groupId).toList();
        if (groupBudgets.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No shared budgets yet'),
            ),
          );
        }
        return Column(
          children: groupBudgets
              .map((b) => Card(
                    child: ListTile(
                      title: Text(b.name),
                      subtitle: Text(b.month),
                      trailing:
                          const Icon(Icons.chevron_right),
                      onTap: () =>
                          context.push('/budget/${b.id}'),
                    ),
                  ))
              .toList(),
        );
      },
    );
  }
}
