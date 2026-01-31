import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/constants/app_constants.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final user = authState.valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // Profile section
          if (user != null)
            Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: context.colorScheme.primaryContainer,
                    child: Text(
                      (user.displayName ?? user.email)
                          .substring(0, 1)
                          .toUpperCase(),
                      style: context.textTheme.headlineMedium,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user.displayName ?? 'No name set',
                    style: context.textTheme.titleLarge,
                  ),
                  Text(
                    user.email,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          const Divider(),
          // Currency
          ListTile(
            leading: const Icon(Icons.attach_money),
            title: const Text('Default Currency'),
            subtitle: Text(user?.defaultCurrency ?? 'USD'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              _showCurrencyPicker(context, ref, user?.defaultCurrency ?? 'USD');
            },
          ),
          // Categories
          ListTile(
            leading: const Icon(Icons.category),
            title: const Text('Categories'),
            subtitle: const Text('Manage expense and income categories'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/categories'),
          ),
          const Divider(),
          // Display name
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Display Name'),
            subtitle: Text(user?.displayName ?? 'Not set'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showEditNameDialog(context, ref, user?.displayName),
          ),
          const Divider(),
          // About
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            subtitle: const Text('Version 1.0.0'),
          ),
          const Divider(),
          // Danger zone
          ListTile(
            leading: Icon(Icons.logout, color: context.colorScheme.error),
            title: Text('Sign Out',
                style: TextStyle(color: context.colorScheme.error)),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Sign Out'),
                  content: const Text('Are you sure you want to sign out?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Sign Out'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await ref.read(authStateProvider.notifier).logout();
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Delete Account',
                style: TextStyle(color: Colors.red)),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete Account'),
                  content: const Text(
                    'This will permanently delete your account and all data. This action cannot be undone.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(
                          backgroundColor: Colors.red),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await ref.read(authStateProvider.notifier).deleteAccount();
              }
            },
          ),
        ],
      ),
    );
  }

  void _showCurrencyPicker(
      BuildContext context, WidgetRef ref, String current) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => ListView(
        children: AppConstants.supportedCurrencies.map((currency) {
          return ListTile(
            title: Text(currency),
            trailing: currency == current
                ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                : null,
            onTap: () {
              ref.read(authStateProvider.notifier).updateProfile(
                    defaultCurrency: currency,
                  );
              Navigator.pop(ctx);
            },
          );
        }).toList(),
      ),
    );
  }

  void _showEditNameDialog(
      BuildContext context, WidgetRef ref, String? currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Display Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Display Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(authStateProvider.notifier).updateProfile(
                    displayName: controller.text.trim(),
                  );
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
