import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_app/core/database/sqlite_database.dart';
import 'package:inventory_app/core/services/warehouse_stock.dart';
import 'package:inventory_app/features/stocktaking/data/stocktaking_repository.dart';
import 'package:inventory_app/features/stocktaking/domain/stocktaking_models.dart';
import 'package:inventory_app/features/warehouse_ops/data/warehouse_ops_repository.dart';
import 'package:inventory_app/features/warehouse_ops/domain/warehouse_op_models.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Database rawDatabase;
  late SqliteDatabase database;
  late WarehouseOpsRepository operations;
  late StocktakingRepository stocktaking;

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
        name TEXT NOT NULL,
        product_code TEXT,
        current_stock INTEGER NOT NULL DEFAULT 0,
        purchase_price INTEGER NOT NULL DEFAULT 0,
        selling_price INTEGER NOT NULL DEFAULT 0,
        unit_name TEXT,
        updated_at TEXT
      );
      CREATE TABLE stock_movements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        movement_type TEXT NOT NULL,
        reference_id INTEGER,
        reference_type TEXT,
        from_warehouse_id INTEGER,
        to_warehouse_id INTEGER,
        movement_date TEXT,
        notes TEXT
      );
      CREATE TABLE stock_adjustment_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_number TEXT NOT NULL,
        warehouse_id INTEGER,
        session_date TEXT,
        total INTEGER,
        items_count INTEGER,
        applied INTEGER,
        notes TEXT,
        created_at TEXT,
        updated_at TEXT
      );
      CREATE TABLE stock_adjustment_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER,
        product_id INTEGER,
        product_name TEXT,
        product_code TEXT,
        unit_name TEXT,
        available_qty INTEGER,
        adjusted_qty INTEGER,
        difference INTEGER,
        price INTEGER,
        total INTEGER
      );
      CREATE TABLE stock_transfer_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_number TEXT NOT NULL,
        from_warehouse_id INTEGER,
        to_warehouse_id INTEGER,
        session_date TEXT,
        total INTEGER,
        items_count INTEGER,
        applied INTEGER,
        notes TEXT,
        created_at TEXT,
        updated_at TEXT
      );
      CREATE TABLE stock_transfer_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER,
        product_id INTEGER,
        product_name TEXT,
        product_code TEXT,
        unit_name TEXT,
        available_qty INTEGER,
        transfer_qty INTEGER,
        price INTEGER,
        total INTEGER
      );
      CREATE TABLE stocktaking_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_number TEXT NOT NULL,
        warehouse_id INTEGER,
        session_date TEXT,
        total INTEGER,
        items_count INTEGER,
        applied INTEGER,
        notes TEXT,
        created_at TEXT,
        updated_at TEXT
      );
      CREATE TABLE stocktaking_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER,
        product_id INTEGER,
        product_name TEXT,
        product_code TEXT,
        unit_name TEXT,
        available_qty INTEGER,
        counted_qty INTEGER,
        price INTEGER,
        total INTEGER
      );
      CREATE TABLE document_custom_values (
        document_type TEXT,
        document_id INTEGER,
        field_id INTEGER,
        value TEXT,
        updated_at TEXT
      );
      INSERT INTO warehouses(id, name) VALUES (1, 'الرئيسي'), (2, 'الفرعي');
      INSERT INTO products(id, name, product_code, current_stock, purchase_price)
      VALUES (1, 'صنف', 'P1', 100, 10);
      INSERT INTO stock_movements
        (product_id, quantity, movement_type, to_warehouse_id)
      VALUES (1, 100, 'purchase', 1);
    ''');
    database = SqliteDatabase.withDatabase(rawDatabase);
    operations = WarehouseOpsRepository.withDatabase(database);
    stocktaking = StocktakingRepository.withDatabase(database);
  });

  tearDown(() => rawDatabase.dispose());

  Map<int, int> balances() => {
    for (final row in WarehouseStock.byProduct(database, 1))
      (row['id'] as int): row['available'] as int,
  };

  test(
    'adjustments apply only to their warehouse and edits reverse cleanly',
    () async {
      final adjustment = await operations.saveAdjustment(
        warehouseId: 2,
        sessionNumber: 'ADJ-1',
        lines: [
          WarehouseOpLine(
            productId: 1,
            code: 'P1',
            name: 'صنف',
            unit: 'حبة',
            available:
                100, // deliberately stale; the repository must use warehouse 2
            qty: 20,
            price: 10,
          ),
        ],
        notes: '',
        applyStock: true,
      );
      expect(balances(), {1: 100, 2: 20});
      expect(
        rawDatabase
            .select('SELECT current_stock FROM products')
            .first['current_stock'],
        120,
      );

      await operations.updateAdjustment(
        sessionId: adjustment.sessionId,
        warehouseId: 1,
        sessionNumber: 'ADJ-1',
        lines: [
          WarehouseOpLine(
            productId: 1,
            code: 'P1',
            name: 'صنف',
            unit: 'حبة',
            available: 0,
            qty: 95,
            price: 10,
          ),
        ],
        notes: '',
        applyStock: true,
      );
      expect(balances(), {1: 95});
      expect(
        rawDatabase
            .select('SELECT current_stock FROM products')
            .first['current_stock'],
        95,
      );
    },
  );

  test(
    'transfer writes one out and one in without changing global quantity',
    () async {
      final result = await operations.saveTransfer(
        fromWarehouseId: 1,
        toWarehouseId: 2,
        sessionNumber: 'TR-1',
        lines: [
          WarehouseOpLine(
            productId: 1,
            code: 'P1',
            name: 'صنف',
            unit: 'حبة',
            available: 100,
            qty: 30,
            price: 10,
          ),
        ],
        notes: '',
        applyStock: true,
      );

      expect(balances(), {1: 70, 2: 30});
      expect(
        rawDatabase
            .select('SELECT current_stock FROM products')
            .first['current_stock'],
        100,
      );
      final movements = rawDatabase.select(
        "SELECT movement_type, from_warehouse_id, to_warehouse_id FROM stock_movements WHERE reference_type='stock_transfer' AND reference_id=? ORDER BY id",
        [result.sessionId],
      );
      expect(movements, hasLength(2));
      expect(movements.first['movement_type'], 'transfer_out');
      expect(movements.first['from_warehouse_id'], 1);
      expect(movements.first['to_warehouse_id'], isNull);
      expect(movements.last['movement_type'], 'transfer_in');
      expect(movements.last['from_warehouse_id'], isNull);
      expect(movements.last['to_warehouse_id'], 2);
    },
  );

  test(
    'transfer edits cannot remove stock already consumed at destination',
    () async {
      final result = await operations.saveTransfer(
        fromWarehouseId: 1,
        toWarehouseId: 2,
        sessionNumber: 'TR-USED',
        lines: [
          WarehouseOpLine(
            productId: 1,
            code: 'P1',
            name: 'صنف',
            unit: 'حبة',
            available: 100,
            qty: 30,
            price: 10,
          ),
        ],
        notes: '',
        applyStock: true,
      );
      rawDatabase.execute('''
        INSERT INTO stock_movements
          (product_id, quantity, movement_type, from_warehouse_id)
        VALUES (1, 28, 'sale', 2)
      ''');
      rawDatabase.execute('UPDATE products SET current_stock=72 WHERE id=1');

      await expectLater(
        operations.updateTransfer(
          sessionId: result.sessionId,
          fromWarehouseId: 1,
          toWarehouseId: 2,
          sessionNumber: 'TR-USED',
          lines: [
            WarehouseOpLine(
              productId: 1,
              code: 'P1',
              name: 'صنف',
              unit: 'حبة',
              available: 100,
              qty: 30,
              price: 10,
            ),
          ],
          notes: '',
          applyStock: false,
        ),
        throwsA(
          isA<WarehouseOpValidationException>().having(
            (error) => error.message,
            'message',
            contains('مخزن الوجهة'),
          ),
        ),
      );

      expect(balances(), {1: 70, 2: 2});
      expect(
        rawDatabase.select(
          "SELECT COUNT(*) AS c FROM stock_movements "
          "WHERE reference_type='stock_transfer' AND reference_id=?",
          [result.sessionId],
        ).single['c'],
        2,
      );
      expect(
        rawDatabase.select(
          'SELECT transfer_qty FROM stock_transfer_items WHERE session_id=?',
          [result.sessionId],
        ).single['transfer_qty'],
        30,
      );
    },
  );

  test(
    'a no-op transfer edit remains allowed after destination sales',
    () async {
      final result = await operations.saveTransfer(
        fromWarehouseId: 1,
        toWarehouseId: 2,
        sessionNumber: 'TR-NOOP',
        lines: [
          WarehouseOpLine(
            productId: 1,
            code: 'P1',
            name: 'صنف',
            unit: 'حبة',
            available: 100,
            qty: 30,
            price: 10,
          ),
        ],
        notes: '',
        applyStock: true,
      );
      rawDatabase.execute('''
      INSERT INTO stock_movements
        (product_id, quantity, movement_type, from_warehouse_id)
      VALUES (1, 28, 'sale', 2)
    ''');
      rawDatabase.execute('UPDATE products SET current_stock=72 WHERE id=1');

      await operations.updateTransfer(
        sessionId: result.sessionId,
        fromWarehouseId: 1,
        toWarehouseId: 2,
        sessionNumber: 'TR-NOOP',
        lines: [
          WarehouseOpLine(
            productId: 1,
            code: 'P1',
            name: 'صنف',
            unit: 'حبة',
            available: 100,
            qty: 30,
            price: 10,
          ),
        ],
        notes: '',
        applyStock: true,
      );

      expect(balances(), {1: 70, 2: 2});
    },
  );

  test(
    'stocktaking changes only the selected warehouse and global delta',
    () async {
      await stocktaking.saveSession(
        warehouseId: 1,
        sessionNumber: 'ST-1',
        lines: [
          StocktakingLine(
            productId: 1,
            code: 'P1',
            name: 'صنف',
            unit: 'حبة',
            available: 100,
            qty: 92,
            price: 10,
          ),
        ],
        notes: '',
        applyStock: true,
      );

      expect(balances(), {1: 92});
      expect(
        rawDatabase
            .select('SELECT current_stock FROM products')
            .first['current_stock'],
        92,
      );
      final movement = rawDatabase
          .select(
            "SELECT from_warehouse_id FROM stock_movements WHERE reference_type='stocktaking_session'",
          )
          .single;
      expect(movement['from_warehouse_id'], 1);
    },
  );
}
