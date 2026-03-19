import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../shared/models/budget_model.dart';
import '../../../../shared/models/budget_item_model.dart';

final selectedMonthProvider = StateProvider<String>((ref) {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}';
});

/// Budget items for a given month — used by the transaction form picker
final budgetItemsForMonthProvider =
    FutureProvider.family<List<BudgetItemSummary>, String>((ref, month) async {
  final apiClient = ref.read(apiClientProvider);
  final response = await apiClient.get(
    ApiConstants.budgetItemsForMonth,
    queryParameters: {'month': month},
  );
  return (response['data'] as List)
      .map((e) => BudgetItemSummary.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Lightweight model for the transaction budget item picker
class BudgetItemSummary {
  final String id;
  final String name;
  final String budgetId;
  final String budgetName;

  const BudgetItemSummary({
    required this.id,
    required this.name,
    required this.budgetId,
    required this.budgetName,
  });

  factory BudgetItemSummary.fromJson(Map<String, dynamic> json) {
    return BudgetItemSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      budgetId: json['budgetId'] as String? ?? json['budget_id'] as String? ?? '',
      budgetName: json['budgetName'] as String? ?? json['budget_name'] as String? ?? '',
    );
  }
}

final budgetsProvider =
    StateNotifierProvider<BudgetsNotifier, AsyncValue<List<BudgetModel>>>(
        (ref) {
  return BudgetsNotifier(ref.read(apiClientProvider), ref);
});

class BudgetsNotifier extends StateNotifier<AsyncValue<List<BudgetModel>>> {
  final ApiClient _apiClient;
  final Ref _ref;

  BudgetsNotifier(this._apiClient, this._ref)
      : super(const AsyncValue.loading()) {
    loadBudgets();
  }

  Future<void> loadBudgets() async {
    state = const AsyncValue.loading();
    try {
      final month = _ref.read(selectedMonthProvider);
      final response = await _apiClient
          .get('${ApiConstants.budgets}?month=$month');
      final list = (response['data'] as List)
          .map((e) => BudgetModel.fromJson(e as Map<String, dynamic>))
          .toList();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<BudgetModel?> createBudget(Map<String, dynamic> data) async {
    final response =
        await _apiClient.post(ApiConstants.budgets, data: data);
    if (response['success'] == true) {
      await loadBudgets();
      return BudgetModel.fromJson(
          response['data'] as Map<String, dynamic>);
    }
    return null;
  }

  Future<void> updateBudget(String id, Map<String, dynamic> data) async {
    await _apiClient.patch('${ApiConstants.budgets}/$id', data: data);
    await loadBudgets();
  }

  Future<void> deleteBudget(String id) async {
    await _apiClient.delete('${ApiConstants.budgets}/$id');
    await loadBudgets();
  }

  Future<BudgetModel?> copyBudget(String id, String targetMonth) async {
    final response = await _apiClient.post(
      '${ApiConstants.budgets}/$id/copy',
      data: {'targetMonth': targetMonth},
    );
    if (response['success'] == true) {
      return BudgetModel.fromJson(
          response['data'] as Map<String, dynamic>);
    }
    return null;
  }
}

final budgetSummaryProvider =
    FutureProvider.family<BudgetSummaryModel, String>(
        (ref, budgetId) async {
  final apiClient = ref.read(apiClientProvider);
  final response =
      await apiClient.get('${ApiConstants.budgets}/$budgetId/summary');
  return BudgetSummaryModel.fromJson(
      response['data'] as Map<String, dynamic>);
});

// Budget item operations (not state-managed, just API calls)
class BudgetItemService {
  final ApiClient _apiClient;

  BudgetItemService(this._apiClient);

  Future<void> addItem(String budgetId, Map<String, dynamic> data) async {
    await _apiClient.post(
        '${ApiConstants.budgets}/$budgetId/items',
        data: data);
  }

  Future<void> updateItem(
      String budgetId, String itemId, Map<String, dynamic> data) async {
    await _apiClient.patch(
        '${ApiConstants.budgets}/$budgetId/items/$itemId',
        data: data);
  }

  Future<void> deleteItem(String budgetId, String itemId) async {
    await _apiClient
        .delete('${ApiConstants.budgets}/$budgetId/items/$itemId');
  }

  Future<Map<String, dynamic>> generateItems(
      String budgetId, Map<String, dynamic> data) async {
    final response = await _apiClient.post(
        '${ApiConstants.budgets}/$budgetId/items/generate',
        data: data);
    return response['data'] as Map<String, dynamic>;
  }

  Future<void> setWeeklyAdjustment(
      String budgetId, String itemId, int week,
      Map<String, dynamic> data) async {
    await _apiClient.patch(
        '${ApiConstants.budgets}/$budgetId/items/$itemId/weekly/$week',
        data: data);
  }
}

final budgetItemServiceProvider = Provider<BudgetItemService>((ref) {
  return BudgetItemService(ref.read(apiClientProvider));
});
