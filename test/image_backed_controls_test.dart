import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_app/app/widgets/hover_widgets.dart';

void main() {
  testWidgets('image-backed toolbar actions are accessible real buttons', (
    tester,
  ) async {
    var taps = 0;
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: HoverAssetButton(
              asset: 'assets/icons/products/top_refresh.png',
              width: 126,
              height: 30,
              onTap: () => taps++,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(InkWell), findsOneWidget);
    expect(find.bySemanticsLabel('تحديث'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byType(InkWell));
    expect(taps, 1);
    semantics.dispose();
  });

  testWidgets('missing image asset keeps the action labeled and usable', (
    tester,
  ) async {
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: HoverAssetButton(
              asset: 'assets/icons/products/top_refresh_missing.png',
              width: 126,
              height: 30,
              onTap: () => taps++,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('تحديث'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byType(InkWell));
    expect(taps, 1);
  });
}
