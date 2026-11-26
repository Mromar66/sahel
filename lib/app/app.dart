import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:safwa/app/router.dart';
import 'package:safwa/app/theme/app_theme.dart';

class InventoryApp extends StatelessWidget {
  const InventoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Lock to portrait/landscape as needed for desktop
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppThemeController.mode,
      builder: (context, mode, _) => MaterialApp.router(
        title: 'Safwa',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: mode,
        routerConfig: appRouter,
        builder: (context, child) {
          final mediaQuery = MediaQuery.of(context);
          return MediaQuery(
            data: mediaQuery.copyWith(textScaler: const TextScaler.linear(1.2)),
            child: child ?? const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}
