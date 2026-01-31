import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/categories_provider.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../shared/models/category_model.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showAddCategoryDialog(String type) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Category'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Category Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (nameController.text.trim().isNotEmpty) {
                await ref.read(categoriesProvider.notifier).createCategory({
                  'name': nameController.text.trim(),
                  'type': type,
                });
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(CategoryModel category) {
    final nameController = TextEditingController(text: category.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Category'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Category Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          if (!category.isSystem)
            TextButton(
              onPressed: () async {
                await ref
                    .read(categoriesProvider.notifier)
                    .deleteCategory(category.id);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          FilledButton(
            onPressed: () async {
              if (nameController.text.trim().isNotEmpty) {
                await ref
                    .read(categoriesProvider.notifier)
                    .updateCategory(category.id, {
                  'name': nameController.text.trim(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Expense'),
            Tab(text: 'Income'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddCategoryDialog(
            _tabController.index == 0 ? 'expense' : 'income',
          );
        },
        child: const Icon(Icons.add),
      ),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (categories) {
          return TabBarView(
            controller: _tabController,
            children: [
              _buildCategoryList(
                categories.where((c) => c.type == 'expense').toList(),
              ),
              _buildCategoryList(
                categories.where((c) => c.type == 'income').toList(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCategoryList(List<CategoryModel> categories) {
    if (categories.isEmpty) {
      return const Center(child: Text('No categories'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final cat = categories[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: cat.colorValue.withOpacity(0.2),
            child: Icon(cat.iconData, color: cat.colorValue, size: 20),
          ),
          title: Text(cat.name),
          subtitle: cat.isSystem ? const Text('System') : const Text('Custom'),
          trailing: cat.isSystem
              ? null
              : const Icon(Icons.chevron_right),
          onTap: cat.isSystem ? null : () => _showEditDialog(cat),
        );
      },
    );
  }
}
