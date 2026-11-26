import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safwa/app/app.dart';
import 'package:safwa/app/router.dart';
import 'package:safwa/app/theme/app_theme.dart';
import 'package:safwa/core/services/auth_session.dart';

const _testDatabaseMarker = 'safwa_settings_categories_qa';
const _testPassword = 'Test-Only-Admin-2026';
final _isolatedTestRun =
    Platform.environment['SAHEL_DATABASE_DIR']?.contains(_testDatabaseMarker) ??
    false;

void main() {
  setUpAll(() async {
    if (!_isolatedTestRun) return;
    await AuthSession.instance.initialize();
    final setupError = await AuthSession.instance.createFirstAdmin(
      username: 'settings_qa',
      displayName: 'مدير الاختبار',
      password: _testPassword,
    );
    expect(setupError, isNull);
    expect(
      await AuthSession.instance.login('settings_qa', _testPassword),
      isNull,
    );
  });

  testWidgets(
    'settings categories open the matching Safwa screen or explain the gap',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(() => AppThemeController.mode.value = ThemeMode.dark);

      await tester.pumpWidget(const ProviderScope(child: InventoryApp()));
      await tester.pumpAndSettle();
      appRouter.go('/settings');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, _testPassword);
      await tester.tap(find.text('موافق'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 3)),
      );
      await tester.pump();

      final categories = [
        'إعدادات النظام',
        'الفواتير',
        'المخازن',
        'العملاء والموردين',
        'الضرائب',
        'صلاحيات المستخدمين',
        'الأجهزة والطابعات',
        'طريقة العرض',
        'شريط الأخبار',
        'الحقول الإضافية',
        'الدورة المستندية',
        'الإضافات',
        'تصميم التقارير',
      ];
      for (final category in categories) {
        expect(find.text(category), findsWidgets, reason: category);
      }

      await _openCategory(tester, 'إعدادات النظام');
      expect(find.text('اسم المشروع'), findsOneWidget);
      await _backToProperties(tester);

      await _openCategory(tester, 'الفواتير');
      expect(find.text('تفعيل خصائص الفاتورة الإلكترونية'), findsOneWidget);
      await _backToProperties(tester);

      await _openCategory(tester, 'المخازن');
      expect(find.text('المخازن / الفروع'), findsOneWidget);
      await _backToProperties(tester);

      await _openCategory(tester, 'الضرائب');
      expect(find.text('الرقم الضريبي'), findsOneWidget);
      await _backToProperties(tester);

      await _openCategory(tester, 'صلاحيات المستخدمين');
      expect(find.text('مستخدمو البرنامج'), findsOneWidget);
      await _backToProperties(tester);

      await _openCategory(tester, 'الأجهزة والطابعات');
      expect(find.text('عدد نسخ طباعة فاتورة البيع'), findsOneWidget);
      await _backToProperties(tester);

      await _openCategory(tester, 'الحقول الإضافية');
      expect(find.text('حقول إضافية للصنف'), findsOneWidget);
      await _backToProperties(tester);

      await _openCategory(tester, 'طريقة العرض');
      expect(find.text('استخدام الواجهة الفاتحة'), findsOneWidget);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(AppThemeController.mode.value, ThemeMode.light);
      await tester.tap(find.text('إغلاق'));
      await tester.pumpAndSettle();

      await _openCategory(tester, 'شريط الأخبار');
      expect(find.textContaining('شريط الأخبار مش موجود'), findsOneWidget);
      await _closeInfo(tester);

      await _openCategory(tester, 'الدورة المستندية');
      expect(find.textContaining('الدورة المستندية مش موجودة'), findsOneWidget);
      await _closeInfo(tester);

      await _openCategory(tester, 'الإضافات');
      expect(
        find.textContaining('إدارة إضافات خارجية مش موجودة'),
        findsOneWidget,
      );
      await _closeInfo(tester);

      await _openCategory(tester, 'تصميم التقارير');
      expect(find.textContaining('مصمم نماذج التقارير'), findsOneWidget);
      await tester.tap(find.text('فتح مركز التقارير'));
      await tester.pumpAndSettle();
      expect(appRouter.routeInformationProvider.value.uri.path, '/reports');

      appRouter.go('/settings');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, _testPassword);
      await tester.tap(find.text('موافق'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 3)),
      );
      await tester.pump();
      await _openCategory(tester, 'العملاء والموردين');
      await tester.pumpAndSettle();
      expect(appRouter.routeInformationProvider.value.uri.path, '/accounts');
      expect(tester.takeException(), isNull);
    },
    skip: !_isolatedTestRun,
  );
}

Future<void> _openCategory(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> _backToProperties(WidgetTester tester) async {
  await tester.tap(find.text('كل الخصائص'));
  await tester.pumpAndSettle();
}

Future<void> _closeInfo(WidgetTester tester) async {
  await tester.tap(find.text('إغلاق'));
  await tester.pumpAndSettle();
}
