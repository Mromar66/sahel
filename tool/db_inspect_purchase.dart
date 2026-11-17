import 'package:sqlite3/sqlite3.dart';

void main(List<String> args) {
  final path = args.isEmpty ? 'database/inventory.sqlite' : args.first;
  final db = sqlite3.open(path);
  print('DB: $path');
  final tables = db.select(
    "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
  );
  for (final t in tables) {
    final name = t['name'] as String;
    if (name.startsWith('sqlite_')) continue;
    final info = db.select('PRAGMA table_info($name)');
    final cols = info.map((c) => c['name']).join(', ');
    final count = db.select('SELECT COUNT(*) AS c FROM "$name"').first['c'];
    print('\n[$name] ($count)');
    print('  $cols');
  }
  for (final table in ['products', 'units', 'accounts', 'suppliers', 'purchase_invoices', 'purchase_items', 'stock_movements', 'sales_invoices', 'payments', 'treasury_transactions', 'warehouses', 'stocktaking_sessions', 'stocktaking_items', 'stock_adjustment_sessions', 'stock_adjustment_items', 'stock_transfer_sessions', 'stock_transfer_items']) {
    print('\n--- $table rows ---');
    final rows = db.select('SELECT * FROM $table LIMIT 15');
    for (final r in rows) {
      print('  $r');
    }
  }
  db.dispose();
}
