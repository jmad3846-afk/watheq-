import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/constants/app_colors.dart';
import 'presentation/providers/app_settings_provider.dart';
import 'presentation/providers/license_provider.dart';
import 'presentation/screens/setup/currency_setup_screen.dart';
import 'presentation/screens/lock/lock_screen.dart';
import 'presentation/screens/shell/main_shell_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: WathaqApp(),
    ),
  );
}

class WathaqApp extends ConsumerWidget {
  const WathaqApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final license = ref.watch(licenseProvider);

    return MaterialApp(
      title: 'وثق للمحاسبة والمخازن',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar', 'SA'),
      supportedLocales: const [
        Locale('ar', 'SA'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: GoogleFonts.tajawal().fontFamily,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.accent,
          background: AppColors.background,
          surface: AppColors.surface,
        ),
        scaffoldBackgroundColor: AppColors.background,
        textTheme: GoogleFonts.tajawalTextTheme(Theme.of(context).textTheme),
      ),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      home: _buildHome(settings, license),
    );
  }

  Widget _buildHome(AppSettingsState settings, LicenseState license) {
    if (!settings.isLoaded || license.isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.primaryDark,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.accent),
              SizedBox(height: 16),
              Text(
                'جاري تشغيل نظام وثق...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    // Step 1: Force currency selection on first launch
    if (settings.isFirstLaunch) {
      return const CurrencySetupScreen();
    }

    // Step 2: Enforce License Lock if expired or invalid key
    if (!license.isUnlocked) {
      return const LockScreen();
    }

    // Step 3: Main App Shell
    return const MainShellScreen();
  }
}
