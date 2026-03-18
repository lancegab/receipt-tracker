import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../shared/models/budget_group_model.dart';

final budgetGroupsProvider = StateNotifierProvider<BudgetGroupsNotifier,
    AsyncValue<List<BudgetGroupModel>>>((ref) {
  return BudgetGroupsNotifier(ref.read(apiClientProvider));
});

class BudgetGroupsNotifier
    extends StateNotifier<AsyncValue<List<BudgetGroupModel>>> {
  final ApiClient _apiClient;

  BudgetGroupsNotifier(this._apiClient)
      : super(const AsyncValue.loading()) {
    loadGroups();
  }

  Future<void> loadGroups() async {
    state = const AsyncValue.loading();
    try {
      final response = await _apiClient.get(ApiConstants.budgetGroups);
      final list = (response['data'] as List)
          .map((e) =>
              BudgetGroupModel.fromJson(e as Map<String, dynamic>))
          .toList();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<BudgetGroupModel?> createGroup(
      Map<String, dynamic> data) async {
    final response =
        await _apiClient.post(ApiConstants.budgetGroups, data: data);
    if (response['success'] == true) {
      await loadGroups();
      return BudgetGroupModel.fromJson(
          response['data'] as Map<String, dynamic>);
    }
    return null;
  }

  Future<BudgetGroupModel?> getGroupDetail(String groupId) async {
    final response =
        await _apiClient.get('${ApiConstants.budgetGroups}/$groupId');
    if (response['success'] == true) {
      return BudgetGroupModel.fromJson(
          response['data'] as Map<String, dynamic>);
    }
    return null;
  }

  Future<void> updateGroup(
      String id, Map<String, dynamic> data) async {
    await _apiClient.patch('${ApiConstants.budgetGroups}/$id',
        data: data);
    await loadGroups();
  }

  Future<void> deleteGroup(String id) async {
    await _apiClient.delete('${ApiConstants.budgetGroups}/$id');
    await loadGroups();
  }

  Future<void> inviteMember(String groupId, String email) async {
    await _apiClient.post(
        '${ApiConstants.budgetGroups}/$groupId/invite',
        data: {'email': email});
  }

  Future<void> removeMember(String groupId, String memberId) async {
    await _apiClient.post(
        '${ApiConstants.budgetGroups}/$groupId/members/$memberId/remove');
  }
}

final pendingInvitationsProvider =
    FutureProvider<List<GroupInvitationModel>>((ref) async {
  final apiClient = ref.read(apiClientProvider);
  final response =
      await apiClient.get('${ApiConstants.budgetGroups}/invitations');
  return (response['data'] as List)
      .map((e) =>
          GroupInvitationModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

class InvitationService {
  final ApiClient _apiClient;

  InvitationService(this._apiClient);

  Future<void> acceptInvitation(String inviteId) async {
    await _apiClient.post(
        '${ApiConstants.budgetGroups}/invitations/$inviteId/accept');
  }

  Future<void> declineInvitation(String inviteId) async {
    await _apiClient.post(
        '${ApiConstants.budgetGroups}/invitations/$inviteId/decline');
  }
}

final invitationServiceProvider = Provider<InvitationService>((ref) {
  return InvitationService(ref.read(apiClientProvider));
});
