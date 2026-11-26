import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:safwa/app/shell/app_top_bar.dart';
import 'package:safwa/app/theme/app_theme.dart';

void main() {
  testWidgets('top navigation opens its menu before opening a page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              const Scaffold(body: AppTopBar(activeTab: AppTab.home)),
        ),
        GoRoute(
          path: '/sales',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('صفحة المبيعات'))),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('المبيعات'));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/');
    expect(find.text('فاتورة مبيعات'), findsOneWidget);

    await tester.tap(find.text('فاتورة مبيعات'));
    await tester.pumpAndSettle();

    expect(find.text('صفحة المبيعات'), findsOneWidget);
  });

  testWidgets('toolbar help, user and appearance controls are connected', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => AppThemeController.mode.value = ThemeMode.dark);
    AppThemeController.mode.value = ThemeMode.dark;

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              const Scaffold(body: AppTopBar(activeTab: AppTab.home)),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('المساعدة وأدوات البرنامج'));
    await tester.pumpAndSettle();
    for (final item in [
      'التعديل على قوائم البرنامج',
      'ملفات الشرح',
      'ضبط وإصلاح',
      'الشكاوى والمقترحات',
      'التسجيل',
      'عن الشركة',
    ]) {
      expect(find.text(item), findsOneWidget);
    }

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(AppThemeController.mode.value, ThemeMode.light);

    await tester.tap(find.byTooltip('المستخدم الحالي'));
    await tester.pumpAndSettle();
    for (final item in [
      'إعدادات المستخدم',
      'تعديل الرقم السري',
      'إغلاق الوردية',
      'خروج المستخدم',
    ]) {
      expect(find.text(item), findsOneWidget);
    }
  });
}
