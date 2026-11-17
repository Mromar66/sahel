import 'package:inventory_app/core/database/sqlite_database.dart';

/// Warehouse balances are derived from the movement ledger while preserving
/// the global product total for legacy movements that had no warehouse.
class WarehouseStock {
  const WarehouseStock._();

  static int? defaultWarehouseId(SqliteDatabase database) {
    final rows = database.query(
      'SELECT id FROM warehouses WHERE is_active = 1 ORDER BY id LIMIT 1',
    );
    return rows.isEmpty ? null : (rows.first['id'] as num).toInt();
  }

  static List<Map<String, Object?>> byProduct(
    SqliteDatabase database,
    int productId,
  ) {
    return database.query(
      '''
      WITH warehouse_balances AS (
        SELECT w.id, w.name,
          COALESCE(SUM(CASE
            WHEN sm.movement_type IN ('adjustment', 'stocktaking') THEN
              CASE
                WHEN sm.from_warehouse_id = w.id OR sm.to_warehouse_id = w.id
                THEN sm.quantity ELSE 0
              END
            WHEN sm.movement_type = 'transfer_out' THEN
              CASE WHEN sm.from_warehouse_id = w.id THEN -ABS(sm.quantity) ELSE 0 END
            WHEN sm.movement_type = 'transfer_in' THEN
              CASE WHEN sm.to_warehouse_id = w.id THEN ABS(sm.quantity) ELSE 0 END
            ELSE
              CASE WHEN sm.to_warehouse_id = w.id THEN ABS(sm.quantity) ELSE 0 END -
              CASE WHEN sm.from_warehouse_id = w.id THEN ABS(sm.quantity) ELSE 0 END
          END), 0) AS ledger_quantity
        FROM warehouses w
        LEFT JOIN stock_movements sm
          ON sm.product_id = ?
            AND (sm.to_warehouse_id = w.id OR sm.from_warehouse_id = w.id)
        GROUP BY w.id, w.name
      ), totals AS (
        SELECT COALESCE(current_stock, 0) AS global_quantity
        FROM products WHERE id = ?
      ), tracked AS (
        SELECT COALESCE(SUM(ledger_quantity), 0) AS ledger_quantity
        FROM warehouse_balances
      ), primary_warehouse AS (
        SELECT id FROM warehouses WHERE is_active = 1 ORDER BY id LIMIT 1
      )
      SELECT wb.id, wb.name,
        wb.ledger_quantity + CASE
          WHEN wb.id = (SELECT id FROM primary_warehouse)
          THEN COALESCE((SELECT global_quantity FROM totals), 0) -
               COALESCE((SELECT ledger_quantity FROM tracked), 0)
          ELSE 0
        END AS available,
        0 AS reserved
      FROM warehouse_balances wb
      WHERE wb.ledger_quantity + CASE
        WHEN wb.id = (SELECT id FROM primary_warehouse)
        THEN COALESCE((SELECT global_quantity FROM totals), 0) -
             COALESCE((SELECT ledger_quantity FROM tracked), 0)
        ELSE 0
      END <> 0
      ORDER BY wb.id
      ''',
      [productId, productId],
    );
  }

  static int quantityInWarehouse(
    SqliteDatabase database,
    int productId,
    int? warehouseId,
  ) {
    if (warehouseId == null) return 0;
    for (final row in byProduct(database, productId)) {
      if ((row['id'] as num).toInt() == warehouseId) {
        return (row['available'] as num?)?.toInt() ?? 0;
      }
    }
    return 0;
  }
}
