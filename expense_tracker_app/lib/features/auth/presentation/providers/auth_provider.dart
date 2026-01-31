import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../shared/models/user_model.dart';

final authStateProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<UserModel?>>((ref) {
  return AuthNotifier(ref.read(apiClientProvider));
});

class AuthNotifier extends StateNotifier<AsyncValue<UserModel?>> {
  final ApiClient _apiClient;

  AuthNotifier(this._apiClient) : super(const AsyncValue.data(null)) {
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final token = await _apiClient.getAccessToken();
    if (token != null) {
      try {
        final response = await _apiClient.get(ApiConstants.me);
        if (response['success'] == true) {
          state = AsyncValue.data(
            UserModel.fromJson(response['data'] as Map<String, dynamic>),
          );
        }
      } catch (_) {
        state = const AsyncValue.data(null);
      }
    }
  }

  Future<void> loginWithEmail(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final response = await _apiClient.post(
        ApiConstants.login,
        data: {'email': email, 'password': password},
      );

      final data = response['data'] as Map<String, dynamic>;
      await _apiClient.saveTokens(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
        userId: (data['user'] as Map<String, dynamic>)['id'] as String,
      );

      state = AsyncValue.data(
        UserModel.fromJson(data['user'] as Map<String, dynamic>),
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> registerWithEmail(
    String email,
    String password, {
    String? displayName,
  }) async {
    state = const AsyncValue.loading();
    try {
      final response = await _apiClient.post(
        ApiConstants.register,
        data: {
          'email': email,
          'password': password,
          if (displayName != null) 'displayName': displayName,
        },
      );

      final data = response['data'] as Map<String, dynamic>;
      await _apiClient.saveTokens(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
        userId: (data['user'] as Map<String, dynamic>)['id'] as String,
      );

      state = AsyncValue.data(
        UserModel.fromJson(data['user'] as Map<String, dynamic>),
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> loginWithGoogle(String idToken) async {
    state = const AsyncValue.loading();
    try {
      final response = await _apiClient.post(
        ApiConstants.googleAuth,
        data: {'idToken': idToken},
      );

      final data = response['data'] as Map<String, dynamic>;
      await _apiClient.saveTokens(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
        userId: (data['user'] as Map<String, dynamic>)['id'] as String,
      );

      state = AsyncValue.data(
        UserModel.fromJson(data['user'] as Map<String, dynamic>),
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateProfile({String? displayName, String? defaultCurrency}) async {
    try {
      final response = await _apiClient.patch(
        ApiConstants.me,
        data: {
          if (displayName != null) 'displayName': displayName,
          if (defaultCurrency != null) 'defaultCurrency': defaultCurrency,
        },
      );

      if (response['success'] == true) {
        state = AsyncValue.data(
          UserModel.fromJson(response['data'] as Map<String, dynamic>),
        );
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> logout() async {
    try {
      await _apiClient.post(ApiConstants.logout);
    } catch (_) {}
    await _apiClient.clearTokens();
    state = const AsyncValue.data(null);
  }

  Future<void> deleteAccount() async {
    await _apiClient.delete(ApiConstants.me);
    await _apiClient.clearTokens();
    state = const AsyncValue.data(null);
  }
}
