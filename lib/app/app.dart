import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_app/app/router.dart';
import 'package:inventory_app/app/theme/app_theme.dart';

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

    return MaterialApp.router(
      title: 'صفو لإدارة الأعمال',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: appRouter,
    );
  }
}
