import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_app/features/products/presentation/products_list_page.dart';

void main() {
  testWidgets('products page fits a 1024x704 desktop viewport', (tester) async {
    tester.view.physicalSize = const Size(1024, 704);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: ProductsListPage()));
    await tester.pumpAndSettle();

    expect(find.byType(ProductsListPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
