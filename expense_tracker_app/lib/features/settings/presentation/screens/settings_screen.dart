import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/auth/presentation/providers/biometric_provider.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final user = authState.valueOrNull;
    final biometric = ref.watch(biometricProvider);

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
          Builder(builder: (context) {
            final code = user?.defaultCurrency ?? 'PHP';
            final currency = CurrencyFormatter.getCurrency(code);
            return ListTile(
              leading: const Icon(Icons.attach_money),
              title: const Text('Default Currency'),
              subtitle: Text(currency != null
                  ? '${currency.flag} $code - ${currency.name}'
                  : code),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                _showCurrencyPicker(context, ref, code);
              },
            );
          }),
          // Categories
          ListTile(
            leading: const Icon(Icons.category),
            title: const Text('Categories'),
            subtitle: const Text('Manage expense and income categories'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/categories'),
          ),
          // Recurring Transactions
          ListTile(
            leading: const Icon(Icons.repeat),
            title: const Text('Recurring Transactions'),
            subtitle: const Text('Manage recurring income and expenses'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/recurring'),
          ),
          const Divider(),
          // Biometric lock
          if (biometric.isAvailable)
            SwitchListTile(
              secondary: const Icon(Icons.fingerprint),
              title: const Text('Biometric Lock'),
              subtitle: const Text('Require authentication on app resume'),
              value: biometric.isEnabled,
              onChanged: (value) {
                ref.read(biometricProvider.notifier).setEnabled(value);
              },
            ),
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
              child: Text('Default Currency',
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
                    leading:
                        Text(c.flag, style: const TextStyle(fontSize: 24)),
                    title: Text(c.code,
                        style:
                            const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(c.name),
                    trailing: isSelected
                        ? Icon(Icons.check,
                            color: Theme.of(context).colorScheme.primary)
                        : Text(c.symbol,
                            style: Theme.of(context).textTheme.bodyLarge),
                    onTap: () {
                      ref.read(authStateProvider.notifier).updateProfile(
                            defaultCurrency: c.code,
                          );
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
