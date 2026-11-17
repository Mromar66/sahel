import 'dart:io';

import 'package:inventory_app/core/database/sqlite_database.dart';
import 'package:inventory_app/features/purchases/data/purchase_repository.dart';
import 'package:inventory_app/features/purchases/domain/purchase_models.dart';

/// End-to-end smoke test of the purchase repository against a *copy* of the
/// live database. Run with: dart run tool/purchase_smoke.dart
void main() async {
  final source = File('database/inventory.sqlite');
  if (!source.existsSync()) {
    stderr.writeln('source database not found');
    exit(1);
  }
  final temp = Directory(
    '${Directory.systemTemp.path}/sahl_purchase_smoke',
  );
  if (temp.existsSync()) temp.deleteSync(recursive: true);
  Directory('${temp.path}/database').createSync(recursive: true);
  source.copySync('${temp.path}/database/inventory.sqlite');
  Directory.current = temp.path;

  final db = SqliteDatabase();
  final repo = PurchaseRepository();

  print('next invoice: ${repo.nextInvoiceNumber()}');
  final accounts = await repo.getAccounts();
  print('accounts: ${accounts.map((a) => "${a.id}:${a.name}").join(", ")}');
  if (accounts.isEmpty) {
    stderr.writeln('no accounts');
    exit(1);
  }
  final products = await repo.searchProducts('صف');
  print('search "صف": ${products.map((p) => "${p.id}:${p.name}").join(", ")}');
  final byCode = await repo.findByBarcode(products.first.code);
  print('barcode lookup: ${byCode?.name}');

  final product = products.first;
  final invoiceNumber = repo.nextInvoiceNumber();
  final result = await repo.savePurchase(
    accountId: accounts.first.id,
    invoiceNumber: invoiceNumber,
    lines: [
      PurchaseLine(
        productId: product.id,
        code: product.code,
        name: product.name,
        unit: product.unitName,
        available: product.available,
        qty: 3,
        price: 12,
        discount: 1,
      ),
    ],
    discount: 2,
    addition: 0,
    notes: 'اختبار المستودع',
    paymentMethod: 'cash',
    payment: PurchasePaymentInput(
      accountId: accounts.first.id,
      amount: 10,
      method: 'cash',
    ),
  );
  print('saved: $result invoice=${result.invoiceNumber} total=${result.total}');
  print('invoice: ${await repo.getInvoice(result.invoiceId)}');
  print('items: ${await repo.getInvoiceItems(result.invoiceId)}');
  final converted = await repo.recordPayment(
    invoiceId: result.invoiceId,
    accountId: accounts.first.id,
    amount: 10,
    method: 'bank',
  );
  print('extra payment: paid=${converted.paid} remaining=${converted.remaining}');
  print('product after: ${db.query("SELECT id,current_stock,purchase_price FROM products WHERE id = ?", [product.id])}');
  print('movements: ${db.query("SELECT * FROM stock_movements WHERE reference_id = ?", [result.invoiceId])}');
  print('payments: ${db.query("SELECT payment_number,amount,payment_method,reference_id FROM payments")}');
  print('treasury: ${db.query("SELECT transaction_type,amount,balance_after,reference_id FROM treasury_transactions")}');
  print('account: ${db.query("SELECT id,balance FROM accounts WHERE id = ?", [accounts.first.id])}');

  // Validation failures must not leave rows behind.
  final before = db.query('SELECT COUNT(*) c FROM purchase_invoices').first['c'];
  try {
    await repo.savePurchase(
      accountId: accounts.first.id,
      invoiceNumber: 'X',
      lines: [
        PurchaseLine(
          productId: product.id,
          code: 'X',
          name: 'bad',
          unit: '',
          available: 0,
          qty: 0,
          price: 1,
        ),
      ],
      discount: 0,
      addition: 0,
      notes: '',
      paymentMethod: 'cash',
    );
    print('ERROR: zero qty accepted');
  } catch (e) {
    print('validation ok: $e');
  }
  final after = db.query('SELECT COUNT(*) c FROM purchase_invoices').first['c'];
  print('invoice count unchanged: $before -> $after');

  db.close();
  Directory.current = Directory.systemTemp.path;
  print('DONE ${temp.path}');
}
