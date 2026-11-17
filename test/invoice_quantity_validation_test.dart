import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_app/features/invoice_ops/data/invoice_op_repository.dart';
import 'package:inventory_app/features/invoice_ops/domain/invoice_op_models.dart';

void main() {
  test('duplicate invoice rows are combined before stock validation', () {
    final quantities = aggregateInvoiceQuantities([
      InvoiceLine(
        productId: 7,
        code: 'P7',
        name: 'صنف',
        unit: 'حبة',
        available: 10,
        qty: 6,
        price: 20,
      ),
      InvoiceLine(
        productId: 7,
        code: 'P7',
        name: 'صنف',
        unit: 'حبة',
        available: 10,
        qty: 5,
        price: 25,
      ),
    ]);

    expect(quantities, {7: 11});
  });

  test('invoice rows without a saved product are rejected', () {
    expect(
      () => aggregateInvoiceQuantities([
        InvoiceLine(
          code: '',
          name: 'غير مسجل',
          unit: 'حبة',
          available: 0,
          qty: 1,
          price: 1,
        ),
      ]),
      throwsA(isA<InvoiceValidationException>()),
    );
  });
}
