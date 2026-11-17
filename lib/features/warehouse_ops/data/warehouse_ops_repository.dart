import 'package:inventory_app/core/database/sqlite_database.dart';
import 'package:inventory_app/core/services/document_custom_fields.dart';
import 'package:inventory_app/core/services/warehouse_stock.dart';
import 'package:inventory_app/core/utils/constants.dart';
import 'package:inventory_app/features/stocktaking/data/stocktaking_repository.dart';
import 'package:inventory_app/features/warehouse_ops/domain/warehouse_op_models.dart';

/// Data access for تسوية مخزن and تحويل لمخزن.
///
/// The product / warehouse catalogue is read through the stocktaking
/// repository because it is pure read-only data; every write, every document
/// table and every stock movement below belongs to that document alone.
class WarehouseOpsRepository {
  WarehouseOpsRepository() : this.withDatabase(SqliteDatabase());

  WarehouseOpsRepository.withDatabase(SqliteDatabase database)
    : _db = database,
      _catalogue = StocktakingRepository.withDatabase(database);

  final SqliteDatabase _db;

  /// Read-only catalogue shared with جرد مخزن.
  final StocktakingRepository _catalogue;

  static final RegExp _digits = RegExp(r'\d+');

  // ---------------------------------------------------------------------------
  // Catalogue.
  // ---------------------------------------------------------------------------
  Future<List<WarehouseOpProduct>> searchProducts(
    String term, {
    int limit = 60,
  }) => _catalogue.searchProducts(term, limit: limit);

  Future<WarehouseOpProduct?> findByBarcode(String code) =>
      _catalogue.findByBarcode(code);

  Future<List<WarehouseOpProduct>> listProducts({int? categoryId}) =>
      _catalogue.listProducts(categoryId: categoryId);

  Future<List<Map<String, Object?>>> getCategories() =>
      _catalogue.getCategories();

  Future<List<WarehouseOpWarehouse>> getWarehouses() =>
      _catalogue.getWarehouses();

  /// Current quantity in one selected warehouse, or the global total when
  /// no warehouse is selected in a legacy single-warehouse database.
  int stockForWarehouse(int productId, int? warehouseId) =>
      _stockForWarehouse(productId, warehouseId);

  // ---------------------------------------------------------------------------
  // Numbering — each document type has its own sequence.
  // ---------------------------------------------------------------------------
  String _sessionsTable(WarehouseOpKind kind) =>
      kind == WarehouseOpKind.adjustment
      ? 'stock_adjustment_sessions'
      : 'stock_transfer_sessions';

  String nextSessionNumber(WarehouseOpKind kind) {
    final rows = _db.query(
      'SELECT session_number FROM ${_sessionsTable(kind)} '
      'ORDER BY id DESC LIMIT 1',
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

  /// Persist a تسوية مخزن document in one transaction.
  ///
  /// When [applyStock] is true every line whose adjusted quantity differs from
  /// the recorded quantity updates `products.current_stock` and writes one
  /// `adjustment` stock movement.
  Future<WarehouseOpSaveResult> saveAdjustment({
    required int? warehouseId,
    required String sessionNumber,
    required List<WarehouseOpLine> lines,
    required String notes,
    required bool applyStock,
    Map<int, String> customFields = const {},
  }) async {
    _validateCommon(lines);
    _assertNumberFree(WarehouseOpKind.adjustment, sessionNumber);
    final total = lines.fold<int>(0, (sum, line) => sum + line.gross);
    var changed = 0;

    return _db.transaction<WarehouseOpSaveResult>(() async {
      final now = DateTime.now().toIso8601String();
      final sessionId = _db.insert(
        '''
        INSERT INTO stock_adjustment_sessions
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
          INSERT INTO stock_adjustment_items
            (session_id, product_id, product_name, product_code, unit_name,
             available_qty, adjusted_qty, difference, price, total)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            sessionId,
            line.productId,
            line.name,
            line.code,
            line.unit,
            available,
            line.qty,
            difference,
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
          VALUES (?, ?, ?, ?, 'stock_adjustment', ?, ?, ?)
          ''',
          [
            line.productId,
            difference,
            AppConstants.movementAdjustment,
            sessionId,
            warehouseId,
            now,
            'تسوية مخزن - مستند $sessionNumber',
          ],
        );
      }

      DocumentCustomFields.saveValues(
        DocumentTypes.warehouseAdjustment,
        sessionId,
        customFields,
      );

      return WarehouseOpSaveResult(
        sessionId: sessionId,
        sessionNumber: sessionNumber,
        total: total,
        itemsCount: lines.length,
        changedCount: changed,
        applied: applyStock,
      );
    });
  }

  /// Persist a تحويل لمخزن document in one transaction.
  ///
  /// A transfer never changes the total inventory: when [applyStock] is true
  /// it writes one `transfer_out` and one `transfer_in` movement per line with
  /// the source and destination warehouses. `products.current_stock` stays the
  /// same because the goods only move between warehouses.
  Future<WarehouseOpSaveResult> saveTransfer({
    required int? fromWarehouseId,
    required int? toWarehouseId,
    required String sessionNumber,
    required List<WarehouseOpLine> lines,
    required String notes,
    required bool applyStock,
    Map<int, String> customFields = const {},
  }) async {
    _validateCommon(lines);
    _assertNumberFree(WarehouseOpKind.transfer, sessionNumber);
    for (final line in lines) {
      if (line.qty <= 0) {
        throw WarehouseOpValidationException(
          'كمية التحويل يجب أن تكون أكبر من صفر في السطر «${line.name}».',
        );
      }
    }
    if (applyStock) {
      if (fromWarehouseId == null || toWarehouseId == null) {
        throw WarehouseOpValidationException(
          'لا توجد مخازن كافية للتحويل — احفظ مخزنين على الأقل ثم اختر '
          'مخزن المصدر ومخزن الوجهة.',
        );
      }
      if (fromWarehouseId == toWarehouseId) {
        throw WarehouseOpValidationException(
          'اختر مخزن مصدر ومخزن وجهة مختلفين قبل التحويل.',
        );
      }
    }

    final total = lines.fold<int>(0, (sum, line) => sum + line.gross);
    final changed = lines.where((line) => line.qty != 0).length;

    return _db.transaction<WarehouseOpSaveResult>(() async {
      if (applyStock) _validateTransferStock(lines, fromWarehouseId);
      final now = DateTime.now().toIso8601String();
      final sessionId = _db.insert(
        '''
        INSERT INTO stock_transfer_sessions
          (session_number, from_warehouse_id, to_warehouse_id, session_date,
           total, items_count, applied, notes, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          sessionNumber,
          fromWarehouseId,
          toWarehouseId,
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
        _db.insert(
          '''
          INSERT INTO stock_transfer_items
            (session_id, product_id, product_name, product_code, unit_name,
             available_qty, transfer_qty, price, total)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            sessionId,
            line.productId,
            line.name,
            line.code,
            line.unit,
            line.productId == null
                ? line.available
                : _stockForWarehouse(line.productId!, fromWarehouseId),
            line.qty,
            line.price,
            line.gross,
          ],
        );

        if (!applyStock || line.productId == null) continue;

        for (final movement in [
          (
            type: AppConstants.movementTransferOut,
            from: fromWarehouseId,
            to: null,
          ),
          (
            type: AppConstants.movementTransferIn,
            from: null,
            to: toWarehouseId,
          ),
        ]) {
          _db.insert(
            '''
            INSERT INTO stock_movements
              (product_id, quantity, movement_type, reference_id,
               reference_type, from_warehouse_id, to_warehouse_id,
               movement_date, notes)
            VALUES (?, ?, ?, ?, 'stock_transfer', ?, ?, ?, ?)
            ''',
            [
              line.productId,
              line.qty,
              movement.type,
              sessionId,
              movement.from,
              movement.to,
              now,
              'تحويل مخزن - مستند $sessionNumber',
            ],
          );
        }
      }

      DocumentCustomFields.saveValues(
        DocumentTypes.warehouseTransfer,
        sessionId,
        customFields,
      );

      return WarehouseOpSaveResult(
        sessionId: sessionId,
        sessionNumber: sessionNumber,
        total: total,
        itemsCount: lines.length,
        changedCount: changed,
        applied: applyStock,
      );
    });
  }

  void _validateCommon(List<WarehouseOpLine> lines) {
    if (lines.isEmpty) {
      throw WarehouseOpValidationException(
        'أضف صنفاً واحداً على الأقل قبل الحفظ.',
      );
    }
    final seenProducts = <int>{};
    for (final line in lines) {
      if (line.productId != null && !seenProducts.add(line.productId!)) {
        throw WarehouseOpValidationException(
          'لا يمكن تكرار الصنف نفسه في أكثر من سطر في المستند.',
        );
      }
      if (line.qty < 0) {
        throw WarehouseOpValidationException(
          'الكمية لا يمكن أن تكون سالبة في السطر «${line.name}».',
        );
      }
      if (line.price < 0) {
        throw WarehouseOpValidationException(
          'السعر لا يمكن أن يكون سالباً في السطر «${line.name}».',
        );
      }
    }
  }

  void _validateTransferStock(
    List<WarehouseOpLine> lines,
    int? fromWarehouseId,
  ) {
    final requestedByProduct = <int, int>{};
    final nameByProduct = <int, String>{};
    for (final line in lines) {
      final productId = line.productId;
      if (productId == null) continue;
      requestedByProduct.update(
        productId,
        (quantity) => quantity + line.qty,
        ifAbsent: () => line.qty,
      );
      nameByProduct[productId] = line.name;
    }
    for (final entry in requestedByProduct.entries) {
      final available = _stockForWarehouse(entry.key, fromWarehouseId);
      if (entry.value > available) {
        throw WarehouseOpValidationException(
          'الكمية المطلوبة أكبر من المتاح في مخزن المصدر للصنف '
          '«${nameByProduct[entry.key] ?? ''}» (المتاح: $available).',
        );
      }
    }
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

  /// Editing a posted transfer removes and rebuilds its ledger rows. Protect
  /// the old destination balance from going negative when later documents have
  /// already consumed stock received by this transfer.
  void _validateTransferUpdateReversal({
    required int sessionId,
    required int? newDestinationId,
    required List<WarehouseOpLine> newLines,
  }) {
    final sessions = _db.query(
      'SELECT to_warehouse_id, applied FROM stock_transfer_sessions WHERE id=?',
      [sessionId],
    );
    if (sessions.isEmpty ||
        ((sessions.first['applied'] as num?)?.toInt() ?? 0) != 1) {
      return;
    }

    final oldDestinationId = (sessions.first['to_warehouse_id'] as num?)
        ?.toInt();
    final keepsDestination =
        newDestinationId != null && newDestinationId == oldDestinationId;
    final newQuantityByProduct = <int, int>{};
    if (keepsDestination) {
      for (final line in newLines) {
        final productId = line.productId;
        if (productId == null) continue;
        newQuantityByProduct.update(
          productId,
          (quantity) => quantity + line.qty,
          ifAbsent: () => line.qty,
        );
      }
    }

    final oldQuantityByProduct = <int, int>{};
    for (final item in _db.query(
      'SELECT product_id, transfer_qty FROM stock_transfer_items WHERE session_id=?',
      [sessionId],
    )) {
      final productId = (item['product_id'] as num?)?.toInt();
      if (productId == null) continue;
      final quantity = (item['transfer_qty'] as num?)?.toInt() ?? 0;
      oldQuantityByProduct.update(
        productId,
        (current) => current + quantity,
        ifAbsent: () => quantity,
      );
    }

    for (final entry in oldQuantityByProduct.entries) {
      final newQuantity = newQuantityByProduct[entry.key] ?? 0;
      final quantityToReverse = keepsDestination
          ? (entry.value - newQuantity).clamp(0, entry.value)
          : entry.value;
      if (quantityToReverse == 0) continue;
      final available = _stockForWarehouse(entry.key, oldDestinationId);
      if (available < quantityToReverse) {
        throw WarehouseOpValidationException(
          'لا يمكن تعديل مستند التحويل لأن بعض الكمية استُخدمت من مخزن الوجهة. '
          'انقل الكمية إلى المخزن أولاً ثم أعد المحاولة.',
        );
      }
    }
  }

  /// The document numbers are unique per document type; tell the operator
  /// before the INSERT fails with a raw SQLite constraint error.
  void _assertNumberFree(WarehouseOpKind kind, String number) {
    final rows = _db.query(
      'SELECT 1 FROM ${_sessionsTable(kind)} '
      'WHERE session_number = ? LIMIT 1',
      [number],
    );
    if (rows.isNotEmpty) {
      throw WarehouseOpValidationException(
        'رقم ${kind.documentName} «$number» مستخدم بالفعل — اكتب رقماً آخر.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Print / export lookups.
  // ---------------------------------------------------------------------------
  Future<Map<String, Object?>?> getSession(
    WarehouseOpKind kind,
    int sessionId,
  ) async {
    final table = _sessionsTable(kind);
    final rows = _db.query(
      '''
      SELECT s.*,
             wf.name AS from_warehouse_name,
             wt.name AS to_warehouse_name
      FROM $table s
      LEFT JOIN warehouses wf
        ON wf.id = s.${kind == WarehouseOpKind.transfer ? 'from_warehouse_id' : 'warehouse_id'}
      LEFT JOIN warehouses wt
        ON wt.id = s.${kind == WarehouseOpKind.transfer ? 'to_warehouse_id' : 'warehouse_id'}
      WHERE s.id = ?
      ''',
      [sessionId],
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, Object?>>> getSessionItems(
    WarehouseOpKind kind,
    int sessionId,
  ) async {
    final itemsTable = kind == WarehouseOpKind.adjustment
        ? 'stock_adjustment_items'
        : 'stock_transfer_items';
    return _db.query(
      'SELECT * FROM $itemsTable WHERE session_id = ? ORDER BY id',
      [sessionId],
    );
  }

  // ---------------------------------------------------------------------------
  // Edit.
  // ---------------------------------------------------------------------------

  /// Load a saved adjustment / transfer for the edit screen.
  Future<WarehouseOpEditData?> loadSessionForEdit(
    WarehouseOpKind kind,
    int sessionId,
  ) async {
    final header = await getSession(kind, sessionId);
    if (header == null) return null;
    final items = await getSessionItems(kind, sessionId);
    final movementByProduct = <int, int>{};
    if (kind == WarehouseOpKind.adjustment) {
      for (final row in _db.query(
        'SELECT product_id, quantity FROM stock_movements '
        "WHERE reference_type = 'stock_adjustment' AND reference_id = ?",
        [sessionId],
      )) {
        final productId = (row['product_id'] as num?)?.toInt();
        if (productId != null) {
          movementByProduct[productId] =
              (movementByProduct[productId] ?? 0) +
              ((row['quantity'] as num?)?.toInt() ?? 0);
        }
      }
    }
    final sessionWarehouseId = (header['warehouse_id'] as num?)?.toInt();
    final sessionFromWarehouseId = (header['from_warehouse_id'] as num?)
        ?.toInt();
    final transferOutByProduct = <int, int>{};
    if (kind == WarehouseOpKind.transfer) {
      for (final row in _db.query(
        'SELECT product_id, quantity FROM stock_movements '
        "WHERE reference_type = 'stock_transfer' AND reference_id = ? "
        "AND movement_type = 'transfer_out'",
        [sessionId],
      )) {
        final productId = (row['product_id'] as num?)?.toInt();
        if (productId != null) {
          transferOutByProduct[productId] =
              (transferOutByProduct[productId] ?? 0) +
              ((row['quantity'] as num?)?.toInt() ?? 0);
        }
      }
    }
    final lines = <WarehouseOpEditLine>[];
    for (final item in items) {
      final productId = (item['product_id'] as num?)?.toInt();
      var available = (item['available_qty'] as num?)?.toInt() ?? 0;
      final qty = kind == WarehouseOpKind.adjustment
          ? (item['adjusted_qty'] as num?)?.toInt() ?? 0
          : (item['transfer_qty'] as num?)?.toInt() ?? 0;
      if (productId != null) {
        available = kind == WarehouseOpKind.adjustment
            ? _stockForWarehouse(productId, sessionWarehouseId) -
                  (movementByProduct[productId] ?? 0)
            : _stockForWarehouse(productId, sessionFromWarehouseId) +
                  (transferOutByProduct[productId] ?? 0);
      }
      lines.add(
        WarehouseOpEditLine(
          productId: productId,
          name: '${item['product_name'] ?? ''}',
          code: '${item['product_code'] ?? ''}',
          unit: '${item['unit_name'] ?? ''}'.trim().isEmpty
              ? 'حبة'
              : '${item['unit_name']}',
          available: available,
          qty: qty,
          price: (item['price'] as num?)?.toInt() ?? 0,
        ),
      );
    }
    final parsed = DateTime.tryParse('${header['session_date'] ?? ''}');
    return WarehouseOpEditData(
      id: sessionId,
      number: '${header['session_number'] ?? ''}',
      warehouseId: (header['warehouse_id'] as num?)?.toInt(),
      fromWarehouseId: (header['from_warehouse_id'] as num?)?.toInt(),
      toWarehouseId: (header['to_warehouse_id'] as num?)?.toInt(),
      date: parsed,
      time: _editTime(parsed),
      notes: '${header['notes'] ?? ''}',
      applied: ((header['applied'] as num?)?.toInt() ?? 0) == 1,
      lines: lines,
      customFields: DocumentCustomFields.values(
        kind == WarehouseOpKind.adjustment
            ? DocumentTypes.warehouseAdjustment
            : DocumentTypes.warehouseTransfer,
        sessionId,
      ),
    );
  }

  /// Update a saved تسوية مخزن in place, reversing the old movements first.
  Future<WarehouseOpSaveResult> updateAdjustment({
    required int sessionId,
    required int? warehouseId,
    required String sessionNumber,
    required List<WarehouseOpLine> lines,
    required String notes,
    required bool applyStock,
    Map<int, String> customFields = const {},
  }) async {
    _validateCommon(lines);
    _assertNumberFreeExcept(
      WarehouseOpKind.adjustment,
      sessionNumber,
      sessionId,
    );
    var changed = 0;
    return _db.transaction<WarehouseOpSaveResult>(() async {
      final rows = _db.query(
        'SELECT applied FROM stock_adjustment_sessions WHERE id = ?',
        [sessionId],
      );
      if (rows.isEmpty) {
        throw WarehouseOpValidationException('مستند التسوية غير موجود.');
      }
      final wasApplied = ((rows.first['applied'] as num?)?.toInt() ?? 0) == 1;
      final now = DateTime.now().toIso8601String();
      if (wasApplied) {
        for (final movement in _db.query(
          'SELECT product_id, quantity, from_warehouse_id FROM stock_movements '
          "WHERE reference_type = 'stock_adjustment' AND reference_id = ?",
          [sessionId],
        )) {
          final productId = (movement['product_id'] as num?)?.toInt();
          final quantity = (movement['quantity'] as num?)?.toInt() ?? 0;
          if (productId == null) continue;
          if (quantity > 0) {
            final movementWarehouseId = (movement['from_warehouse_id'] as num?)
                ?.toInt();
            final stock = _stockForWarehouse(productId, movementWarehouseId);
            if (stock < quantity) {
              throw WarehouseOpValidationException(
                'لا يمكن تعديل مستند التسوية لأن بعض الكميات استُخدمت في '
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
        "DELETE FROM stock_movements WHERE reference_type = 'stock_adjustment' "
        'AND reference_id = ?',
        [sessionId],
      );
      _db.execute('DELETE FROM stock_adjustment_items WHERE session_id = ?', [
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
          INSERT INTO stock_adjustment_items
            (session_id, product_id, product_name, product_code, unit_name,
             available_qty, adjusted_qty, difference, price, total)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            sessionId,
            line.productId,
            line.name,
            line.code,
            line.unit,
            available,
            line.qty,
            difference,
            line.price,
            line.qty * line.price,
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
          VALUES (?, ?, ?, ?, 'stock_adjustment', ?, ?, ?)
          ''',
          [
            line.productId,
            difference,
            AppConstants.movementAdjustment,
            sessionId,
            warehouseId,
            now,
            'تسوية مخزن - مستند $sessionNumber',
          ],
        );
      }
      _db.execute(
        '''
        UPDATE stock_adjustment_sessions
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
        "DELETE FROM document_custom_values "
        "WHERE document_type='warehouse_adjustment' AND document_id = ?",
        [sessionId],
      );
      DocumentCustomFields.saveValues(
        DocumentTypes.warehouseAdjustment,
        sessionId,
        customFields,
      );
      return WarehouseOpSaveResult(
        sessionId: sessionId,
        sessionNumber: sessionNumber,
        total: total,
        itemsCount: lines.length,
        changedCount: changed,
        applied: applyStock,
      );
    });
  }

  /// Update a saved تحويل لمخزن in place. Transfers never change the global
  /// inventory, so only the movement rows are rebuilt.
  Future<WarehouseOpSaveResult> updateTransfer({
    required int sessionId,
    required int? fromWarehouseId,
    required int? toWarehouseId,
    required String sessionNumber,
    required List<WarehouseOpLine> lines,
    required String notes,
    required bool applyStock,
    Map<int, String> customFields = const {},
  }) async {
    _validateCommon(lines);
    _assertNumberFreeExcept(WarehouseOpKind.transfer, sessionNumber, sessionId);
    for (final line in lines) {
      if (line.qty <= 0) {
        throw WarehouseOpValidationException(
          'كمية التحويل يجب أن تكون أكبر من صفر في السطر «${line.name}».',
        );
      }
    }
    if (applyStock) {
      if (fromWarehouseId == null || toWarehouseId == null) {
        throw WarehouseOpValidationException(
          'لا توجد مخازن كافية للتحويل — احفظ مخزنين على الأقل ثم اختر '
          'مخزن المصدر ومخزن الوجهة.',
        );
      }
      if (fromWarehouseId == toWarehouseId) {
        throw WarehouseOpValidationException(
          'اختر مخزن مصدر ومخزن وجهة مختلفين قبل التحويل.',
        );
      }
    }
    final changed = lines.where((line) => line.qty != 0).length;
    return _db.transaction<WarehouseOpSaveResult>(() async {
      final rows = _db.query(
        'SELECT id FROM stock_transfer_sessions WHERE id = ?',
        [sessionId],
      );
      if (rows.isEmpty) {
        throw WarehouseOpValidationException('مستند التحويل غير موجود.');
      }
      _validateTransferUpdateReversal(
        sessionId: sessionId,
        newDestinationId: applyStock ? toWarehouseId : null,
        newLines: lines,
      );
      final now = DateTime.now().toIso8601String();
      _db.execute(
        "DELETE FROM stock_movements WHERE reference_type = 'stock_transfer' "
        'AND reference_id = ?',
        [sessionId],
      );
      if (applyStock) _validateTransferStock(lines, fromWarehouseId);
      _db.execute('DELETE FROM stock_transfer_items WHERE session_id = ?', [
        sessionId,
      ]);
      var total = 0;
      for (final line in lines) {
        total += line.qty * line.price;
        _db.insert(
          '''
          INSERT INTO stock_transfer_items
            (session_id, product_id, product_name, product_code, unit_name,
             available_qty, transfer_qty, price, total)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            sessionId,
            line.productId,
            line.name,
            line.code,
            line.unit,
            line.productId == null
                ? line.available
                : _stockForWarehouse(line.productId!, fromWarehouseId),
            line.qty,
            line.price,
            line.qty * line.price,
          ],
        );
        if (!applyStock || line.productId == null) continue;
        for (final movement in [
          (
            type: AppConstants.movementTransferOut,
            from: fromWarehouseId,
            to: null,
          ),
          (
            type: AppConstants.movementTransferIn,
            from: null,
            to: toWarehouseId,
          ),
        ]) {
          _db.insert(
            '''
            INSERT INTO stock_movements
              (product_id, quantity, movement_type, reference_id,
               reference_type, from_warehouse_id, to_warehouse_id,
               movement_date, notes)
            VALUES (?, ?, ?, ?, 'stock_transfer', ?, ?, ?, ?)
            ''',
            [
              line.productId,
              line.qty,
              movement.type,
              sessionId,
              movement.from,
              movement.to,
              now,
              'تحويل مخزن - مستند $sessionNumber',
            ],
          );
        }
      }
      _db.execute(
        '''
        UPDATE stock_transfer_sessions
        SET session_number = ?, from_warehouse_id = ?, to_warehouse_id = ?,
            total = ?, items_count = ?, applied = ?, notes = ?, updated_at = ?
        WHERE id = ?
        ''',
        [
          sessionNumber,
          fromWarehouseId,
          toWarehouseId,
          total,
          lines.length,
          applyStock ? 1 : 0,
          notes.isEmpty ? null : notes,
          now,
          sessionId,
        ],
      );
      _db.execute(
        "DELETE FROM document_custom_values "
        "WHERE document_type='warehouse_transfer' AND document_id = ?",
        [sessionId],
      );
      DocumentCustomFields.saveValues(
        DocumentTypes.warehouseTransfer,
        sessionId,
        customFields,
      );
      return WarehouseOpSaveResult(
        sessionId: sessionId,
        sessionNumber: sessionNumber,
        total: total,
        itemsCount: lines.length,
        changedCount: changed,
        applied: applyStock,
      );
    });
  }

  void _assertNumberFreeExcept(
    WarehouseOpKind kind,
    String number,
    int sessionId,
  ) {
    final rows = _db.query(
      'SELECT 1 FROM ${_sessionsTable(kind)} '
      'WHERE session_number = ? AND id <> ? LIMIT 1',
      [number, sessionId],
    );
    if (rows.isNotEmpty) {
      throw WarehouseOpValidationException(
        'رقم ${kind.documentName} «$number» مستخدم بالفعل — اكتب رقماً آخر.',
      );
    }
  }

  static String _editTime(DateTime? value) {
    if (value == null) return '';
    final hour = (value.hour % 12 == 0 ? 12 : value.hour % 12)
        .toString()
        .padLeft(2, '0');
    return '$hour:${value.minute.toString().padLeft(2, '0')} '
        '${value.hour < 12 ? 'AM' : 'PM'}';
  }
}
