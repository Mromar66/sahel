import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:safwa/features/products/presentation/products_list_page.dart';

void main() {
  testWidgets('products page fits a 1024x704 desktop viewport', (tester) async {
    tester.view.physicalSize = const Size(1024, 704);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/products',
      routes: [
        GoRoute(
          path: '/products',
          builder: (context, state) => const ProductsListPage(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.byType(ProductsListPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
