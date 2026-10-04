import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';

class AppSettingsState {
  final String currency;
  final String printerHeader;
  final bool isFirstLaunch;
  final bool isLoaded;

  const AppSettingsState({
    this.currency = AppConstants.defaultCurrency,
    this.printerHeader = AppConstants.defaultPrinterHeader,
    this.isFirstLaunch = false,
    this.isLoaded = false,
  });

  AppSettingsState copyWith({
    String? currency,
    String? printerHeader,
    bool? isFirstLaunch,
    bool? isLoaded,
  }) {
    return AppSettingsState(
      currency: currency ?? this.currency,
      printerHeader: printerHeader ?? this.printerHeader,
      isFirstLaunch: isFirstLaunch ?? this.isFirstLaunch,
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }
}

Future<void> _safeInit(Future<void> Function() initFn, {required AppSettingsState Function() fallback}) async {
  if (kIsWeb) {
    try {
      await initFn().timeout(const Duration(seconds: 2));
    } catch (e, stack) {
      print('AppSettingsProvider Web Timeout/Error: $e');
    }
  } else {
    try {
      await initFn();
    } catch (e, stack) {
      print('AppSettingsProvider Error: $e');
    }
  }
}

class AppSettingsNotifier extends StateNotifier<AppSettingsState> {
  AppSettingsNotifier() : super(const AppSettingsState()) {
    _safeInit(
      () async {
        final prefs = await SharedPreferences.getInstance();
        final storedCurrency = prefs.getString(AppConstants.prefCurrency);
        final storedHeader = prefs.getString(AppConstants.prefPrinterHeader) ?? AppConstants.defaultPrinterHeader;
        final firstLaunch = prefs.getBool(AppConstants.prefFirstLaunch) ?? true;

        state = state.copyWith(
          currency: storedCurrency ?? AppConstants.defaultCurrency,
          printerHeader: storedHeader,
          isFirstLaunch: storedCurrency == null || firstLaunch,
          isLoaded: true,
        );
      },
      fallback: () => state.copyWith(isLoaded: true),
    );
  }

  Future<void> setCurrency(String selectedCurrency) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefCurrency, selectedCurrency);
    await prefs.setBool(AppConstants.prefFirstLaunch, false);
    state = state.copyWith(
      currency: selectedCurrency,
      isFirstLaunch: false,
    );
  }

  Future<void> setPrinterHeader(String newHeader) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefPrinterHeader, newHeader);
    state = state.copyWith(printerHeader: newHeader);
  }
}

final appSettingsProvider = StateNotifierProvider<AppSettingsNotifier, AppSettingsState>((ref) {
  return AppSettingsNotifier();
});
