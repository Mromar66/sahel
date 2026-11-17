import 'package:sqlite3/sqlite3.dart';

import 'package:inventory_app/core/database/sqlite_database.dart';
import 'package:inventory_app/core/services/warehouse_stock.dart';
import 'package:inventory_app/features/invoices/domain/invoice_archive_models.dart';

/// Data access for the الفواتير document archive.
///
/// Every tab reads its own real document family. No shadow table and no
/// `UNION` is used, so a filter never mixes unrelated schemas. The optional
/// [database] argument exists so the filtering and deletion rules can be
/// exercised against an isolated in-memory database in tests.
class InvoiceArchiveRepository {
  InvoiceArchiveRepository({Database? database})
    : _db = database ?? SqliteDatabase().db;

  final Database _db;

  // ---------------------------------------------------------------------------
  // Lookups.
  // ---------------------------------------------------------------------------
  List<ArchiveOption> warehouses() =>
      _options('SELECT id,name FROM warehouses ORDER BY sort_order,id');

  List<ArchiveOption> accounts() =>
      _options('SELECT id,name FROM accounts WHERE is_active=1 ORDER BY name');

  List<ArchiveOption> treasuries() =>
      _options('SELECT id,name FROM treasuries WHERE is_active=1 ORDER BY id');

  List<ArchiveOption> categories() =>
      _options('SELECT id,name FROM categories ORDER BY name');

  List<ArchiveOption> users() => _options(
    'SELECT id,display_name AS name FROM program_users '
    'WHERE is_active=1 ORDER BY sort_order,id',
  );

  /// The current schema has no invoice -> sales representative relationship.
  List<ArchiveOption> salesReps() => const [];

  List<ArchiveStringOption> accountTypes() {
    const labels = {'customer': 'عميل', 'supplier': 'مورد'};
    final rows = _db.select(
      "SELECT DISTINCT account_type FROM accounts WHERE account_type <> '' "
      'ORDER BY account_type',
    );
    return [
      for (final row in rows)
        ArchiveStringOption(
          '${row['account_type']}',
          labels['${row['account_type']}'] ?? '${row['account_type']}',
        ),
    ];
  }

  List<ArchiveStringOption> paymentMethods() => [
    for (final row in _db.select(
      'SELECT code,name FROM payment_methods WHERE is_active=1 '
      'ORDER BY sort_order,id',
    ))
      ArchiveStringOption('${row['code']}', '${row['name']}'),
  ];

  List<ArchiveOption> _options(String sql) => [
    for (final row in _db.select(sql))
      ArchiveOption((row['id'] as num).toInt(), '${row['name'] ?? ''}'),
  ];

  // ---------------------------------------------------------------------------
  // Validation.
  // ---------------------------------------------------------------------------

  /// Returns an Arabic message when a filter cannot be applied truthfully to
  /// [type], or when a numeric/date range is inverted.
  String? validateFilters(ArchiveDocType type, ArchiveFilters filters) {
    final rangeError = filters.validate();
    if (rangeError != null) return rangeError;
    final spec = _spec(type);
    if (filters.warehouseId != null && !spec.supportsWarehouse) {
      return 'فلتر المخزن غير متاح لهذا النوع: المستند لا يسجل مخزناً.';
    }
    if ((filters.accountId != null || filters.accountType.isNotEmpty) &&
        !spec.supportsAccount) {
      return 'فلتر الحساب غير متاح لهذا النوع: المستند لا يسجل حساباً.';
    }
    if (filters.treasuryId != null && !spec.supportsTreasury) {
      return 'فلتر الخزينة غير متاح لهذا النوع: المستند لا يسجل حركة خزينة.';
    }
    if (filters.paymentMethod != 'all' && !spec.supportsPaymentMethod) {
      return 'فلتر طريقة السداد غير متاح لهذا النوع.';
    }
    if (filters.paymentStatus != 'all' && !spec.supportsPaymentStatus) {
      return 'فلتر حالة السداد غير متاح لهذا النوع.';
    }
    if (!spec.usesItems &&
        (filters.itemName.trim().isNotEmpty ||
            filters.itemCode.trim().isNotEmpty ||
            filters.barcode.trim().isNotEmpty ||
            filters.categoryId != null)) {
      return 'البحث بالأصناف غير متاح لهذا النوع: المستند لا يحتوي سطور أصناف.';
    }
    if (filters.userId != null) {
      return 'فلتر المستخدم غير متاح: المستندات الحالية لا تسجل منشئها.';
    }
    if (filters.salesRepId != null) {
      return 'فلتر مندوب البيع غير متاح: المستندات الحالية لا تسجل مندوباً.';
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Document search.
  // ---------------------------------------------------------------------------
  Future<ArchiveDocumentPage> searchDocuments({
    required ArchiveDocType type,
    required ArchiveFilters filters,
    ArchiveSort sort = const ArchiveSort(),
    int limit = 100,
    int offset = 0,
  }) async {
    final spec = _spec(type);
    final where = _documentWhere(type, spec, filters);
    final rows = _db.select(
      'SELECT ${_documentSelect(spec)} FROM ${spec.from} '
      'WHERE ${where.sql} ORDER BY ${_documentOrder(spec, sort)} '
      'LIMIT ? OFFSET ?',
      [...where.params, limit, offset],
    );
    final totalsRow = _db
        .select(
          'SELECT COUNT(*) AS c, '
          'COALESCE(SUM(${spec.total}),0) AS total, '
          'COALESCE(SUM(${spec.discount}),0) AS discount, '
          'COALESCE(SUM(${spec.tax}),0) AS tax, '
          'COALESCE(SUM(${spec.paid}),0) AS paid, '
          'COALESCE(SUM(${spec.remaining}),0) AS remaining '
          'FROM ${spec.from} WHERE ${where.sql}',
          where.params,
        )
        .first;
    final count = (totalsRow['c'] as num?)?.toInt() ?? 0;
    return ArchiveDocumentPage(
      rows: [for (final row in rows) _mapDocument(row, type)],
      totalCount: count,
      totals: ArchiveTotals(
        count: count,
        total: _int(totalsRow['total']),
        discount: _int(totalsRow['discount']),
        tax: _int(totalsRow['tax']),
        paid: _int(totalsRow['paid']),
        remaining: _int(totalsRow['remaining']),
      ),
      hasMore: offset + rows.length < count,
    );
  }

  // ---------------------------------------------------------------------------
  // Item search.
  // ---------------------------------------------------------------------------
  Future<ArchiveItemPage> searchItems({
    required ArchiveDocType type,
    required ArchiveFilters filters,
    ArchiveItemSort sort = const ArchiveItemSort(),
    int limit = 100,
    int offset = 0,
  }) async {
    final spec = _spec(type);
    if (!spec.supportsItems) {
      return const ArchiveItemPage(
        rows: [],
        totalCount: 0,
        totals: ArchiveTotals(),
        hasMore: false,
      );
    }
    final where = _itemWhere(type, spec, filters);
    final rows = _db.select(
      'SELECT ${_itemSelect(spec)} FROM ${spec.itemsFrom} '
      'WHERE ${where.sql} ORDER BY ${_itemOrder(spec, sort)} '
      'LIMIT ? OFFSET ?',
      [...where.params, limit, offset],
    );
    final totalsRow = _db
        .select(
          'SELECT COUNT(*) AS c, '
          'COALESCE(SUM(${spec.itemTotal}),0) AS total, '
          'COALESCE(SUM(${spec.itemDiscount}),0) AS discount, '
          'COALESCE(SUM(${spec.itemQty}),0) AS quantity '
          'FROM ${spec.itemsFrom} WHERE ${where.sql}',
          where.params,
        )
        .first;
    final count = (totalsRow['c'] as num?)?.toInt() ?? 0;
    return ArchiveItemPage(
      rows: [for (final row in rows) _mapItem(row, type)],
      totalCount: count,
      totals: ArchiveTotals(
        count: count,
        total: _int(totalsRow['total']),
        discount: _int(totalsRow['discount']),
        quantity: _int(totalsRow['quantity']),
      ),
      hasMore: offset + rows.length < count,
    );
  }

  // ---------------------------------------------------------------------------
  // Loading one document for printing / editing.
  // ---------------------------------------------------------------------------
  Future<ArchiveDocumentDetail?> loadDocument(
    ArchiveDocType type,
    int documentId,
  ) async {
    final spec = _spec(type);
    final rows = _db.select(
      'SELECT ${_documentSelect(spec)} FROM ${spec.from} '
      'WHERE d.id = ? AND ${spec.baseWhere}',
      [documentId],
    );
    if (rows.isEmpty) return null;
    var items = <Map<String, Object?>>[];
    if (spec.supportsItems) {
      items = _db
          .select(
            'SELECT i.*, COALESCE(p.barcode,\'\') AS barcode, '
            'COALESCE(u.name,i.unit_name,\'\') AS unit_name '
            'FROM ${spec.itemsFrom} WHERE d.id = ? ORDER BY i.id',
            [documentId],
          )
          .map((row) => Map<String, Object?>.from(row))
          .toList();
    }
    return ArchiveDocumentDetail(
      type: type,
      header: Map<String, Object?>.from(rows.first),
      items: items,
    );
  }

  // ---------------------------------------------------------------------------
  // Deletion inside one database transaction.
  // ---------------------------------------------------------------------------
  Future<void> deleteDocument(ArchiveDocType type, int documentId) async {
    _db.execute('BEGIN IMMEDIATE');
    try {
      switch (type) {
        case ArchiveDocType.sale:
          _deleteSale(documentId);
        case ArchiveDocType.salesReturn:
          _deleteSalesReturn(documentId);
        case ArchiveDocType.quotation:
          _deleteQuotation(documentId);
        case ArchiveDocType.purchase:
          _deletePurchase(documentId);
        case ArchiveDocType.purchaseReturn:
          _deletePurchaseReturn(documentId);
        case ArchiveDocType.receipt:
        case ArchiveDocType.payment:
          _deleteVoucher(type, documentId);
        case ArchiveDocType.stocktaking:
          _deleteStockSession(
            documentId: documentId,
            table: 'stocktaking_sessions',
            itemsTable: 'stocktaking_items',
            referenceType: 'stocktaking_session',
            customType: 'stocktaking',
            label: 'مستند الجرد',
          );
        case ArchiveDocType.adjustment:
          _deleteStockSession(
            documentId: documentId,
            table: 'stock_adjustment_sessions',
            itemsTable: 'stock_adjustment_items',
            referenceType: 'stock_adjustment',
            customType: 'warehouse_adjustment',
            label: 'مستند التسوية',
          );
        case ArchiveDocType.transfer:
          _deleteTransfer(documentId);
      }
      _db.execute('COMMIT');
    } catch (_) {
      try {
        _db.execute('ROLLBACK');
      } catch (_) {
        // SQLite may already have closed the transaction.
      }
      rethrow;
    }
  }

  void _deleteSale(int id) {
    final rows = _db.select(
      'SELECT invoice_number, is_return FROM sales_invoices WHERE id=?',
      [id],
    );
    if (rows.isEmpty) throw ArchiveException('المستند غير موجود.');
    if ((rows.first['is_return'] as int? ?? 0) == 1) {
      throw ArchiveException('هذا المستند مرتجع بيع وليس فاتورة بيع.');
    }
    final returns = _db.select(
      'SELECT COUNT(*) AS c FROM sales_invoices '
      'WHERE is_return=1 AND original_invoice_id=?',
      [id],
    );
    if ((returns.first['c'] as num? ?? 0) > 0) {
      throw ArchiveException(
        'لا يمكن حذف الفاتورة لأن عليها مرتجع بيع مسجل. احذف المرتجع أولاً.',
      );
    }
    final now = DateTime.now().toIso8601String();
    for (final item in _db.select(
      'SELECT product_id, quantity FROM sales_items WHERE invoice_id=?',
      [id],
    )) {
      final productId = (item['product_id'] as num?)?.toInt();
      if (productId == null) continue;
      _db.execute(
        'UPDATE products SET current_stock=current_stock+?, updated_at=? '
        'WHERE id=?',
        [_int(item['quantity']), now, productId],
      );
    }
    _db.execute(
      "DELETE FROM stock_movements WHERE reference_type='sales_invoice' "
      'AND reference_id=?',
      [id],
    );
    _reversePayments('sales_invoice', id);
    _db.execute(
      'UPDATE quotations SET status=\'open\', converted_invoice_id=NULL, '
      'updated_at=? WHERE converted_invoice_id=?',
      [now, id],
    );
    _deleteCustom('sale', id);
    _db.execute('DELETE FROM sales_items WHERE invoice_id=?', [id]);
    _db.execute('DELETE FROM sales_invoices WHERE id=?', [id]);
  }

  void _deleteSalesReturn(int id) {
    final rows = _db.select(
      'SELECT invoice_number, is_return FROM sales_invoices WHERE id=?',
      [id],
    );
    if (rows.isEmpty) throw ArchiveException('المستند غير موجود.');
    if ((rows.first['is_return'] as int? ?? 0) != 1) {
      throw ArchiveException('هذا المستند ليس مرتجع بيع.');
    }
    final now = DateTime.now().toIso8601String();
    final stockDatabase = SqliteDatabase.withDatabase(_db);
    final defaultWarehouseId = WarehouseStock.defaultWarehouseId(stockDatabase);
    final items = _db.select(
      'SELECT product_id, quantity FROM sales_items WHERE invoice_id=?',
      [id],
    );
    final movements = _db.select(
      "SELECT product_id, quantity, from_warehouse_id, to_warehouse_id "
      "FROM stock_movements WHERE reference_type='sales_return' AND reference_id=?",
      [id],
    );
    final reversalTotals = movements.isEmpty
        ? {
            for (final item in items)
              if ((item['product_id'] as num?) != null)
                ((item['product_id'] as num).toInt(), defaultWarehouseId): _int(
                  item['quantity'],
                ),
          }
        : _movementTotals(movements, defaultWarehouseId);
    _ensureReversalStock(reversalTotals, stockDatabase, 'مرتجع البيع');
    for (final item in items) {
      final productId = (item['product_id'] as num?)?.toInt();
      final qty = _int(item['quantity']);
      if (productId == null) continue;
      _db.execute(
        'UPDATE products SET current_stock=current_stock-?, updated_at=? '
        'WHERE id=?',
        [qty, now, productId],
      );
    }
    _db.execute(
      "DELETE FROM stock_movements WHERE reference_type='sales_return' "
      'AND reference_id=?',
      [id],
    );
    _reversePayments('sales_return', id);
    _deleteCustom('sales_return', id);
    _db.execute('DELETE FROM sales_items WHERE invoice_id=?', [id]);
    _db.execute('DELETE FROM sales_invoices WHERE id=?', [id]);
  }

  void _deleteQuotation(int id) {
    final rows = _db.select(
      'SELECT quote_number, converted_invoice_id FROM quotations WHERE id=?',
      [id],
    );
    if (rows.isEmpty) throw ArchiveException('المستند غير موجود.');
    if (rows.first['converted_invoice_id'] != null) {
      throw ArchiveException(
        'عرض السعر محوّل إلى فاتورة بيع ولا يمكن حذفه من الأرشيف.',
      );
    }
    _deleteCustom('quotation', id);
    _db.execute('DELETE FROM quotation_items WHERE quote_id=?', [id]);
    _db.execute('DELETE FROM quotations WHERE id=?', [id]);
  }

  void _deletePurchase(int id) {
    final rows = _db.select(
      'SELECT invoice_number FROM purchase_invoices WHERE id=?',
      [id],
    );
    if (rows.isEmpty) throw ArchiveException('المستند غير موجود.');
    final returns = _db.select(
      'SELECT COUNT(*) AS c FROM purchase_return_invoices '
      'WHERE original_invoice_id=?',
      [id],
    );
    if ((returns.first['c'] as num? ?? 0) > 0) {
      throw ArchiveException(
        'لا يمكن حذف فاتورة الشراء لأن عليها مرتجع شراء مسجل. '
        'احذف المرتجع أولاً.',
      );
    }
    final now = DateTime.now().toIso8601String();
    final stockDatabase = SqliteDatabase.withDatabase(_db);
    final defaultWarehouseId = WarehouseStock.defaultWarehouseId(stockDatabase);
    final items = _db.select(
      'SELECT product_id, quantity FROM purchase_items WHERE invoice_id=?',
      [id],
    );
    final movements = _db.select(
      "SELECT product_id, quantity, from_warehouse_id, to_warehouse_id "
      "FROM stock_movements WHERE reference_type='purchase_invoice' AND reference_id=?",
      [id],
    );
    final reversalTotals = movements.isEmpty
        ? {
            for (final item in items)
              if ((item['product_id'] as num?) != null)
                ((item['product_id'] as num).toInt(), defaultWarehouseId): _int(
                  item['quantity'],
                ),
          }
        : _movementTotals(movements, defaultWarehouseId);
    _ensureReversalStock(reversalTotals, stockDatabase, 'فاتورة الشراء');
    for (final item in items) {
      final productId = (item['product_id'] as num?)?.toInt();
      final qty = _int(item['quantity']);
      if (productId == null) continue;
      _db.execute(
        'UPDATE products SET current_stock=current_stock-?, updated_at=? '
        'WHERE id=?',
        [qty, now, productId],
      );
    }
    _db.execute(
      "DELETE FROM stock_movements WHERE reference_type='purchase_invoice' "
      'AND reference_id=?',
      [id],
    );
    _reversePayments('purchase_invoice', id);
    _deleteCustom('purchase', id);
    _db.execute('DELETE FROM purchase_items WHERE invoice_id=?', [id]);
    _db.execute('DELETE FROM purchase_invoices WHERE id=?', [id]);
  }

  void _deletePurchaseReturn(int id) {
    final rows = _db.select(
      'SELECT return_number FROM purchase_return_invoices WHERE id=?',
      [id],
    );
    if (rows.isEmpty) throw ArchiveException('المستند غير موجود.');
    final now = DateTime.now().toIso8601String();
    for (final item in _db.select(
      'SELECT product_id, quantity FROM purchase_return_items '
      'WHERE return_id=?',
      [id],
    )) {
      final productId = (item['product_id'] as num?)?.toInt();
      if (productId == null) continue;
      _db.execute(
        'UPDATE products SET current_stock=current_stock+?, updated_at=? '
        'WHERE id=?',
        [_int(item['quantity']), now, productId],
      );
    }
    _db.execute(
      "DELETE FROM stock_movements WHERE reference_type='purchase_return' "
      'AND reference_id=?',
      [id],
    );
    _reversePayments('purchase_return', id);
    _deleteCustom('purchase_return', id);
    _db.execute('DELETE FROM purchase_return_items WHERE return_id=?', [id]);
    _db.execute('DELETE FROM purchase_return_invoices WHERE id=?', [id]);
  }

  void _deleteVoucher(ArchiveDocType type, int id) {
    final rows = _db.select(
      'SELECT payment_type, reference_id, account_id, amount '
      'FROM payments WHERE id=?',
      [id],
    );
    if (rows.isEmpty) throw ArchiveException('المستند غير موجود.');
    final paymentType = '${rows.first['payment_type'] ?? ''}';
    if (rows.first['reference_id'] != null) {
      throw ArchiveException(
        'لا يمكن حذف دفعة مرتبطة بفاتورة من الأرشيف. احذف الفاتورة نفسها.',
      );
    }
    if ((type.isReceipt && paymentType != 'receipt') ||
        (type.isPayment && paymentType != 'payment')) {
      throw ArchiveException('نوع السند لا يطابق التبويب المحدد.');
    }
    final expenseRows = _db.select(
      'SELECT 1 FROM expenses WHERE payment_id=? LIMIT 1',
      [id],
    );
    if (expenseRows.isNotEmpty) {
      throw ArchiveException(
        'السند مرتبط بمصروف؛ احذف المصروف من شاشته أولاً.',
      );
    }
    final accountId = (rows.first['account_id'] as num?)?.toInt();
    final amount = _int(rows.first['amount']);
    if (accountId != null) {
      _db.execute(
        'UPDATE accounts SET balance=balance+?, updated_at=? WHERE id=?',
        [
          paymentType == 'receipt' ? amount : -amount,
          DateTime.now().toIso8601String(),
          accountId,
        ],
      );
    }
    final treasuryIds = <int>{};
    for (final movement in _db.select(
      'SELECT DISTINCT treasury_id FROM treasury_transactions '
      'WHERE reference_id=? AND reference_type IN (?, ?)',
      [id, 'receipt_voucher', 'payment_voucher'],
    )) {
      final treasuryId = (movement['treasury_id'] as num?)?.toInt();
      if (treasuryId != null) treasuryIds.add(treasuryId);
    }
    _db.execute(
      'DELETE FROM treasury_transactions WHERE reference_id=? '
      'AND reference_type IN (?, ?)',
      [id, 'receipt_voucher', 'payment_voucher'],
    );
    _db.execute('DELETE FROM account_checks WHERE payment_id=?', [id]);
    _deleteCustom(paymentType == 'receipt' ? 'receipt' : 'payment', id);
    _db.execute('DELETE FROM payments WHERE id=?', [id]);
    for (final treasuryId in treasuryIds) {
      _recalculateTreasury(treasuryId);
    }
  }

  void _deleteStockSession({
    required int documentId,
    required String table,
    required String itemsTable,
    required String referenceType,
    required String customType,
    required String label,
  }) {
    final rows = _db.select('SELECT applied FROM $table WHERE id=?', [
      documentId,
    ]);
    if (rows.isEmpty) throw ArchiveException('المستند غير موجود.');
    final applied = _int(rows.first['applied']) == 1;
    final now = DateTime.now().toIso8601String();
    if (applied) {
      final stockDatabase = SqliteDatabase.withDatabase(_db);
      final defaultWarehouseId = WarehouseStock.defaultWarehouseId(
        stockDatabase,
      );
      final movements = _db.select(
        'SELECT product_id, quantity, from_warehouse_id, to_warehouse_id '
        'FROM stock_movements '
        'WHERE reference_type=? AND reference_id=?',
        [referenceType, documentId],
      );
      _ensureReversalStock(
        _movementTotals(movements, defaultWarehouseId),
        stockDatabase,
        label,
      );
      for (final movement in movements) {
        final productId = (movement['product_id'] as num?)?.toInt();
        if (productId == null) continue;
        final quantity = _int(movement['quantity']);
        _db.execute(
          'UPDATE products SET current_stock=current_stock-?, updated_at=? '
          'WHERE id=?',
          [quantity, now, productId],
        );
      }
    }
    _db.execute(
      'DELETE FROM stock_movements WHERE reference_type=? AND reference_id=?',
      [referenceType, documentId],
    );
    _deleteCustom(customType, documentId);
    _db.execute('DELETE FROM $itemsTable WHERE session_id=?', [documentId]);
    _db.execute('DELETE FROM $table WHERE id=?', [documentId]);
  }

  int _currentStock(int productId) {
    final rows = _db.select('SELECT current_stock FROM products WHERE id=?', [
      productId,
    ]);
    return rows.isEmpty ? 0 : _int(rows.first['current_stock']);
  }

  Map<(int, int?), int> _movementTotals(
    Iterable<Row> movements,
    int? defaultWarehouseId,
  ) {
    final totals = <(int, int?), int>{};
    for (final movement in movements) {
      final productId = (movement['product_id'] as num?)?.toInt();
      if (productId == null) continue;
      final warehouseId =
          (movement['from_warehouse_id'] as num?)?.toInt() ??
          (movement['to_warehouse_id'] as num?)?.toInt() ??
          defaultWarehouseId;
      final key = (productId, warehouseId);
      final quantity = _int(movement['quantity']);
      totals.update(key, (total) => total + quantity, ifAbsent: () => quantity);
    }
    return totals;
  }

  void _ensureReversalStock(
    Map<(int, int?), int> quantities,
    SqliteDatabase stockDatabase,
    String label,
  ) {
    for (final entry in quantities.entries) {
      if (entry.value <= 0) continue;
      final productId = entry.key.$1;
      final warehouseId = entry.key.$2;
      final stock = warehouseId == null
          ? _currentStock(productId)
          : WarehouseStock.quantityInWarehouse(
              stockDatabase,
              productId,
              warehouseId,
            );
      if (stock < entry.value) {
        throw ArchiveException(
          'لا يمكن حذف $label لأن بعض الكميات المعدلة استُخدمت في '
          'حركات لاحقة. المخزون الحالي غير كافٍ للتراجع.',
        );
      }
    }
  }

  void _deleteTransfer(int id) {
    final rows = _db.select(
      'SELECT session_number, to_warehouse_id, applied '
      'FROM stock_transfer_sessions WHERE id=?',
      [id],
    );
    if (rows.isEmpty) throw ArchiveException('المستند غير موجود.');
    if (_int(rows.first['applied']) == 1) {
      final stockDatabase = SqliteDatabase.withDatabase(_db);
      final destinationId =
          (rows.first['to_warehouse_id'] as num?)?.toInt() ??
          WarehouseStock.defaultWarehouseId(stockDatabase);
      final quantityByProduct = <int, int>{};
      for (final item in _db.select(
        'SELECT product_id, transfer_qty FROM stock_transfer_items '
        'WHERE session_id=?',
        [id],
      )) {
        final productId = (item['product_id'] as num?)?.toInt();
        if (productId == null) continue;
        quantityByProduct.update(
          productId,
          (quantity) => quantity + _int(item['transfer_qty']),
          ifAbsent: () => _int(item['transfer_qty']),
        );
      }
      for (final entry in quantityByProduct.entries) {
        final available = destinationId == null
            ? _currentStock(entry.key)
            : WarehouseStock.quantityInWarehouse(
                stockDatabase,
                entry.key,
                destinationId,
              );
        if (available < entry.value) {
          throw ArchiveException(
            'لا يمكن حذف مستند التحويل لأن بعض الكمية استُخدمت من مخزن الوجهة. '
            'انقل الكمية إلى المخزن أولاً ثم أعد المحاولة.',
          );
        }
      }
    }
    _db.execute(
      "DELETE FROM stock_movements WHERE reference_type='stock_transfer' "
      'AND reference_id=?',
      [id],
    );
    _deleteCustom('warehouse_transfer', id);
    _db.execute('DELETE FROM stock_transfer_items WHERE session_id=?', [id]);
    _db.execute('DELETE FROM stock_transfer_sessions WHERE id=?', [id]);
  }

  void _reversePayments(String referenceType, int referenceId) {
    final treasuryIds = <int>{};
    for (final row in _db.select(
      'SELECT DISTINCT treasury_id FROM treasury_transactions '
      'WHERE reference_type=? AND reference_id=?',
      [referenceType, referenceId],
    )) {
      final treasuryId = (row['treasury_id'] as num?)?.toInt();
      if (treasuryId != null) treasuryIds.add(treasuryId);
    }
    for (final payment in _db.select(
      'SELECT account_id, amount, payment_type FROM payments '
      'WHERE reference_type=? AND reference_id=?',
      [referenceType, referenceId],
    )) {
      final accountId = (payment['account_id'] as num?)?.toInt();
      if (accountId == null) continue;
      final amount = _int(payment['amount']);
      final delta = '${payment['payment_type']}' == 'receipt'
          ? amount
          : -amount;
      _db.execute(
        'UPDATE accounts SET balance=balance+?, updated_at=? WHERE id=?',
        [delta, DateTime.now().toIso8601String(), accountId],
      );
    }
    _db.execute(
      'DELETE FROM treasury_transactions WHERE reference_type=? '
      'AND reference_id=?',
      [referenceType, referenceId],
    );
    _db.execute(
      'DELETE FROM payments WHERE reference_type=? AND reference_id=?',
      [referenceType, referenceId],
    );
    for (final treasuryId in treasuryIds) {
      _recalculateTreasury(treasuryId);
    }
  }

  void _recalculateTreasury(int treasuryId) {
    final rows = _db.select(
      'SELECT opening_balance FROM treasuries WHERE id=?',
      [treasuryId],
    );
    if (rows.isEmpty) return;
    var running = _int(rows.first['opening_balance']);
    for (final transaction in _db.select(
      'SELECT id, amount, transaction_type FROM treasury_transactions '
      'WHERE treasury_id=? ORDER BY transaction_date,id',
      [treasuryId],
    )) {
      final amount = _int(transaction['amount']);
      running += '${transaction['transaction_type']}' == 'receive'
          ? amount
          : -amount;
      _db.execute(
        'UPDATE treasury_transactions SET balance_after=? WHERE id=?',
        [running, (transaction['id'] as num).toInt()],
      );
    }
  }

  void _deleteCustom(String documentType, int documentId) {
    _db.execute(
      'DELETE FROM document_custom_values WHERE document_type=? '
      'AND document_id=?',
      [documentType, documentId],
    );
  }

  // ---------------------------------------------------------------------------
  // SQL sources.
  // ---------------------------------------------------------------------------
  _DocSpec _spec(ArchiveDocType type) {
    switch (type) {
      case ArchiveDocType.sale:
        return _DocSpec(
          from:
              'sales_invoices d '
              'LEFT JOIN accounts a ON a.id=d.account_id '
              'LEFT JOIN sales_invoices orig ON orig.id=d.original_invoice_id',
          baseWhere: 'd.is_return=0',
          number: 'd.invoice_number',
          date: 'd.invoice_date',
          accountId: 'd.account_id',
          accountName: "COALESCE(a.name,'')",
          warehouseName: "''",
          total: 'd.total',
          discount: 'd.discount',
          tax: 'd.tax',
          paid: 'd.paid_amount',
          remaining: 'd.remaining_amount',
          status: 'd.payment_status',
          notes: "COALESCE(d.notes,'')",
          originalNumber: "COALESCE(orig.invoice_number,'')",
          itemCount:
              '(SELECT COUNT(*) FROM sales_items it WHERE it.invoice_id=d.id)',
          applied: '1',
          createdAt: 'd.created_at',
          paymentMethod: _paymentMethodExpr(
            'sales_invoice',
            paidExpr: 'd.paid_amount',
          ),
          supportsWarehouse: false,
          supportsAccount: true,
          supportsTreasury: true,
          supportsPaymentMethod: true,
          supportsPaymentStatus: true,
          supportsItems: true,
          supportsDocumentStatus: true,
          itemsFrom:
              'sales_items i '
              'JOIN sales_invoices d ON d.id=i.invoice_id '
              'LEFT JOIN sales_invoices orig ON orig.id=d.original_invoice_id '
              'LEFT JOIN accounts a ON a.id=d.account_id '
              'LEFT JOIN products p ON p.id=i.product_id '
              'LEFT JOIN units u ON u.id=p.unit_id',
          itemsWhere: 'd.is_return=0',
          itemName: 'i.product_name',
          itemCode: 'i.product_code',
          itemBarcode: "COALESCE(p.barcode,'')",
          itemUnit: "COALESCE(u.name,'')",
          itemQty: 'i.quantity',
          itemPrice: 'i.unit_price',
          itemDiscount: 'i.discount',
          itemTotal: 'i.total',
          itemExtraLabel: "''",
          itemExtraValue: "''",
          itemCategoryId: 'p.category_id',
        );
      case ArchiveDocType.salesReturn:
        return _DocSpec(
          from:
              'sales_invoices d '
              'LEFT JOIN accounts a ON a.id=d.account_id '
              'LEFT JOIN sales_invoices orig ON orig.id=d.original_invoice_id',
          baseWhere: 'd.is_return=1',
          number: 'd.invoice_number',
          date: 'd.invoice_date',
          accountId: 'd.account_id',
          accountName: "COALESCE(a.name,'')",
          warehouseName: "''",
          total: 'd.total',
          discount: 'd.discount',
          tax: 'd.tax',
          paid: 'd.paid_amount',
          remaining: 'd.remaining_amount',
          status: 'd.payment_status',
          notes: "COALESCE(d.notes,'')",
          originalNumber: "COALESCE(orig.invoice_number,'')",
          itemCount:
              '(SELECT COUNT(*) FROM sales_items it WHERE it.invoice_id=d.id)',
          applied: '1',
          createdAt: 'd.created_at',
          paymentMethod: _paymentMethodExpr(
            'sales_return',
            paidExpr: 'd.paid_amount',
          ),
          supportsWarehouse: false,
          supportsAccount: true,
          supportsTreasury: true,
          supportsPaymentMethod: true,
          supportsPaymentStatus: true,
          supportsItems: true,
          supportsDocumentStatus: true,
          itemsFrom:
              'sales_items i '
              'JOIN sales_invoices d ON d.id=i.invoice_id '
              'LEFT JOIN sales_invoices orig ON orig.id=d.original_invoice_id '
              'LEFT JOIN accounts a ON a.id=d.account_id '
              'LEFT JOIN products p ON p.id=i.product_id '
              'LEFT JOIN units u ON u.id=p.unit_id',
          itemsWhere: 'd.is_return=1',
          itemName: 'i.product_name',
          itemCode: 'i.product_code',
          itemBarcode: "COALESCE(p.barcode,'')",
          itemUnit: "COALESCE(u.name,'')",
          itemQty: 'i.quantity',
          itemPrice: 'i.unit_price',
          itemDiscount: 'i.discount',
          itemTotal: 'i.total',
          itemExtraLabel: "''",
          itemExtraValue: "''",
          itemCategoryId: 'p.category_id',
        );
      case ArchiveDocType.quotation:
        return _DocSpec(
          from:
              'quotations d '
              'LEFT JOIN accounts a ON a.id=d.account_id',
          baseWhere: '1=1',
          number: 'd.quote_number',
          date: 'd.quote_date',
          accountId: 'd.account_id',
          accountName: "COALESCE(a.name,'')",
          warehouseName: "''",
          total: 'd.total',
          discount: 'd.discount',
          tax: 'd.tax',
          paid: '0',
          remaining: 'd.total',
          status: 'd.status',
          notes: "COALESCE(d.notes,'')",
          originalNumber: "''",
          itemCount: '(SELECT COUNT(*) FROM quotation_items it WHERE it.quote_id=d.id)',
          applied: "CASE WHEN d.status='converted' THEN 1 ELSE 0 END",
          createdAt: 'd.created_at',
          paymentMethod: "'credit'",
          supportsWarehouse: false,
          supportsAccount: true,
          supportsTreasury: false,
          supportsPaymentMethod: true,
          supportsPaymentStatus: false,
          supportsItems: true,
          supportsDocumentStatus: true,
          itemsFrom:
              'quotation_items i '
              'JOIN quotations d ON d.id=i.quote_id '
              'LEFT JOIN accounts a ON a.id=d.account_id '
              'LEFT JOIN products p ON p.id=i.product_id '
              'LEFT JOIN units u ON u.id=p.unit_id',
          itemsWhere: '1=1',
          itemName: 'i.product_name',
          itemCode: 'i.product_code',
          itemBarcode: "COALESCE(p.barcode,'')",
          itemUnit: "COALESCE(u.name,'')",
          itemQty: 'i.quantity',
          itemPrice: 'i.unit_price',
          itemDiscount: 'i.discount',
          itemTotal: 'i.total',
          itemExtraLabel: "''",
          itemExtraValue: "''",
          itemCategoryId: 'p.category_id',
        );
      case ArchiveDocType.purchase:
        return _DocSpec(
          from:
              'purchase_invoices d '
              'LEFT JOIN accounts a ON a.id=d.account_id',
          baseWhere: 'd.is_return=0',
          number: 'd.invoice_number',
          date: 'd.invoice_date',
          accountId: 'd.account_id',
          accountName: "COALESCE(a.name,'')",
          warehouseName: "''",
          total: 'd.total',
          discount: 'd.discount',
          tax: 'd.tax',
          paid: 'd.paid_amount',
          remaining: 'd.remaining_amount',
          status: 'd.payment_status',
          notes: "COALESCE(d.notes,'')",
          originalNumber: "''",
          itemCount:
              '(SELECT COUNT(*) FROM purchase_items it '
              'WHERE it.invoice_id=d.id)',
          applied: '1',
          createdAt: 'd.created_at',
          paymentMethod: _paymentMethodExpr(
            'purchase_invoice',
            paidExpr: 'd.paid_amount',
          ),
          supportsWarehouse: false,
          supportsAccount: true,
          supportsTreasury: true,
          supportsPaymentMethod: true,
          supportsPaymentStatus: true,
          supportsItems: true,
          supportsDocumentStatus: true,
          itemsFrom:
              'purchase_items i '
              'JOIN purchase_invoices d ON d.id=i.invoice_id '
              'LEFT JOIN accounts a ON a.id=d.account_id '
              'LEFT JOIN products p ON p.id=i.product_id '
              'LEFT JOIN units u ON u.id=p.unit_id',
          itemsWhere: 'd.is_return=0',
          itemName: 'i.product_name',
          itemCode: 'i.product_code',
          itemBarcode: "COALESCE(p.barcode,'')",
          itemUnit: "COALESCE(u.name,'')",
          itemQty: 'i.quantity',
          itemPrice: 'i.unit_price',
          itemDiscount: 'i.discount',
          itemTotal: 'i.total',
          itemExtraLabel: "''",
          itemExtraValue: "''",
          itemCategoryId: 'p.category_id',
        );
      case ArchiveDocType.purchaseReturn:
        return _DocSpec(
          from:
              'purchase_return_invoices d '
              'LEFT JOIN accounts a ON a.id=d.account_id '
              'LEFT JOIN purchase_invoices orig '
              'ON orig.id=d.original_invoice_id',
          baseWhere: '1=1',
          number: 'd.return_number',
          date: 'd.return_date',
          accountId: 'd.account_id',
          accountName: "COALESCE(a.name,'')",
          warehouseName: "''",
          total: 'd.total',
          discount: 'd.discount',
          tax: 'd.tax',
          paid: 'd.refunded_amount',
          remaining: 'd.remaining_amount',
          status: 'd.payment_status',
          notes: "COALESCE(d.notes,'')",
          originalNumber: "COALESCE(orig.invoice_number,'')",
          itemCount:
              '(SELECT COUNT(*) FROM purchase_return_items it '
              'WHERE it.return_id=d.id)',
          applied: '1',
          createdAt: 'd.created_at',
          paymentMethod: _paymentMethodExpr(
            'purchase_return',
            paidExpr: 'd.refunded_amount',
          ),
          supportsWarehouse: false,
          supportsAccount: true,
          supportsTreasury: true,
          supportsPaymentMethod: true,
          supportsPaymentStatus: true,
          supportsItems: true,
          supportsDocumentStatus: true,
          itemsFrom:
              'purchase_return_items i '
              'JOIN purchase_return_invoices d ON d.id=i.return_id '
              'LEFT JOIN purchase_invoices orig ON orig.id=d.original_invoice_id '
              'LEFT JOIN accounts a ON a.id=d.account_id '
              'LEFT JOIN products p ON p.id=i.product_id '
              'LEFT JOIN units u ON u.id=p.unit_id',
          itemsWhere: '1=1',
          itemName: 'i.product_name',
          itemCode: 'i.product_code',
          itemBarcode: "COALESCE(p.barcode,'')",
          itemUnit: "COALESCE(u.name,'')",
          itemQty: 'i.quantity',
          itemPrice: 'i.unit_price',
          itemDiscount: 'i.discount',
          itemTotal: 'i.total',
          itemExtraLabel: "''",
          itemExtraValue: "''",
          itemCategoryId: 'p.category_id',
        );
      case ArchiveDocType.receipt:
      case ArchiveDocType.payment:
        final paymentType = type.isReceipt ? 'receipt' : 'payment';
        return _DocSpec(
          from:
              'payments d '
              'LEFT JOIN accounts a ON a.id=d.account_id',
          baseWhere: "d.payment_type='$paymentType' AND d.reference_id IS NULL",
          number: 'd.payment_number',
          date: 'd.payment_date',
          accountId: 'd.account_id',
          accountName: "COALESCE(a.name,'')",
          warehouseName: "''",
          total: 'd.amount',
          discount: '0',
          tax: '0',
          paid: 'd.amount',
          remaining: '0',
          status: "'paid'",
          notes: "COALESCE(d.description,'')",
          originalNumber: "''",
          itemCount: '0',
          applied: '1',
          createdAt: 'd.created_at',
          paymentMethod: 'd.payment_method',
          supportsWarehouse: false,
          supportsAccount: true,
          supportsTreasury: false,
          supportsPaymentMethod: true,
          supportsPaymentStatus: true,
          supportsItems: false,
          supportsDocumentStatus: false,
          itemsFrom: '',
          itemsWhere: '1=0',
          itemName: "''",
          itemCode: "''",
          itemBarcode: "''",
          itemUnit: "''",
          itemQty: '0',
          itemPrice: '0',
          itemDiscount: '0',
          itemTotal: '0',
          itemExtraLabel: "''",
          itemExtraValue: "''",
          itemCategoryId: 'NULL',
        );
      case ArchiveDocType.stocktaking:
        return _stockSpec(
          from:
              'stocktaking_sessions d '
              'LEFT JOIN warehouses w ON w.id=d.warehouse_id',
          itemsFrom:
              'stocktaking_items i '
              'JOIN stocktaking_sessions d ON d.id=i.session_id '
              'LEFT JOIN warehouses w ON w.id=d.warehouse_id '
              'LEFT JOIN products p ON p.id=i.product_id',
          referenceType: 'stocktaking_session',
          customType: 'stocktaking',
          number: 'd.session_number',
          date: 'd.session_date',
          warehouseId: 'd.warehouse_id',
          warehouseName: "COALESCE(w.name,'')",
          itemQty: 'i.counted_qty',
          itemExtraLabel: "'المتاح'",
          itemExtraValue: 'i.available_qty',
        );
      case ArchiveDocType.adjustment:
        return _stockSpec(
          from:
              'stock_adjustment_sessions d '
              'LEFT JOIN warehouses w ON w.id=d.warehouse_id',
          itemsFrom:
              'stock_adjustment_items i '
              'JOIN stock_adjustment_sessions d ON d.id=i.session_id '
              'LEFT JOIN warehouses w ON w.id=d.warehouse_id '
              'LEFT JOIN products p ON p.id=i.product_id',
          referenceType: 'stock_adjustment',
          customType: 'warehouse_adjustment',
          number: 'd.session_number',
          date: 'd.session_date',
          warehouseId: 'd.warehouse_id',
          warehouseName: "COALESCE(w.name,'')",
          itemQty: 'i.adjusted_qty',
          itemExtraLabel: "'الفرق'",
          itemExtraValue: 'i.difference',
        );
      case ArchiveDocType.transfer:
        return _DocSpec(
          from:
              'stock_transfer_sessions d '
              'LEFT JOIN warehouses wf ON wf.id=d.from_warehouse_id '
              'LEFT JOIN warehouses wt ON wt.id=d.to_warehouse_id',
          baseWhere: '1=1',
          number: 'd.session_number',
          date: 'd.session_date',
          accountId: 'NULL',
          accountName: "''",
          warehouseName:
              "(COALESCE(wf.name,'') || ' ← ' || COALESCE(wt.name,''))",
          total: 'd.total',
          discount: '0',
          tax: '0',
          paid: '0',
          remaining: 'd.total',
          status: "CASE WHEN d.applied=1 THEN 'applied' ELSE 'draft' END",
          notes: "COALESCE(d.notes,'')",
          originalNumber: "''",
          itemCount: 'd.items_count',
          applied: 'd.applied',
          createdAt: 'd.created_at',
          paymentMethod: "''",
          supportsWarehouse: true,
          supportsAccount: false,
          supportsTreasury: false,
          supportsPaymentMethod: false,
          supportsPaymentStatus: false,
          supportsItems: true,
          supportsDocumentStatus: true,
          itemsFrom:
              'stock_transfer_items i '
              'JOIN stock_transfer_sessions d ON d.id=i.session_id '
              'LEFT JOIN warehouses wf ON wf.id=d.from_warehouse_id '
              'LEFT JOIN warehouses wt ON wt.id=d.to_warehouse_id '
              'LEFT JOIN products p ON p.id=i.product_id',
          itemsWhere: '1=1',
          itemName: 'i.product_name',
          itemCode: 'i.product_code',
          itemBarcode: "COALESCE(p.barcode,'')",
          itemUnit: "COALESCE(i.unit_name,'')",
          itemQty: 'i.transfer_qty',
          itemPrice: 'i.price',
          itemDiscount: '0',
          itemTotal: 'i.total',
          itemExtraLabel: "'المتاح'",
          itemExtraValue: 'i.available_qty',
          itemCategoryId: 'p.category_id',
          warehouseFilter: '(d.from_warehouse_id=? OR d.to_warehouse_id=?)',
        );
    }
  }

  _DocSpec _stockSpec({
    required String from,
    required String itemsFrom,
    required String referenceType,
    required String customType,
    required String number,
    required String date,
    required String warehouseId,
    required String warehouseName,
    required String itemQty,
    required String itemExtraLabel,
    required String itemExtraValue,
  }) {
    return _DocSpec(
      from: from,
      baseWhere: '1=1',
      number: number,
      date: date,
      accountId: 'NULL',
      accountName: "''",
      warehouseName: warehouseName,
      total: 'd.total',
      discount: '0',
      tax: '0',
      paid: '0',
      remaining: 'd.total',
      status: "CASE WHEN d.applied=1 THEN 'applied' ELSE 'draft' END",
      notes: "COALESCE(d.notes,'')",
      originalNumber: "''",
      itemCount: 'd.items_count',
      applied: 'd.applied',
      createdAt: 'd.created_at',
      paymentMethod: "''",
      supportsWarehouse: true,
      supportsAccount: false,
      supportsTreasury: false,
      supportsPaymentMethod: false,
      supportsPaymentStatus: false,
      supportsItems: true,
      supportsDocumentStatus: true,
      itemsFrom: itemsFrom,
      itemsWhere: '1=1',
      itemName: 'i.product_name',
      itemCode: 'i.product_code',
      itemBarcode: "COALESCE(p.barcode,'')",
      itemUnit: "COALESCE(i.unit_name,'')",
      itemQty: itemQty,
      itemPrice: 'i.price',
      itemDiscount: '0',
      itemTotal: 'i.total',
      itemExtraLabel: itemExtraLabel,
      itemExtraValue: itemExtraValue,
      itemCategoryId: 'p.category_id',
      warehouseFilter: '$warehouseId=?',
      treasuryReferenceType: referenceType,
      customType: customType,
    );
  }

  String _paymentMethodExpr(String referenceType, {required String paidExpr}) {
    return "COALESCE((SELECT p.payment_method FROM payments p "
        "WHERE p.reference_type='$referenceType' AND p.reference_id=d.id "
        "ORDER BY p.id DESC LIMIT 1), "
        "CASE WHEN $paidExpr > 0 THEN 'cash' ELSE 'credit' END)";
  }

  // ---------------------------------------------------------------------------
  // SQL fragments.
  // ---------------------------------------------------------------------------
  String _documentSelect(_DocSpec s) =>
      'd.id AS id, ${s.number} AS number, ${s.date} AS doc_date, '
      '${s.accountId} AS account_id, ${s.accountName} AS account_name, '
      '${s.warehouseName} AS warehouse_name, ${s.total} AS total, '
      '${s.discount} AS discount, ${s.tax} AS tax, ${s.paid} AS paid, '
      '${s.remaining} AS remaining, ${s.status} AS status, '
      '${s.notes} AS notes, ${s.originalNumber} AS original_number, '
      '${s.itemCount} AS item_count, ${s.applied} AS applied, '
      '${s.createdAt} AS created_at, ${s.paymentMethod} AS payment_method';

  String _itemSelect(_DocSpec s) =>
      'd.id AS document_id, ${s.number} AS number, ${s.date} AS doc_date, '
      '${s.accountName} AS account_name, '
      '${s.warehouseName} AS warehouse_name, ${s.itemName} AS item_name, '
      '${s.itemCode} AS item_code, ${s.itemBarcode} AS barcode, '
      '${s.itemUnit} AS unit_name, ${s.itemQty} AS quantity, '
      '${s.itemPrice} AS unit_price, ${s.itemDiscount} AS discount, '
      '${s.itemTotal} AS line_total, '
      '${s.itemExtraLabel} AS extra_label, '
      '${s.itemExtraValue} AS extra_value, ${s.notes} AS notes';

  _Where _documentWhere(ArchiveDocType type, _DocSpec s, ArchiveFilters f) {
    final clauses = <String>[s.baseWhere];
    final params = <Object?>[];
    if (f.fromDate != null) {
      clauses.add('substr(${s.date},1,10) >= ?');
      params.add(_date(f.fromDate!));
    }
    if (f.toDate != null) {
      clauses.add('substr(${s.date},1,10) <= ?');
      params.add(_date(f.toDate!));
    }
    if (f.fromTime != null && f.fromTime!.isNotEmpty) {
      clauses.add('substr(${s.date},12,5) >= ?');
      params.add(f.fromTime);
    }
    if (f.toTime != null && f.toTime!.isNotEmpty) {
      clauses.add('substr(${s.date},12,5) <= ?');
      params.add(f.toTime);
    }
    if (f.warehouseId != null) {
      if (s.warehouseFilter != null) {
        clauses.add(s.warehouseFilter!);
        params.add(f.warehouseId);
        if (type.isTransfer) params.add(f.warehouseId);
      } else {
        clauses.add('1=0');
      }
    }
    if (f.accountId != null) {
      if (s.supportsAccount) {
        clauses.add('d.account_id=?');
        params.add(f.accountId);
      } else {
        clauses.add('1=0');
      }
    }
    if (f.accountType.isNotEmpty) {
      if (s.supportsAccount) {
        clauses.add('a.account_type=?');
        params.add(f.accountType);
      } else {
        clauses.add('1=0');
      }
    }
    if (f.treasuryId != null) {
      if (s.supportsTreasury) {
        clauses.add(
          'EXISTS (SELECT 1 FROM treasury_transactions tt '
          'WHERE tt.reference_type=? AND tt.reference_id=d.id '
          'AND tt.treasury_id=?)',
        );
        params.add(_referenceType(type));
        params.add(f.treasuryId);
      } else {
        clauses.add('1=0');
      }
    }
    if (f.paymentMethod != 'all') {
      if (f.paymentMethod == 'cash') {
        clauses.add(
          "(${s.paymentMethod} IS NOT NULL AND ${s.paymentMethod} <> '' "
          "AND ${s.paymentMethod} <> 'credit')",
        );
      } else if (f.paymentMethod == 'credit') {
        clauses.add("${s.paymentMethod}='credit'");
      } else {
        clauses.add('${s.paymentMethod}=?');
        params.add(f.paymentMethod);
      }
    }
    if (f.paymentStatus != 'all') {
      if (s.supportsPaymentStatus) {
        clauses.add('${s.status}=?');
        params.add(f.paymentStatus);
      } else {
        clauses.add('1=0');
      }
    }
    final number = f.invoiceNumber.trim();
    if (number.isNotEmpty) {
      final pattern = _like(number);
      clauses.add(
        '(${s.number} LIKE ? ESCAPE \'\\\' OR ${s.originalNumber} LIKE ? '
        'ESCAPE \'\\\' OR ${s.notes} LIKE ? ESCAPE \'\\\')',
      );
      params.addAll([pattern, pattern, pattern]);
    }
    final exact = f.exactNumber.trim();
    if (exact.isNotEmpty) {
      clauses.add('${s.number}=?');
      params.add(exact);
    }
    if (f.minAmount != null) {
      clauses.add('${s.total} >= ?');
      params.add(f.minAmount);
    }
    if (f.maxAmount != null) {
      clauses.add('${s.total} <= ?');
      params.add(f.maxAmount);
    }
    if (f.itemName.trim().isNotEmpty) {
      if (s.supportsItems) {
        clauses.add(
          'EXISTS (SELECT 1 FROM ${s.resolvedItemsTable} x '
          'LEFT JOIN products px ON px.id=x.product_id '
          'WHERE x.${s.resolvedItemsFk}=d.id AND x.product_name LIKE ? ESCAPE \'\\\')',
        );
        params.add(_like(f.itemName));
      } else {
        clauses.add('1=0');
      }
    }
    if (f.itemCode.trim().isNotEmpty) {
      if (s.supportsItems) {
        clauses.add(
          'EXISTS (SELECT 1 FROM ${s.resolvedItemsTable} x '
          'WHERE x.${s.resolvedItemsFk}=d.id AND x.product_code LIKE ? ESCAPE \'\\\')',
        );
        params.add(_like(f.itemCode));
      } else {
        clauses.add('1=0');
      }
    }
    if (f.barcode.trim().isNotEmpty) {
      if (s.supportsItems) {
        clauses.add(
          'EXISTS (SELECT 1 FROM ${s.resolvedItemsTable} x '
          'LEFT JOIN products px ON px.id=x.product_id '
          "WHERE x.${s.resolvedItemsFk}=d.id AND COALESCE(px.barcode,'') LIKE ? "
          "ESCAPE '\\')",
        );
        params.add(_like(f.barcode));
      } else {
        clauses.add('1=0');
      }
    }
    if (f.categoryId != null) {
      if (s.supportsItems) {
        clauses.add(
          'EXISTS (SELECT 1 FROM ${s.resolvedItemsTable} x '
          'LEFT JOIN products px ON px.id=x.product_id '
          'WHERE x.${s.resolvedItemsFk}=d.id AND px.category_id=?)',
        );
        params.add(f.categoryId);
      } else {
        clauses.add('1=0');
      }
    }
    if (f.partyName.trim().isNotEmpty) {
      clauses.add('${s.accountName} LIKE ? ESCAPE \'\\\'');
      params.add(_like(f.partyName));
    }
    if (f.notes.trim().isNotEmpty) {
      clauses.add('${s.notes} LIKE ? ESCAPE \'\\\'');
      params.add(_like(f.notes));
    }
    if (f.documentStatus != 'all') {
      if (s.supportsDocumentStatus) {
        if (type.isStockDocument) {
          clauses.add('d.applied=?');
          params.add(f.documentStatus == 'applied' ? 1 : 0);
        } else if (type.isQuotation) {
          clauses.add('d.status=?');
          params.add(f.documentStatus);
        } else {
          clauses.add('${s.status}=?');
          params.add(f.documentStatus);
        }
      } else {
        clauses.add('1=0');
      }
    }
    return _Where(clauses.join(' AND '), params);
  }

  _Where _itemWhere(ArchiveDocType type, _DocSpec s, ArchiveFilters f) {
    final clauses = <String>[s.itemsWhere];
    final params = <Object?>[];
    if (f.fromDate != null) {
      clauses.add('substr(${s.date},1,10) >= ?');
      params.add(_date(f.fromDate!));
    }
    if (f.toDate != null) {
      clauses.add('substr(${s.date},1,10) <= ?');
      params.add(_date(f.toDate!));
    }
    if (f.fromTime != null && f.fromTime!.isNotEmpty) {
      clauses.add('substr(${s.date},12,5) >= ?');
      params.add(f.fromTime);
    }
    if (f.toTime != null && f.toTime!.isNotEmpty) {
      clauses.add('substr(${s.date},12,5) <= ?');
      params.add(f.toTime);
    }
    if (f.warehouseId != null) {
      if (s.warehouseFilter != null) {
        clauses.add(s.warehouseFilter!);
        params.add(f.warehouseId);
        if (type.isTransfer) params.add(f.warehouseId);
      } else {
        clauses.add('1=0');
      }
    }
    if (f.accountId != null) {
      if (s.supportsAccount) {
        clauses.add('d.account_id=?');
        params.add(f.accountId);
      } else {
        clauses.add('1=0');
      }
    }
    if (f.accountType.isNotEmpty) {
      if (s.supportsAccount) {
        clauses.add('a.account_type=?');
        params.add(f.accountType);
      } else {
        clauses.add('1=0');
      }
    }
    if (f.treasuryId != null) {
      if (s.supportsTreasury) {
        clauses.add(
          'EXISTS (SELECT 1 FROM treasury_transactions tt '
          'WHERE tt.reference_type=? AND tt.reference_id=d.id '
          'AND tt.treasury_id=?)',
        );
        params.add(_referenceType(type));
        params.add(f.treasuryId);
      } else {
        clauses.add('1=0');
      }
    }
    if (f.paymentMethod != 'all') {
      if (f.paymentMethod == 'cash') {
        clauses.add(
          "(${s.paymentMethod} IS NOT NULL AND ${s.paymentMethod} <> '' "
          "AND ${s.paymentMethod} <> 'credit')",
        );
      } else if (f.paymentMethod == 'credit') {
        clauses.add("${s.paymentMethod}='credit'");
      } else {
        clauses.add('${s.paymentMethod}=?');
        params.add(f.paymentMethod);
      }
    }
    if (f.paymentStatus != 'all') {
      if (s.supportsPaymentStatus) {
        clauses.add('${s.status}=?');
        params.add(f.paymentStatus);
      } else {
        clauses.add('1=0');
      }
    }
    final number = f.invoiceNumber.trim();
    if (number.isNotEmpty) {
      final pattern = _like(number);
      clauses.add(
        '(${s.number} LIKE ? ESCAPE \'\\\' OR ${s.originalNumber} LIKE ? '
        'ESCAPE \'\\\')',
      );
      params.addAll([pattern, pattern]);
    }
    final exact = f.exactNumber.trim();
    if (exact.isNotEmpty) {
      clauses.add('${s.number}=?');
      params.add(exact);
    }
    if (f.minAmount != null) {
      clauses.add('${s.itemTotal} >= ?');
      params.add(f.minAmount);
    }
    if (f.maxAmount != null) {
      clauses.add('${s.itemTotal} <= ?');
      params.add(f.maxAmount);
    }
    if (f.itemName.trim().isNotEmpty) {
      clauses.add('${s.itemName} LIKE ? ESCAPE \'\\\'');
      params.add(_like(f.itemName));
    }
    if (f.itemCode.trim().isNotEmpty) {
      clauses.add('${s.itemCode} LIKE ? ESCAPE \'\\\'');
      params.add(_like(f.itemCode));
    }
    if (f.barcode.trim().isNotEmpty) {
      clauses.add('${s.itemBarcode} LIKE ? ESCAPE \'\\\'');
      params.add(_like(f.barcode));
    }
    if (f.categoryId != null) {
      clauses.add('${s.itemCategoryId}=?');
      params.add(f.categoryId);
    }
    if (f.partyName.trim().isNotEmpty) {
      clauses.add('${s.accountName} LIKE ? ESCAPE \'\\\'');
      params.add(_like(f.partyName));
    }
    if (f.notes.trim().isNotEmpty) {
      clauses.add('${s.notes} LIKE ? ESCAPE \'\\\'');
      params.add(_like(f.notes));
    }
    if (f.documentStatus != 'all' && s.supportsDocumentStatus) {
      if (type.isStockDocument) {
        clauses.add('d.applied=?');
        params.add(f.documentStatus == 'applied' ? 1 : 0);
      } else if (type.isQuotation) {
        clauses.add('d.status=?');
        params.add(f.documentStatus);
      } else {
        clauses.add('${s.status}=?');
        params.add(f.documentStatus);
      }
    }
    return _Where(clauses.join(' AND '), params);
  }

  String _documentOrder(_DocSpec s, ArchiveSort sort) {
    final column = switch (sort.field) {
      ArchiveSortField.date => s.date,
      ArchiveSortField.number => s.number,
      ArchiveSortField.account => s.accountName,
      ArchiveSortField.total => s.total,
      ArchiveSortField.paid => s.paid,
      ArchiveSortField.remaining => s.remaining,
      ArchiveSortField.status => s.status,
    };
    return '$column ${sort.ascending ? 'ASC' : 'DESC'}, d.id DESC';
  }

  String _itemOrder(_DocSpec s, ArchiveItemSort sort) {
    final column = switch (sort.field) {
      ArchiveItemSortField.date => s.date,
      ArchiveItemSortField.number => s.number,
      ArchiveItemSortField.item => s.itemName,
      ArchiveItemSortField.quantity => s.itemQty,
      ArchiveItemSortField.total => s.itemTotal,
    };
    return '$column ${sort.ascending ? 'ASC' : 'DESC'}, d.id DESC, i.id ASC';
  }

  String _referenceType(ArchiveDocType type) => switch (type) {
    ArchiveDocType.sale => 'sales_invoice',
    ArchiveDocType.salesReturn => 'sales_return',
    ArchiveDocType.purchase => 'purchase_invoice',
    ArchiveDocType.purchaseReturn => 'purchase_return',
    _ => '',
  };

  ArchiveDocument _mapDocument(Map<String, Object?> row, ArchiveDocType type) {
    return ArchiveDocument(
      type: type,
      id: _int(row['id']),
      number: '${row['number'] ?? ''}',
      date: DateTime.tryParse('${row['doc_date'] ?? ''}'),
      accountId: (row['account_id'] as num?)?.toInt(),
      accountName: '${row['account_name'] ?? ''}',
      warehouseName: '${row['warehouse_name'] ?? ''}',
      total: _int(row['total']),
      discount: _int(row['discount']),
      tax: _int(row['tax']),
      paid: _int(row['paid']),
      remaining: _int(row['remaining']),
      status: '${row['status'] ?? ''}',
      paymentMethod: '${row['payment_method'] ?? ''}',
      notes: '${row['notes'] ?? ''}',
      originalNumber: '${row['original_number'] ?? ''}',
      itemCount: _int(row['item_count']),
      applied: _int(row['applied']) == 1,
      createdAt: DateTime.tryParse('${row['created_at'] ?? ''}'),
    );
  }

  ArchiveItem _mapItem(Map<String, Object?> row, ArchiveDocType type) {
    return ArchiveItem(
      type: type,
      documentId: _int(row['document_id']),
      documentNumber: '${row['number'] ?? ''}',
      date: DateTime.tryParse('${row['doc_date'] ?? ''}'),
      accountName: '${row['account_name'] ?? ''}',
      warehouseName: '${row['warehouse_name'] ?? ''}',
      itemName: '${row['item_name'] ?? ''}',
      itemCode: '${row['item_code'] ?? ''}',
      barcode: '${row['barcode'] ?? ''}',
      unitName: '${row['unit_name'] ?? ''}',
      quantity: _int(row['quantity']),
      unitPrice: _int(row['unit_price']),
      discount: _int(row['discount']),
      lineTotal: _int(row['line_total']),
      extraLabel: '${row['extra_label'] ?? ''}',
      extraValue: '${row['extra_value'] ?? ''}',
      notes: '${row['notes'] ?? ''}',
    );
  }

  static int _int(Object? value) => (value as num?)?.toInt() ?? 0;

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  static String _like(String value) =>
      '%${value.trim().replaceAll('\\', '\\\\').replaceAll('%', '\\%').replaceAll('_', '\\_')}%';
}

/// The SQL expressions of one document family.
class _DocSpec {
  _DocSpec({
    required this.from,
    required this.baseWhere,
    required this.number,
    required this.date,
    required this.accountId,
    required this.accountName,
    required this.warehouseName,
    required this.total,
    required this.discount,
    required this.tax,
    required this.paid,
    required this.remaining,
    required this.status,
    required this.notes,
    required this.originalNumber,
    required this.itemCount,
    required this.applied,
    required this.createdAt,
    required this.paymentMethod,
    required this.supportsWarehouse,
    required this.supportsAccount,
    required this.supportsTreasury,
    required this.supportsPaymentMethod,
    required this.supportsPaymentStatus,
    required this.supportsItems,
    required this.supportsDocumentStatus,
    required this.itemsFrom,
    required this.itemsWhere,
    required this.itemName,
    required this.itemCode,
    required this.itemBarcode,
    required this.itemUnit,
    required this.itemQty,
    required this.itemPrice,
    required this.itemDiscount,
    required this.itemTotal,
    required this.itemExtraLabel,
    required this.itemExtraValue,
    required this.itemCategoryId,
    this.warehouseFilter,
    this.treasuryReferenceType,
    this.customType,
  });

  final String from;
  final String baseWhere;
  final String number;
  final String date;
  final String accountId;
  final String accountName;
  final String warehouseName;
  final String total;
  final String discount;
  final String tax;
  final String paid;
  final String remaining;
  final String status;
  final String notes;
  final String originalNumber;
  final String itemCount;
  final String applied;
  final String createdAt;
  final String paymentMethod;
  final bool supportsWarehouse;
  final bool supportsAccount;
  final bool supportsTreasury;
  final bool supportsPaymentMethod;
  final bool supportsPaymentStatus;
  final bool supportsItems;
  final bool supportsDocumentStatus;
  final String itemsFrom;
  final String itemsWhere;
  final String itemName;
  final String itemCode;
  final String itemBarcode;
  final String itemUnit;
  final String itemQty;
  final String itemPrice;
  final String itemDiscount;
  final String itemTotal;
  final String itemExtraLabel;
  final String itemExtraValue;
  final String itemCategoryId;
  final String? warehouseFilter;
  final String? treasuryReferenceType;
  final String? customType;

  bool get usesItems => supportsItems;

  /// Derived from [itemsFrom] so every family reuses one source of truth.
  String get resolvedItemsTable => _itemsTableFrom(itemsFrom);
  String get resolvedItemsFk => _itemsFkFrom(itemsFrom);

  static String _itemsTableFrom(String from) {
    final match = RegExp(r'^(\w+)\s+i\b').firstMatch(from);
    return match?.group(1) ?? '';
  }

  static String _itemsFkFrom(String from) {
    final table = _itemsTableFrom(from);
    return switch (table) {
      'sales_items' => 'invoice_id',
      'purchase_items' => 'invoice_id',
      'purchase_return_items' => 'return_id',
      'quotation_items' => 'quote_id',
      _ => 'session_id',
    };
  }
}

class _Where {
  const _Where(this.sql, this.params);

  final String sql;
  final List<Object?> params;
}
