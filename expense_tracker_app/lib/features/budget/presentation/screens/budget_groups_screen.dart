import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../shared/models/budget_group_model.dart';
import '../providers/budget_groups_provider.dart';

class BudgetGroupsScreen extends ConsumerWidget {
  const BudgetGroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(budgetGroupsProvider);
    final invitations = ref.watch(pendingInvitationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Budget Groups')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Pending invitations
          invitations.maybeWhen(
            data: (list) {
              if (list.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pending Invitations',
                      style: context.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ...list.map((inv) => _InvitationCard(
                      invitation: inv)),
                  const SizedBox(height: 16),
                ],
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),

          // Groups
          Text('Your Groups',
              style: context.textTheme.titleMedium),
          const SizedBox(height: 8),

          groups.when(
            loading: () => const Center(
                child: CircularProgressIndicator()),
            error: (e, _) =>
                Center(child: Text('Error: $e')),
            data: (list) {
              if (list.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.group_outlined,
                            size: 48,
                            color: context.colorScheme.outline),
                        const SizedBox(height: 8),
                        const Text('No groups yet'),
                      ],
                    ),
                  ),
                );
              }
              return Column(
                children: list
                    .map((g) => Card(
                          child: ListTile(
                            leading: const Icon(Icons.group),
                            title: Text(g.name),
                            subtitle: Text(
                                g.isOwner ? 'Owner' : 'Member'),
                            trailing:
                                const Icon(Icons.chevron_right),
                            onTap: () =>
                                context.push('/groups/${g.id}'),
                          ),
                        ))
                    .toList(),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Group'),
        content: TextField(
          controller: nameController,
          decoration:
              const InputDecoration(labelText: 'Group Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              try {
                await ref
                    .read(budgetGroupsProvider.notifier)
                    .createGroup(
                        {'name': nameController.text.trim()});
              } catch (e) {
                if (context.mounted) {
                  context.showSnackBar('Error: $e');
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

class _InvitationCard extends ConsumerWidget {
  final GroupInvitationModel invitation;

  const _InvitationCard({required this.invitation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      color: context.colorScheme.primaryContainer,
      child: ListTile(
        leading: const Icon(Icons.mail),
        title: Text(invitation.groupName ?? 'Group'),
        subtitle: Text('From: ${invitation.invitedBy}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.check, color: const Color(0xFF2E7D32)),
              onPressed: () async {
                try {
                  await ref
                      .read(invitationServiceProvider)
                      .acceptInvitation(invitation.id);
                  ref.invalidate(pendingInvitationsProvider);
                  ref.read(budgetGroupsProvider.notifier)
                      .loadGroups();
                } catch (e) {
                  if (context.mounted) {
                    context.showSnackBar('Error: $e');
                  }
                }
              },
            ),
            IconButton(
              icon: Icon(Icons.close,
                  color: context.colorScheme.error),
              onPressed: () async {
                try {
                  await ref
                      .read(invitationServiceProvider)
                      .declineInvitation(invitation.id);
                  ref.invalidate(pendingInvitationsProvider);
                } catch (e) {
                  if (context.mounted) {
                    context.showSnackBar('Error: $e');
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
