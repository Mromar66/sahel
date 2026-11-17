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
  db.execute('PRAGMA foreign_keys = ON');
  void dump(String title, String sql) {
    stdout.writeln('== $title');
    for (final row in db.select(sql)) {
      stdout.writeln(row.toString());
    }
  }

  dump(
    'sales_invoices',
    'SELECT id, invoice_number, invoice_date, subtotal, discount, tax, total, '
        'paid_amount, remaining_amount, account_id FROM sales_invoices ORDER BY id',
  );
  dump(
    'sales_items',
    'SELECT id, invoice_id, product_id, quantity, unit_price, discount, total '
        'FROM sales_items ORDER BY invoice_id, id',
  );
  dump(
    'product6',
    "SELECT id, name, current_stock, purchase_price, selling_price, category_id FROM products WHERE id = 6",
  );
  dump(
    'stock_movements',
    'SELECT id, product_id, movement_type, quantity, from_warehouse_id, to_warehouse_id, reference_type, reference_id, movement_date FROM stock_movements ORDER BY id',
  );
  db.dispose();
}
