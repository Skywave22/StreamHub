import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers.dart';
import 'core/storage/settings_store.dart';
import 'ui/router/app_router.dart';
import 'ui/theme/app_theme.dart';

class StreamHubApp extends ConsumerWidget {
  const StreamHubApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsStoreProvider);
    final router = ref.watch(routerProvider);

    final themeMode = switch (settings.themePreference) {
      ThemePreference.system => ThemeMode.system,
      ThemePreference.dark => ThemeMode.dark,
      ThemePreference.light => ThemeMode.light,
    };

    return MaterialApp.router(
      title: 'StreamHub',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(settings.accentColor, settings.density),
      darkTheme: AppTheme.dark(settings.accentColor, settings.density),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
