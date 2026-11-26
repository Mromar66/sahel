import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:safwa/app/app.dart';

void main() {
  testWidgets('Dashboard renders on a desktop surface', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: InventoryApp()));
    await tester.pumpAndSettle();

    expect(find.byType(InventoryApp), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
