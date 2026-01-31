import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../shared/models/transaction_model.dart';

final transactionsProvider = StateNotifierProvider<TransactionsNotifier,
    AsyncValue<List<TransactionModel>>>((ref) {
  return TransactionsNotifier(ref.read(apiClientProvider));
});

class TransactionsNotifier
    extends StateNotifier<AsyncValue<List<TransactionModel>>> {
  final ApiClient _apiClient;

  TransactionsNotifier(this._apiClient) : super(const AsyncValue.loading()) {
    loadTransactions();
  }

  Future<void> loadTransactions({
    String? accountId,
    String? categoryId,
    String? type,
    String? startDate,
    String? endDate,
    String? search,
    int page = 1,
    int limit = 50,
  }) async {
    state = const AsyncValue.loading();
    try {
      final params = <String, dynamic>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (accountId != null) params['accountId'] = accountId;
      if (categoryId != null) params['categoryId'] = categoryId;
      if (type != null) params['type'] = type;
      if (startDate != null) params['startDate'] = startDate;
      if (endDate != null) params['endDate'] = endDate;
      if (search != null) params['search'] = search;

      final response = await _apiClient.get(
        ApiConstants.transactions,
        queryParameters: params,
      );
      final list = (response['data'] as List)
          .map((e) => TransactionModel.fromJson(e as Map<String, dynamic>))
          .toList();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createTransaction(Map<String, dynamic> data) async {
    await _apiClient.post(ApiConstants.transactions, data: data);
    await loadTransactions();
  }

  Future<void> createBatchTransactions(List<Map<String, dynamic>> txns) async {
    await _apiClient.post(
      ApiConstants.batchTransactions,
      data: {'transactions': txns},
    );
    await loadTransactions();
  }

  Future<void> updateTransaction(String id, Map<String, dynamic> data) async {
    await _apiClient.patch('${ApiConstants.transactions}/$id', data: data);
    await loadTransactions();
  }

  Future<void> deleteTransaction(String id) async {
    await _apiClient.delete('${ApiConstants.transactions}/$id');
    await loadTransactions();
  }
}
