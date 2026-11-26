import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:safwa/app/shell/program_search_dialog.dart';

void main() {
  test('Arabic search ignores diacritics and common alef variants', () {
    expect(normalizeProgramSearchText('إِضافة صِنف'), 'اضافة صنف');
    expect(normalizeProgramSearchText('الأصناف'), 'الاصناف');
    expect(matchesProgramSearchText('الأصناف', 'أصناف'), isTrue);
    expect(matchesProgramSearchText('فاتورة مبيعات', 'مشتريات'), isFalse);
  });

  testWidgets('search field stays white and accepts right-to-left typing', (
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
          builder: (context, state) => Scaffold(
            body: Center(
              child: ElevatedButton(
                key: const ValueKey('open-search'),
                onPressed: () => openProgramSearch(context),
                child: const Text('بحث'),
              ),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(theme: ThemeData.dark(), routerConfig: router),
    );
    await tester.tap(find.byKey(const ValueKey('open-search')));
    await tester.pumpAndSettle();

    final input = find.byType(TextField);
    expect(input, findsOneWidget);
    final field = tester.widget<TextField>(input);
    expect(field.textDirection, TextDirection.rtl);
    expect(field.decoration?.filled, isTrue);
    expect(field.decoration?.fillColor, Colors.white);
    expect(field.cursorColor, const Color(0xFF168AE3));

    await tester.enterText(input, 'إضافة صنف');
    await tester.pump();
    expect(tester.widget<TextField>(input).controller?.text, 'إضافة صنف');
    expect(tester.takeException(), isNull);
  });
}
