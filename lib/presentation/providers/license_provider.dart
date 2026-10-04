import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/security/license_service.dart';

class LicenseState {
  final String hwid;
  final bool isUnlocked;
  final bool isLoading;
  final String? expiryDateStr;
  final String errorMessage;

  const LicenseState({
    this.hwid = '',
    this.isUnlocked = false,
    this.isLoading = true,
    this.expiryDateStr,
    this.errorMessage = '',
  });

  LicenseState copyWith({
    String? hwid,
    bool? isUnlocked,
    bool? isLoading,
    String? expiryDateStr,
    String? errorMessage,
  }) {
    return LicenseState(
      hwid: hwid ?? this.hwid,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      isLoading: isLoading ?? this.isLoading,
      expiryDateStr: expiryDateStr ?? this.expiryDateStr,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

Future<void> _safeInit(Future<void> Function() initFn, {required LicenseState Function() fallback}) async {
  if (kIsWeb) {
    try {
      await initFn().timeout(const Duration(seconds: 2));
    } catch (e, stack) {
      print('LicenseProvider Web Timeout/Error: $e');
    }
  } else {
    try {
      await initFn();
    } catch (e, stack) {
      print('LicenseProvider Error: $e');
    }
  }
}

class LicenseNotifier extends StateNotifier<LicenseState> {
  LicenseNotifier() : super(const LicenseState()) {
    _safeInit(
      () async {
        state = state.copyWith(isLoading: true);
        final hwid = await LicenseService.getHWID();
        final storedKey = await LicenseService.getStoredLicense();

        if (storedKey != null && storedKey.isNotEmpty) {
          final result = await LicenseService.validateLicense(storedKey);
          if (result.isValid) {
            state = LicenseState(
              hwid: hwid,
              isUnlocked: true,
              isLoading: false,
              expiryDateStr: result.expiryDateStr,
            );
            return;
          }
        }

        state = LicenseState(
          hwid: hwid,
          isUnlocked: false,
          isLoading: false,
        );
      },
      fallback: () => state.copyWith(isLoading: false, isUnlocked: false),
    );
  }

  Future<bool> activateKey(String key) async {
    state = state.copyWith(isLoading: true, errorMessage: '');
    final result = await LicenseService.validateLicense(key);

    if (result.isValid) {
      await LicenseService.saveStoredLicense(key);
      state = state.copyWith(
        isUnlocked: true,
        isLoading: false,
        expiryDateStr: result.expiryDateStr,
        errorMessage: '',
      );
      return true;
    } else {
      state = state.copyWith(
        isUnlocked: false,
        isLoading: false,
        errorMessage: result.errorMessage,
      );
      return false;
    }
  }
}

final licenseProvider = StateNotifierProvider<LicenseNotifier, LicenseState>((ref) {
  return LicenseNotifier();
});
