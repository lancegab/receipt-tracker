import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../shared/models/account_model.dart';

final accountsProvider =
    StateNotifierProvider<AccountsNotifier, AsyncValue<List<AccountModel>>>(
        (ref) {
  return AccountsNotifier(ref.read(apiClientProvider));
});

final totalBalanceProvider = Provider<double>((ref) {
  final accounts = ref.watch(accountsProvider);
  return accounts.maybeWhen(
    data: (list) => list
        .where((a) => a.type != 'credit_card' && !a.isArchived)
        .fold(0.0, (sum, a) => sum + a.balance),
    orElse: () => 0.0,
  );
});

final totalCreditPayableProvider = Provider<double>((ref) {
  final accounts = ref.watch(accountsProvider);
  return accounts.maybeWhen(
    data: (list) => list
        .where((a) => a.type == 'credit_card' && !a.isArchived)
        .fold(0.0, (sum, a) => sum + a.balance.abs()),
    orElse: () => 0.0,
  );
});

class AccountsNotifier extends StateNotifier<AsyncValue<List<AccountModel>>> {
  final ApiClient _apiClient;

  AccountsNotifier(this._apiClient) : super(const AsyncValue.loading()) {
    loadAccounts();
  }

  Future<void> loadAccounts() async {
    state = const AsyncValue.loading();
    try {
      final response = await _apiClient.get(ApiConstants.accounts);
      final list = (response['data'] as List)
          .map((e) => AccountModel.fromJson(e as Map<String, dynamic>))
          .toList();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createAccount(Map<String, dynamic> data) async {
    final response = await _apiClient.post(ApiConstants.accounts, data: data);
    if (response['success'] == true) {
      await loadAccounts();
    }
  }

  Future<void> updateAccount(String id, Map<String, dynamic> data) async {
    final response =
        await _apiClient.patch('${ApiConstants.accounts}/$id', data: data);
    if (response['success'] == true) {
      await loadAccounts();
    }
  }

  Future<void> archiveAccount(String id) async {
    await _apiClient.delete('${ApiConstants.accounts}/$id');
    await loadAccounts();
  }

  Future<void> recalculateBalances() async {
    await _apiClient.post(ApiConstants.recalculateBalances);
    await loadAccounts();
  }
}
