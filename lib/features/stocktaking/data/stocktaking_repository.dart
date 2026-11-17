import 'package:inventory_app/core/database/sqlite_database.dart';
import 'package:inventory_app/core/services/document_custom_fields.dart';
import 'package:inventory_app/core/services/warehouse_stock.dart';
import 'package:inventory_app/core/utils/constants.dart';
import 'package:inventory_app/features/stocktaking/domain/stocktaking_models.dart';

/// Data access for the جرد مخزن (warehouse stocktaking) screen.
///
/// The class is intentionally separate from `PurchaseRepository`: a
/// stocktaking session never touches purchase invoices, payments, accounts or
/// the treasury. Only the shared `products` / `stock_movements` tables are
/// used, so the inventory stays the single source of truth.
class StocktakingRepository {
  StocktakingRepository._internal() : _db = SqliteDatabase();

  StocktakingRepository.withDatabase(SqliteDatabase database) : _db = database;

  static final StocktakingRepository _instance =
      StocktakingRepository._internal();
  factory StocktakingRepository() => _instance;

  final SqliteDatabase _db;

  static final RegExp _digits = RegExp(r'\d+');

  // ---------------------------------------------------------------------------
  // Product lookups.
  // ---------------------------------------------------------------------------

  /// Search active products by name / code / barcode / secondary codes.
  Future<List<StocktakingProduct>> searchProducts(
    String term, {
    int limit = 60,
  }) async {
    final key = term.trim();
    if (key.isEmpty) return const [];
    final pattern = '%${_escapeLike(key)}%';
    final rows = _db.query(
      '''
      SELECT p.id, p.name, p.product_code, p.barcode,
             p.purchase_price, p.selling_price, p.current_stock,
             COALESCE(u.name, '') AS unit_name
      FROM products p
      LEFT JOIN units u ON u.id = p.unit_id
      WHERE p.is_active = 1
        AND (
          p.name LIKE ? ESCAPE '\\'
          OR p.product_code LIKE ? ESCAPE '\\'
          OR IFNULL(p.barcode, '') LIKE ? ESCAPE '\\'
          OR IFNULL(p.code2, '') LIKE ? ESCAPE '\\'
          OR IFNULL(p.other_codes, '') LIKE ? ESCAPE '\\'
        )
      ORDER BY p.name COLLATE NOCASE
      LIMIT ?
      ''',
      [pattern, pattern, pattern, pattern, pattern, limit],
    );
    return rows.map(_rowToProduct).toList();
  }

  /// Exact barcode / code lookup used when the operator scans a product.
  Future<StocktakingProduct?> findByBarcode(String code) async {
    final key = code.trim();
    if (key.isEmpty) return null;
    final rows = _db.query(
      '''
      SELECT p.id, p.name, p.product_code, p.barcode,
             p.purchase_price, p.selling_price, p.current_stock,
             COALESCE(u.name, '') AS unit_name
      FROM products p
      LEFT JOIN units u ON u.id = p.unit_id
      WHERE p.is_active = 1
        AND (
          p.barcode = ?
          OR p.product_code = ?
          OR IFNULL(p.code2, '') = ?
        )
      LIMIT 1
      ''',
      [key, key, key],
    );
    if (rows.isEmpty) return null;
    return _rowToProduct(rows.first);
  }

  /// All active products (quick list / category picker).
  Future<List<StocktakingProduct>> listProducts({int? categoryId}) async {
    final rows = _db.query('''
      SELECT p.id, p.name, p.product_code, p.barcode,
             p.purchase_price, p.selling_price, p.current_stock,
             COALESCE(u.name, '') AS unit_name
      FROM products p
      LEFT JOIN units u ON u.id = p.unit_id
      WHERE p.is_active = 1
        ${categoryId == null ? '' : 'AND p.category_id = ?'}
      ORDER BY p.name COLLATE NOCASE
      ''', categoryId == null ? [] : [categoryId]);
    return rows.map(_rowToProduct).toList();
  }

  /// Product categories, for the category picker button.
  Future<List<Map<String, Object?>>> getCategories() async {
    return _db.query('SELECT id, name FROM categories ORDER BY name');
  }

  /// Active warehouses, for the green warehouse selector.
  Future<List<StocktakingWarehouse>> getWarehouses() async {
    final rows = _db.query(
      'SELECT id, name FROM warehouses WHERE is_active = 1 ORDER BY name',
    );
    return rows
        .map(
          (r) => StocktakingWarehouse(
            id: r['id'] as int,
            name: (r['name'] as String?) ?? '',
          ),
        )
        .toList();
  }

  /// Current quantity in one selected warehouse, or the legacy global total
  /// when the database has no warehouse selection.
  int stockForWarehouse(int productId, int? warehouseId) =>
      _stockForWarehouse(productId, warehouseId);

  /// Next session number, continuing the numeric sequence of saved sessions.
  String nextSessionNumber() {
    final rows = _db.query(
      'SELECT session_number FROM stocktaking_sessions ORDER BY id DESC LIMIT 1',
    );
    if (rows.isEmpty) return '1';
    final raw = '${rows.first['session_number'] ?? ''}';
    final match = _digits.firstMatch(raw);
    final next = match == null ? 1 : (int.tryParse(match.group(0)!) ?? 0) + 1;
    return '$next';
  }

  // ---------------------------------------------------------------------------
  // Save.
  // ---------------------------------------------------------------------------

  /// Persist a stocktaking session and its lines in one transaction.
  ///
  /// When [applyStock] is true the counted quantities replace the recorded
  /// inventory quantities and one `stocktaking` stock movement is written for
  /// every product whose count differs from the recorded quantity. When it is
  /// false the session is saved for the record only and the inventory is left
  /// untouched.
  Future<StocktakingSaveResult> saveSession({
    required int? warehouseId,
    required String sessionNumber,
    required List<StocktakingLine> lines,
    required String notes,
    required bool applyStock,
    Map<int, String> customFields = const {},
  }) async {
    if (lines.isEmpty) {
      throw StocktakingValidationException(
        'أضف صنفاً واحداً على الأقل قبل الحفظ.',
      );
    }
    for (final line in lines) {
      if (line.qty < 0) {
        throw StocktakingValidationException(
          'الكمية المحسوبة لا يمكن أن تكون سالبة في السطر «${line.name}».',
        );
      }
      if (line.price < 0) {
        throw StocktakingValidationException(
          'السعر لا يمكن أن يكون سالباً في السطر «${line.name}».',
        );
      }
    }
    _validateUniqueProducts(lines.map((line) => line.productId));

    final total = lines.fold<int>(0, (sum, line) => sum + line.gross);
    var changed = 0;

    return _db.transaction<StocktakingSaveResult>(() async {
      final now = DateTime.now().toIso8601String();
      final sessionId = _db.insert(
        '''
        INSERT INTO stocktaking_sessions
          (session_number, warehouse_id, session_date, total, items_count,
           applied, notes, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          sessionNumber,
          warehouseId,
          now,
          total,
          lines.length,
          applyStock ? 1 : 0,
          notes.isEmpty ? null : notes,
          now,
          now,
        ],
      );

      for (final line in lines) {
        final available = line.productId == null
            ? line.available
            : _stockForWarehouse(line.productId!, warehouseId);
        final difference = line.qty - available;
        if (difference != 0) changed++;
        _db.insert(
          '''
          INSERT INTO stocktaking_items
            (session_id, product_id, product_name, product_code, unit_name,
             available_qty, counted_qty, price, total)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            sessionId,
            line.productId,
            line.name,
            line.code,
            line.unit,
            available,
            line.qty,
            line.price,
            line.gross,
          ],
        );

        if (!applyStock || line.productId == null || difference == 0) {
          continue;
        }

        _db.execute(
          'UPDATE products SET current_stock = current_stock + ?, updated_at = ? WHERE id = ?',
          [difference, now, line.productId],
        );
        _db.insert(
          '''
          INSERT INTO stock_movements
            (product_id, quantity, movement_type, reference_id,
             reference_type, from_warehouse_id, movement_date, notes)
          VALUES (?, ?, ?, ?, 'stocktaking_session', ?, ?, ?)
          ''',
          [
            line.productId,
            difference,
            AppConstants.movementStocktaking,
            sessionId,
            warehouseId,
            now,
            'جرد مخزن - مستند $sessionNumber',
          ],
        );
      }

      DocumentCustomFields.saveValues(
        DocumentTypes.stocktaking,
        sessionId,
        customFields,
      );

      return StocktakingSaveResult(
        sessionId: sessionId,
        sessionNumber: sessionNumber,
        total: total,
        itemsCount: lines.length,
        changedCount: changed,
        applied: applyStock,
      );
    });
  }

  // ---------------------------------------------------------------------------
  // Print / export lookups.
  // ---------------------------------------------------------------------------

  Future<Map<String, Object?>?> getSession(int sessionId) async {
    final rows = _db.query(
      '''
      SELECT ss.*, w.name AS warehouse_name
      FROM stocktaking_sessions ss
      LEFT JOIN warehouses w ON w.id = ss.warehouse_id
      WHERE ss.id = ?
      ''',
      [sessionId],
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, Object?>>> getSessionItems(int sessionId) async {
    return _db.query(
      'SELECT * FROM stocktaking_items WHERE session_id = ? ORDER BY id',
      [sessionId],
    );
  }

  /// Load a saved stocktaking session for editing. The recorded available
  /// quantity is reconstructed as `current_stock - old movement` so it reflects
  /// the stock before this document even after later movements.
  Future<StocktakingEditData?> loadSessionForEdit(int sessionId) async {
    final header = await getSession(sessionId);
    if (header == null) return null;
    final items = await getSessionItems(sessionId);
    final warehouseId = (header['warehouse_id'] as num?)?.toInt();
    final movementByProduct = <int, int>{};
    for (final row in _db.query(
      'SELECT product_id, quantity FROM stock_movements '
      "WHERE reference_type = 'stocktaking_session' AND reference_id = ?",
      [sessionId],
    )) {
      final productId = (row['product_id'] as num?)?.toInt();
      if (productId != null) {
        movementByProduct[productId] =
            (movementByProduct[productId] ?? 0) +
            ((row['quantity'] as num?)?.toInt() ?? 0);
      }
    }
    final lines = <StocktakingEditLine>[];
    for (final item in items) {
      final productId = (item['product_id'] as num?)?.toInt();
      var available = (item['available_qty'] as num?)?.toInt() ?? 0;
      if (productId != null) {
        available =
            _stockForWarehouse(productId, warehouseId) -
            (movementByProduct[productId] ?? 0);
      }
      lines.add(
        StocktakingEditLine(
          productId: productId,
          name: '${item['product_name'] ?? ''}',
          code: '${item['product_code'] ?? ''}',
          unit: '${item['unit_name'] ?? ''}'.trim().isEmpty
              ? 'حبة'
              : '${item['unit_name']}',
          available: available,
          qty: (item['counted_qty'] as num?)?.toInt() ?? 0,
          price: (item['price'] as num?)?.toInt() ?? 0,
        ),
      );
    }
    final parsed = DateTime.tryParse('${header['session_date'] ?? ''}');
    return StocktakingEditData(
      id: sessionId,
      number: '${header['session_number'] ?? ''}',
      warehouseId: (header['warehouse_id'] as num?)?.toInt(),
      date: parsed,
      time: _editTime(parsed),
      notes: '${header['notes'] ?? ''}',
      applied: ((header['applied'] as num?)?.toInt() ?? 0) == 1,
      lines: lines,
      customFields: DocumentCustomFields.values(
        DocumentTypes.stocktaking,
        sessionId,
      ),
    );
  }

  /// Update a saved stocktaking session in place, reversing its old stock
  /// movements before applying the new lines.
  Future<StocktakingSaveResult> updateSession({
    required int sessionId,
    required int? warehouseId,
    required String sessionNumber,
    required List<StocktakingLine> lines,
    required String notes,
    required bool applyStock,
    Map<int, String> customFields = const {},
  }) async {
    if (lines.isEmpty) {
      throw StocktakingValidationException(
        'أضف صنفاً واحداً على الأقل قبل الحفظ.',
      );
    }
    for (final line in lines) {
      if (line.qty < 0) {
        throw StocktakingValidationException(
          'الكمية المحسوبة لا يمكن أن تكون سالبة في السطر «${line.name}».',
        );
      }
      if (line.price < 0) {
        throw StocktakingValidationException(
          'السعر لا يمكن أن يكون سالباً في السطر «${line.name}».',
        );
      }
    }
    _validateUniqueProducts(lines.map((line) => line.productId));

    var changed = 0;
    return _db.transaction<StocktakingSaveResult>(() async {
      final rows = _db.query(
        'SELECT applied FROM stocktaking_sessions WHERE id = ?',
        [sessionId],
      );
      if (rows.isEmpty) {
        throw StocktakingValidationException('مستند الجرد غير موجود.');
      }
      final wasApplied = ((rows.first['applied'] as num?)?.toInt() ?? 0) == 1;
      final now = DateTime.now().toIso8601String();

      if (wasApplied) {
        final movements = _db.query(
          'SELECT product_id, quantity FROM stock_movements '
          "WHERE reference_type = 'stocktaking_session' AND reference_id = ?",
          [sessionId],
        );
        for (final movement in movements) {
          final productId = (movement['product_id'] as num?)?.toInt();
          final quantity = (movement['quantity'] as num?)?.toInt() ?? 0;
          if (productId == null) continue;
          if (quantity > 0) {
            final stockRows = _db.query(
              'SELECT current_stock FROM products WHERE id = ?',
              [productId],
            );
            final stock = stockRows.isEmpty
                ? 0
                : ((stockRows.first['current_stock'] as num?)?.toInt() ?? 0);
            if (stock < quantity) {
              throw StocktakingValidationException(
                'لا يمكن تعديل مستند الجرد لأن بعض الكميات استُخدمت في '
                'حركات لاحقة. المخزون الحالي غير كافٍ للتراجع.',
              );
            }
          }
          _db.execute(
            'UPDATE products SET current_stock = current_stock - ?, '
            'updated_at = ? WHERE id = ?',
            [quantity, now, productId],
          );
        }
      }
      _db.execute(
        "DELETE FROM stock_movements WHERE reference_type = 'stocktaking_session' "
        'AND reference_id = ?',
        [sessionId],
      );
      _db.execute('DELETE FROM stocktaking_items WHERE session_id = ?', [
        sessionId,
      ]);

      var total = 0;
      for (final line in lines) {
        final available = line.productId == null
            ? line.available
            : _stockForWarehouse(line.productId!, warehouseId);
        final difference = line.qty - available;
        if (difference != 0) changed++;
        total += line.qty * line.price;
        _db.insert(
          '''
          INSERT INTO stocktaking_items
            (session_id, product_id, product_name, product_code, unit_name,
             available_qty, counted_qty, price, total)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            sessionId,
            line.productId,
            line.name,
            line.code,
            line.unit,
            available,
            line.qty,
            line.price,
            line.qty * line.price,
          ],
        );
        if (!applyStock || line.productId == null) continue;
        if (difference == 0) continue;
        _db.execute(
          'UPDATE products SET current_stock = current_stock + ?, updated_at = ? WHERE id = ?',
          [difference, now, line.productId],
        );
        _db.insert(
          '''
          INSERT INTO stock_movements
            (product_id, quantity, movement_type, reference_id,
             reference_type, from_warehouse_id, movement_date, notes)
          VALUES (?, ?, ?, ?, 'stocktaking_session', ?, ?, ?)
          ''',
          [
            line.productId,
            difference,
            AppConstants.movementStocktaking,
            sessionId,
            warehouseId,
            now,
            'جرد مخزن - مستند $sessionNumber',
          ],
        );
      }

      _db.execute(
        '''
        UPDATE stocktaking_sessions
        SET session_number = ?, warehouse_id = ?, total = ?, items_count = ?,
            applied = ?, notes = ?, updated_at = ?
        WHERE id = ?
        ''',
        [
          sessionNumber,
          warehouseId,
          total,
          lines.length,
          applyStock ? 1 : 0,
          notes.isEmpty ? null : notes,
          now,
          sessionId,
        ],
      );
      _db.execute(
        "DELETE FROM document_custom_values WHERE document_type='stocktaking' "
        'AND document_id = ?',
        [sessionId],
      );
      DocumentCustomFields.saveValues(
        DocumentTypes.stocktaking,
        sessionId,
        customFields,
      );

      return StocktakingSaveResult(
        sessionId: sessionId,
        sessionNumber: sessionNumber,
        total: total,
        itemsCount: lines.length,
        changedCount: changed,
        applied: applyStock,
      );
    });
  }

  static String _editTime(DateTime? value) {
    if (value == null) return '';
    final hour = (value.hour % 12 == 0 ? 12 : value.hour % 12)
        .toString()
        .padLeft(2, '0');
    return '$hour:${value.minute.toString().padLeft(2, '0')} '
        '${value.hour < 12 ? 'AM' : 'PM'}';
  }

  // ---------------------------------------------------------------------------
  // Internals.
  // ---------------------------------------------------------------------------

  StocktakingProduct _rowToProduct(Map<String, dynamic> r) {
    return StocktakingProduct(
      id: r['id'] as int,
      name: (r['name'] as String?) ?? '',
      code: (r['product_code'] as String?) ?? '',
      barcode: r['barcode'] as String?,
      unitName: (r['unit_name'] as String?) ?? '',
      available: (r['current_stock'] as int?) ?? 0,
      purchasePrice: (r['purchase_price'] as int?) ?? 0,
      sellingPrice: (r['selling_price'] as int?) ?? 0,
    );
  }

  int _stockForWarehouse(int productId, int? warehouseId) {
    if (warehouseId == null) {
      final rows = _db.query(
        'SELECT current_stock FROM products WHERE id = ?',
        [productId],
      );
      return rows.isEmpty
          ? 0
          : ((rows.first['current_stock'] as num?)?.toInt() ?? 0);
    }
    return WarehouseStock.quantityInWarehouse(_db, productId, warehouseId);
  }

  void _validateUniqueProducts(Iterable<int?> productIds) {
    final seen = <int>{};
    for (final productId in productIds) {
      if (productId != null && !seen.add(productId)) {
        throw StocktakingValidationException(
          'لا يمكن تكرار الصنف نفسه في أكثر من سطر في مستند الجرد.',
        );
      }
    }
  }

  static String _escapeLike(String value) {
    return value
        .replaceAll('\\', '\\\\')
        .replaceAll('%', '\\%')
        .replaceAll('_', '\\_');
  }
}
