import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BiometricState {
  final bool isAvailable;
  final bool isEnabled;
  final bool isLocked;

  const BiometricState({
    this.isAvailable = false,
    this.isEnabled = false,
    this.isLocked = false,
  });

  BiometricState copyWith({
    bool? isAvailable,
    bool? isEnabled,
    bool? isLocked,
  }) {
    return BiometricState(
      isAvailable: isAvailable ?? this.isAvailable,
      isEnabled: isEnabled ?? this.isEnabled,
      isLocked: isLocked ?? this.isLocked,
    );
  }
}

final biometricProvider =
    StateNotifierProvider<BiometricNotifier, BiometricState>((ref) {
  return BiometricNotifier();
});

class BiometricNotifier extends StateNotifier<BiometricState> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const _key = 'biometric_enabled';

  BiometricNotifier() : super(const BiometricState()) {
    _init();
  }

  Future<void> _init() async {
    final canCheck = await _localAuth.canCheckBiometrics;
    final isDeviceSupported = await _localAuth.isDeviceSupported();
    final isAvailable = canCheck && isDeviceSupported;

    final storedValue = await _storage.read(key: _key);
    final isEnabled = storedValue == 'true';

    state = BiometricState(
      isAvailable: isAvailable,
      isEnabled: isEnabled,
      isLocked: false,
    );
  }

  Future<void> setEnabled(bool enabled) async {
    if (enabled) {
      // Verify identity before enabling
      final authenticated = await authenticate();
      if (!authenticated) return;
    }

    await _storage.write(key: _key, value: enabled.toString());
    state = state.copyWith(isEnabled: enabled);
  }

  Future<bool> authenticate() async {
    try {
      final result = await _localAuth.authenticate(
        localizedReason: 'Authenticate to access Expense Tracker',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
      if (result) {
        state = state.copyWith(isLocked: false);
      }
      return result;
    } catch (_) {
      return false;
    }
  }

  void lock() {
    if (state.isEnabled) {
      state = state.copyWith(isLocked: true);
    }
  }

  void unlock() {
    state = state.copyWith(isLocked: false);
  }
}
