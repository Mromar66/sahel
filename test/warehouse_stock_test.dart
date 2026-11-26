import 'package:flutter_test/flutter_test.dart';
import 'package:safwa/core/database/sqlite_database.dart';
import 'package:safwa/core/services/warehouse_stock.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Database rawDatabase;
  late SqliteDatabase database;

  setUp(() {
    rawDatabase = sqlite3.openInMemory();
    rawDatabase.execute('''
      CREATE TABLE warehouses (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1
      );
      CREATE TABLE products (
        id INTEGER PRIMARY KEY,
        current_stock INTEGER NOT NULL DEFAULT 0
      );
      CREATE TABLE stock_movements (
        id INTEGER PRIMARY KEY,
        product_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        movement_type TEXT NOT NULL,
        from_warehouse_id INTEGER,
        to_warehouse_id INTEGER
      );
      INSERT INTO warehouses(id, name) VALUES (1, 'الرئيسي'), (2, 'الفرعي');
      INSERT INTO products(id, current_stock) VALUES (1, 97), (2, 5);
      INSERT INTO stock_movements
        (id, product_id, quantity, movement_type, to_warehouse_id)
      VALUES (1, 1, 100, 'purchase', 1), (2, 2, 5, 'purchase', 2);
      INSERT INTO stock_movements
        (id, product_id, quantity, movement_type, from_warehouse_id)
      VALUES (3, 1, 30, 'transfer_out', 1);
      INSERT INTO stock_movements
        (id, product_id, quantity, movement_type, to_warehouse_id)
      VALUES (4, 1, 30, 'transfer_in', 2);
      INSERT INTO stock_movements
        (id, product_id, quantity, movement_type, from_warehouse_id)
      VALUES (5, 1, -5, 'adjustment', 2);
      INSERT INTO stock_movements
        (id, product_id, quantity, movement_type, from_warehouse_id)
      VALUES (6, 1, 2, 'stocktaking', 1);
    ''');
    database = SqliteDatabase.withDatabase(rawDatabase);
  });

  tearDown(() => rawDatabase.dispose());

  test('transfers and signed adjustments produce warehouse totals', () {
    final stock = WarehouseStock.byProduct(database, 1);
    final byId = {
      for (final row in stock) (row['id'] as int): row['available'] as int,
    };

    expect(byId, {1: 72, 2: 25});
    expect(byId.values.reduce((sum, quantity) => sum + quantity), 97);
  });

  test('stock lookup filters out movements for other products', () {
    expect(WarehouseStock.quantityInWarehouse(database, 1, 2), 25);
    expect(WarehouseStock.quantityInWarehouse(database, 2, 1), 0);
    expect(WarehouseStock.quantityInWarehouse(database, 2, 2), 5);
  });

  test('unassigned legacy quantities stay in the primary warehouse', () {
    rawDatabase.execute('UPDATE products SET current_stock = 90 WHERE id = 1');

    final stock = WarehouseStock.byProduct(database, 1);
    final primary = stock.firstWhere((row) => row['id'] == 1);
    final secondary = stock.firstWhere((row) => row['id'] == 2);

    expect(primary['available'], 65);
    expect(secondary['available'], 25);
  });
}
