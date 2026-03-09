import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../shared/models/recurring_transaction_model.dart';

final recurringProvider = StateNotifierProvider<RecurringNotifier,
    AsyncValue<List<RecurringTransactionModel>>>((ref) {
  return RecurringNotifier(ref.read(apiClientProvider));
});

class RecurringNotifier
    extends StateNotifier<AsyncValue<List<RecurringTransactionModel>>> {
  final ApiClient _apiClient;

  RecurringNotifier(this._apiClient) : super(const AsyncValue.loading()) {
    loadRecurring();
  }

  Future<void> loadRecurring() async {
    state = const AsyncValue.loading();
    try {
      final response = await _apiClient.get(ApiConstants.recurring);
      final list = (response['data'] as List)
          .map((e) =>
              RecurringTransactionModel.fromJson(e as Map<String, dynamic>))
          .toList();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createRecurring(Map<String, dynamic> data) async {
    await _apiClient.post(ApiConstants.recurring, data: data);
    await loadRecurring();
  }

  Future<void> updateRecurring(String id, Map<String, dynamic> data) async {
    await _apiClient.patch('${ApiConstants.recurring}/$id', data: data);
    await loadRecurring();
  }

  Future<void> deleteRecurring(String id) async {
    await _apiClient.delete('${ApiConstants.recurring}/$id');
    await loadRecurring();
  }

  Future<void> processRecurring() async {
    await _apiClient.post('${ApiConstants.recurring}/process');
    await loadRecurring();
  }
}
