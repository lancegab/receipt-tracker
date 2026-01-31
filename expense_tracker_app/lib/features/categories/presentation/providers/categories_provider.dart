import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../shared/models/category_model.dart';

final categoriesProvider = StateNotifierProvider<CategoriesNotifier,
    AsyncValue<List<CategoryModel>>>((ref) {
  return CategoriesNotifier(ref.read(apiClientProvider));
});

class CategoriesNotifier
    extends StateNotifier<AsyncValue<List<CategoryModel>>> {
  final ApiClient _apiClient;

  CategoriesNotifier(this._apiClient) : super(const AsyncValue.loading()) {
    loadCategories();
  }

  Future<void> loadCategories() async {
    state = const AsyncValue.loading();
    try {
      final response = await _apiClient.get(ApiConstants.categories);
      final list = (response['data'] as List)
          .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
          .toList();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createCategory(Map<String, dynamic> data) async {
    await _apiClient.post(ApiConstants.categories, data: data);
    await loadCategories();
  }

  Future<void> updateCategory(String id, Map<String, dynamic> data) async {
    await _apiClient.patch('${ApiConstants.categories}/$id', data: data);
    await loadCategories();
  }

  Future<void> deleteCategory(String id) async {
    await _apiClient.delete('${ApiConstants.categories}/$id');
    await loadCategories();
  }
}
