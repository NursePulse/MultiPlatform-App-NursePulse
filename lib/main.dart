import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/config/app_config.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/localization/locale_notifier.dart';
import 'core/localization/app_strings.dart';
import 'features/iam/application/auth_notifier.dart';
import 'features/iam/domain/user.dart';

void main() {
  runApp(const ProviderScope(child: NursePulseApp()));
}

class NursePulseApp extends ConsumerWidget {
  const NursePulseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(
        role: ViewModeX.fromRole(
          ref.watch(authNotifierProvider).user?.primaryRole ?? '',
        ),
      ),
      locale: ref.watch(localeProvider),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      // Approved light UI with evergreen headers and clinical status colors.
      themeMode: ThemeMode.light,
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.white,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        child: AppLanguage(locale: ref.watch(localeProvider), child: child!),
      ),
      routerConfig: router,
    );
  }
}
