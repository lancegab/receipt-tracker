import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../shared/models/installment_model.dart';

final installmentsProvider = StateNotifierProvider<InstallmentsNotifier,
    AsyncValue<List<InstallmentModel>>>((ref) {
  return InstallmentsNotifier(ref.read(apiClientProvider));
});

class InstallmentsNotifier
    extends StateNotifier<AsyncValue<List<InstallmentModel>>> {
  final ApiClient _apiClient;

  InstallmentsNotifier(this._apiClient)
      : super(const AsyncValue.loading()) {
    loadInstallments();
  }

  Future<void> loadInstallments({String? accountId, bool? active}) async {
    state = const AsyncValue.loading();
    try {
      final params = <String, String>{};
      if (accountId != null) params['accountId'] = accountId;
      if (active != null) params['active'] = active.toString();

      final query = params.entries
          .map((e) => '${e.key}=${e.value}')
          .join('&');
      final url = query.isEmpty
          ? ApiConstants.installments
          : '${ApiConstants.installments}?$query';

      final response = await _apiClient.get(url);
      final list = (response['data'] as List)
          .map((e) =>
              InstallmentModel.fromJson(e as Map<String, dynamic>))
          .toList();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createInstallment(Map<String, dynamic> data) async {
    await _apiClient.post(ApiConstants.installments, data: data);
    await loadInstallments();
  }

  Future<void> updateInstallment(
      String id, Map<String, dynamic> data) async {
    await _apiClient.patch('${ApiConstants.installments}/$id',
        data: data);
    await loadInstallments();
  }

  Future<void> deactivateInstallment(String id) async {
    await _apiClient.delete('${ApiConstants.installments}/$id');
    await loadInstallments();
  }
}
