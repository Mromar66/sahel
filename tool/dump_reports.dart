import 'dart:ffi';
import 'dart:io';

import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  open.overrideFor(
    OperatingSystem.windows,
    () => DynamicLibrary.open(
      r'C:\sahl_app\build\windows\x64\runner\Release\sqlite3.dll',
    ),
  );
  final db = sqlite3.open(r'C:\sahl_app\database\inventory.sqlite');
  void dump(String title, String sql) {
    stdout.writeln('\n== $title');
    for (final row in db.select(sql)) {
      stdout.writeln(row.toString());
    }
  }

  db.select('PRAGMA table_info(products)').forEach((row) {
    stdout.writeln('products.${row['name']} ${row['type']}');
  });
  dump('accounts', 'SELECT id, name, account_type, balance, is_active FROM accounts');
  dump('products', 'SELECT id, name, product_code, category_id, purchase_price, selling_price, current_stock FROM products');
  dump('sales_invoices', 'SELECT id, invoice_number, invoice_date, subtotal, discount, tax, total, paid_amount, remaining_amount, payment_status, is_return, original_invoice_id, account_id FROM sales_invoices ORDER BY id');
  dump('sales_items', 'SELECT * FROM sales_items ORDER BY invoice_id, id');
  dump('purchase_invoices', 'SELECT id, invoice_number, invoice_date, subtotal, discount, tax, total, paid_amount, remaining_amount, payment_status, is_return, original_invoice_id, account_id FROM purchase_invoices ORDER BY id');
  dump('purchase_items', 'SELECT * FROM purchase_items ORDER BY invoice_id, id');
  dump('purchase_return_invoices', 'SELECT * FROM purchase_return_invoices ORDER BY id');
  dump('purchase_return_items', 'SELECT * FROM purchase_return_items ORDER BY return_id, id');
  dump('payments', 'SELECT * FROM payments ORDER BY id');
  dump('treasury_transactions', 'SELECT * FROM treasury_transactions ORDER BY id');
  dump('expenses', 'SELECT * FROM expenses');
  dump('stock_movements', 'SELECT * FROM stock_movements ORDER BY id');
  dump('treasuries', 'SELECT * FROM treasuries');
  dump('warehouses', 'SELECT * FROM warehouses');
  dump('program_users', 'SELECT id, username, display_name, is_admin, is_active FROM program_users');
  db.dispose();
}
