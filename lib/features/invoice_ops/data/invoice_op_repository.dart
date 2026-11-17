import 'package:inventory_app/core/database/sqlite_database.dart';
import 'package:inventory_app/core/services/document_custom_fields.dart';
import 'package:inventory_app/core/services/warehouse_stock.dart';
import 'package:inventory_app/features/invoice_ops/domain/invoice_op_models.dart';

/// Common contract used by the invoice screen. Each operation has its own
/// concrete repository so its stock / accounting rules stay independent.
abstract class InvoiceOpRepository {
  InvoiceOpKind get kind;

  /// Shared connection used by the edit loader. Concrete repositories extend
  /// [InvoiceRepositoryBase], which exposes its database through this getter.
  SqliteDatabase get db;

  bool get supportsOriginalInvoice => false;

  Future<List<InvoiceProduct>> searchProducts(String term, {int limit = 60});

  Future<InvoiceProduct?> findByBarcode(String code);

  Future<List<InvoiceProduct>> listProducts({int? categoryId});

  Future<List<Map<String, Object?>>> getCategories();

  Future<List<InvoiceAccount>> getAccounts();

  /// Customer-specific price for a product, when the selected operation uses it.
  int? customerLastSoldPrice(int accountId, int productId) => null;

  String nextInvoiceNumber();

  Future<InvoiceSaveResult> saveInvoice({
    required int? accountId,
    required String invoiceNumber,
    required List<InvoiceLine> lines,
    required int discount,
    required int addition,
    required String notes,
    required String paymentMethod,
    InvoicePaymentInput? payment,
    int? originalInvoiceId,
    int? quotationId,
    Map<int, String> customFields = const {},
  });

  /// Update a saved document in place. The id never changes, payments that
  /// were already recorded are preserved, and stock is adjusted from the old
  /// lines to the new ones inside one transaction.
  Future<InvoiceSaveResult> updateInvoice({
    required int invoiceId,
    required int? accountId,
    required String invoiceNumber,
    required List<InvoiceLine> lines,
    required int discount,
    required int addition,
    required String notes,
    required String paymentMethod,
    int? originalInvoiceId,
    Map<int, String> customFields = const {},
  });

  Future<({int paid, int remaining})> recordPayment({
    required int invoiceId,
    required int accountId,
    required int amount,
    required String method,
  });

  Future<Map<String, Object?>?> getInvoice(int invoiceId);

  Future<List<Map<String, Object?>>> getInvoiceItems(int invoiceId);

  /// Load a saved document plus its lines and live product metadata for the
  /// edit screen. The id is preserved so saving updates the same row.
  Future<InvoiceEditData?> loadInvoiceForEdit(int invoiceId) async {
    final header = await getInvoice(invoiceId);
    if (header == null) return null;
    final rawItems = await getInvoiceItems(invoiceId);
    final lines = <InvoiceEditLine>[];
    for (final item in rawItems) {
      final productId = (item['product_id'] as num?)?.toInt();
      var available = 0;
      var unit = '';
      if (productId != null) {
        final products = db.query(
          'SELECT p.current_stock, COALESCE(u.name, \'\') AS unit_name '
          'FROM products p LEFT JOIN units u ON u.id = p.unit_id '
          'WHERE p.id = ?',
          [productId],
        );
        if (products.isNotEmpty) {
          available = (products.first['current_stock'] as num?)?.toInt() ?? 0;
          unit = '${products.first['unit_name'] ?? ''}';
        }
      }
      final qty = (item['quantity'] as num?)?.toInt() ?? 0;
      final lineId = (item['id'] as num?)?.toInt();
      lines.add(
        InvoiceEditLine(
          productId: productId,
          name: '${item['product_name'] ?? ''}',
          code: '${item['product_code'] ?? ''}',
          unit: unit.trim().isEmpty ? 'حبة' : unit,
          // Editing sees the stock the line can use: current stock plus the
          // quantity this document already reserved.
          available: available + qty,
          qty: qty,
          price: (item['unit_price'] as num?)?.toInt() ?? 0,
          discount: (item['discount'] as num?)?.toInt() ?? 0,
          customFields: lineId == null
              ? const {}
              : DocumentCustomFields.lineValues(
                  _documentTypeForKind(kind),
                  invoiceId,
                  lineId,
                ),
        ),
      );
    }
    final rawDate = '${header['invoice_date'] ?? header['quote_date'] ?? ''}';
    final parsed = DateTime.tryParse(rawDate);
    final discount = (header['discount'] as num?)?.toInt() ?? 0;
    final tax = (header['tax'] as num?)?.toInt() ?? 0;
    return InvoiceEditData(
      id: invoiceId,
      number:
          '${header['invoice_number'] ?? header['return_number'] ?? header['quote_number'] ?? ''}',
      accountId: (header['account_id'] as num?)?.toInt(),
      accountName: header['account_name'] as String?,
      date: parsed,
      time: _editTime(parsed),
      discount: discount,
      tax: tax,
      paid:
          (header['paid_amount'] as num?)?.toInt() ??
          (header['refunded_amount'] as num?)?.toInt() ??
          0,
      notes: '${header['notes'] ?? ''}',
      originalInvoiceId: (header['original_invoice_id'] as num?)?.toInt(),
      lines: lines,
      customFields: DocumentCustomFields.values(
        _documentTypeForKind(kind),
        invoiceId,
      ),
    );
  }

  static String _documentTypeForKind(InvoiceOpKind kind) => switch (kind) {
    InvoiceOpKind.sale => DocumentTypes.sale,
    InvoiceOpKind.salesReturn => DocumentTypes.salesReturn,
    InvoiceOpKind.purchaseReturn => DocumentTypes.purchaseReturn,
    InvoiceOpKind.quotation => DocumentTypes.quotation,
  };

  static String _editTime(DateTime? value) {
    if (value == null) return '';
    final hour = (value.hour % 12 == 0 ? 12 : value.hour % 12)
        .toString()
        .padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${value.hour < 12 ? 'AM' : 'PM'}';
  }

  Future<List<OriginalInvoiceSummary>> searchOriginalInvoices(
    String term,
  ) async {
    return const [];
  }

  Future<OriginalInvoiceData?> loadOriginalInvoice(int id) async => null;

  Future<OriginalInvoiceData?> loadQuotation(int id) async => null;
}

/// Shared lookup + validation helpers. No operation-specific stock or
/// accounting rule lives here.
abstract class InvoiceRepositoryBase extends InvoiceOpRepository {
  InvoiceRepositoryBase(this.kind, {SqliteDatabase? database})
    : _db = database ?? SqliteDatabase();

  @override
  final InvoiceOpKind kind;

  final SqliteDatabase _db;

  @override
  SqliteDatabase get db => _db;

  static final RegExp _digits = RegExp(r'\d+');

  // ---------------------------------------------------------------------------
  // Lookups.
  // ---------------------------------------------------------------------------

  @override
  Future<List<InvoiceProduct>> searchProducts(
    String term, {
    int limit = 60,
  }) async {
    final key = term.trim();
    if (key.isEmpty) return const [];
    final pattern = '%${_escapeLike(key)}%';
    final rows = db.query(
      '''
      SELECT p.id, p.name, p.product_code, p.barcode,
             p.purchase_price, p.selling_price, p.selling_price_2,
             p.selling_price_3, p.selling_price_4, p.current_stock,
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

  @override
  Future<InvoiceProduct?> findByBarcode(String code) async {
    final key = code.trim();
    if (key.isEmpty) return null;
    final rows = db.query(
      '''
      SELECT p.id, p.name, p.product_code, p.barcode,
             p.purchase_price, p.selling_price, p.selling_price_2,
             p.selling_price_3, p.selling_price_4, p.current_stock,
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

  @override
  Future<List<InvoiceProduct>> listProducts({int? categoryId}) async {
    final rows = db.query('''
      SELECT p.id, p.name, p.product_code, p.barcode,
             p.purchase_price, p.selling_price, p.selling_price_2,
             p.selling_price_3, p.selling_price_4, p.current_stock,
             COALESCE(u.name, '') AS unit_name
      FROM products p
      LEFT JOIN units u ON u.id = p.unit_id
      WHERE p.is_active = 1
        ${categoryId == null ? '' : 'AND p.category_id = ?'}
      ORDER BY p.name COLLATE NOCASE
      ''', categoryId == null ? [] : [categoryId]);
    return rows.map(_rowToProduct).toList();
  }

  @override
  Future<List<Map<String, Object?>>> getCategories() async {
    return db.query('SELECT id, name FROM categories ORDER BY name');
  }

  @override
  Future<List<InvoiceAccount>> getAccounts() async {
    final rows = db.query(
      'SELECT id, name, balance, account_type FROM accounts '
      'WHERE is_active = 1 ORDER BY name COLLATE NOCASE',
    );
    return rows
        .map(
          (r) => InvoiceAccount(
            id: r['id'] as int,
            name: (r['name'] as String?) ?? '',
            balance: (r['balance'] as int?) ?? 0,
            type: (r['account_type'] as String?) ?? '',
          ),
        )
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Helpers.
  // ---------------------------------------------------------------------------

  /// Next document number in [table], continuing the numeric sequence of
  /// documents that match [where]. Returns `prefix + next`.
  String nextNumber({
    required String table,
    required String column,
    required String where,
    required String prefix,
  }) {
    final rows = db.query(
      'SELECT $column AS number FROM $table '
      '${where.isEmpty ? '' : 'WHERE $where'} '
      'ORDER BY id DESC LIMIT 1',
    );
    if (rows.isEmpty) return '${prefix}1';
    final raw = '${rows.first['number'] ?? ''}';
    final match = _digits.firstMatch(raw);
    final next = match == null ? 1 : (int.tryParse(match.group(0)!) ?? 0) + 1;
    return '$prefix$next';
  }

  /// The product's purchase price, used as the historical cost snapshot when
  /// a sales line is first written.
  int productPurchasePrice(int productId) {
    final rows = db.query(
      'SELECT COALESCE(purchase_price, 0) AS price FROM products WHERE id = ?',
      [productId],
    );
    if (rows.isEmpty) return 0;
    return (rows.first['price'] as num?)?.toInt() ?? 0;
  }

  /// Weighted historical cost of a product on its original sales invoice.
  /// Returns null when the original sale line cannot be found.
  int? originalSaleUnitCost(int? originalInvoiceId, int productId) {
    if (originalInvoiceId == null) return null;
    final rows = db.query(
      '''
      SELECT SUM(quantity * unit_cost) AS cost, SUM(quantity) AS qty
      FROM sales_items
      WHERE invoice_id = ? AND product_id = ?
      ''',
      [originalInvoiceId, productId],
    );
    if (rows.isEmpty) return null;
    final qty = (rows.first['qty'] as num?)?.toInt() ?? 0;
    if (qty <= 0) return null;
    final totalCost = (rows.first['cost'] as num?)?.toInt() ?? 0;
    return (totalCost / qty).round();
  }

  /// Historical cost for a sales-return line: the weighted cost of the
  /// original sale, falling back to the product's current purchase price.
  int salesReturnUnitCost(int? originalInvoiceId, int productId) {
    return originalSaleUnitCost(originalInvoiceId, productId) ??
        productPurchasePrice(productId);
  }

  /// Validate the common line/header rules shared by the four operations.
  ({int subtotal, int discount, int addition, int total})
  validateInvoiceTotals({
    required List<InvoiceLine> lines,
    required int discount,
    required int addition,
  }) {
    if (lines.isEmpty) {
      throw InvoiceValidationException('أضف صنفاً واحداً على الأقل قبل الحفظ.');
    }
    for (final line in lines) {
      if (line.qty <= 0) {
        throw InvoiceValidationException(
          'الكمية يجب أن تكون أكبر من صفر في السطر «${line.name}».',
        );
      }
      if (line.price < 0) {
        throw InvoiceValidationException(
          'السعر لا يمكن أن يكون سالباً في السطر «${line.name}».',
        );
      }
      if (line.discount < 0 || line.discount > line.gross) {
        throw InvoiceValidationException(
          'خصم السطر «${line.name}» أكبر من إجمالي السطر.',
        );
      }
    }

    final subtotal = lines.fold<int>(0, (sum, line) => sum + line.net);
    final safeDiscount = discount < 0 ? 0 : discount;
    final safeAddition = addition < 0 ? 0 : addition;
    final total = subtotal - safeDiscount + safeAddition;
    if (total < 0) {
      throw InvoiceValidationException(
        'إجمالي الفاتورة لا يمكن أن يكون سالباً.',
      );
    }
    return (
      subtotal: subtotal,
      discount: safeDiscount,
      addition: safeAddition,
      total: total,
    );
  }

  /// Validate a payment against the invoice total.
  ({int paid, int remaining, String status}) validatePayment({
    required int total,
    InvoicePaymentInput? payment,
    int? accountId,
  }) {
    final paid = payment?.amount ?? 0;
    if (paid < 0) {
      throw InvoiceValidationException('قيمة السداد غير صحيحة.');
    }
    if (paid > total) {
      throw InvoiceValidationException('قيمة السداد أكبر من إجمالي الفاتورة.');
    }
    if (paid > 0) {
      if (accountId == null) {
        throw InvoiceValidationException('اختر الحساب قبل تسجيل السداد.');
      }
      requireAccount(accountId);
    }
    final remaining = total - paid;
    final status = remaining <= 0 ? 'paid' : (paid > 0 ? 'partial' : 'unpaid');
    return (paid: paid, remaining: remaining, status: status);
  }

  void requireAccount(int accountId) {
    final rows = db.query(
      'SELECT id FROM accounts WHERE id = ? AND is_active = 1',
      [accountId],
    );
    if (rows.isEmpty) {
      throw InvoiceValidationException('الحساب المحدد غير موجود أو غير نشط.');
    }
  }

  /// Write the cash/ledger rows for a payment or refund.
  ///
  /// [moneyIn] = true means cash was received (a customer payment or a
  /// supplier refund); false means cash was paid out (a purchase payment or a
  /// customer refund). This mirrors the sign convention of the accounts module:
  /// receipts reduce the account balance, payments increase it.
  void recordPaymentRows({
    required int referenceId,
    required String referenceType,
    required int accountId,
    required int amount,
    required String method,
    required String description,
    required bool moneyIn,
    required String numberPrefix,
    required String now,
  }) {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    db.insert(
      '''
      INSERT INTO payments
        (payment_number, account_id, payment_date, amount, payment_type,
         payment_method, description, reference_id, reference_type, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        '$numberPrefix-$stamp',
        accountId,
        now,
        amount,
        moneyIn ? 'receipt' : 'payment',
        method,
        description,
        referenceId,
        referenceType,
        now,
      ],
    );
    db.execute(
      'UPDATE accounts SET balance = balance + ?, updated_at = ? WHERE id = ?',
      [moneyIn ? -amount : amount, now, accountId],
    );

    // Credit/offset payments move no cash, so they must not touch the treasury.
    if (method != 'credit') {
      final treasuryRows = db.query(
        'SELECT id FROM treasuries WHERE is_active = 1 ORDER BY id LIMIT 1',
      );
      final treasuryId = treasuryRows.isEmpty
          ? null
          : (treasuryRows.first['id'] as num).toInt();
      int balance;
      if (treasuryId == null) {
        final balanceRows = db.query(
          'SELECT balance_after FROM treasury_transactions '
          'ORDER BY id DESC LIMIT 1',
        );
        balance = balanceRows.isEmpty
            ? 0
            : (balanceRows.first['balance_after'] as int? ?? 0);
      } else {
        final balanceRows = db.query(
          'SELECT (SELECT opening_balance FROM treasuries WHERE id = ?) + '
          'COALESCE(SUM(CASE WHEN transaction_type = \'receive\' '
          'THEN amount ELSE -amount END), 0) AS balance '
          'FROM treasury_transactions WHERE treasury_id = ?',
          [treasuryId, treasuryId],
        );
        balance = (balanceRows.first['balance'] as num?)?.toInt() ?? 0;
      }
      final time = now.length >= 16 ? now.substring(11, 16) : '00:00';
      db.insert(
        '''
        INSERT INTO treasury_transactions
          (transaction_number, transaction_date, transaction_time, amount,
           transaction_type, description, reference_id, reference_type,
           balance_after, created_at, treasury_id)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          'TRE-$stamp',
          now,
          time,
          amount,
          moneyIn ? 'receive' : 'expense',
          description,
          referenceId,
          referenceType,
          moneyIn ? balance + amount : balance - amount,
          now,
          treasuryId,
        ],
      );
    }
  }

  /// Current stock of a product, used by operations that reduce inventory.
  int currentStock(int productId) {
    final rows = db.query('SELECT current_stock FROM products WHERE id = ?', [
      productId,
    ]);
    return rows.isEmpty ? 0 : (rows.first['current_stock'] as int? ?? 0);
  }

  int currentStockInDefaultWarehouse(int productId) {
    final warehouseId = WarehouseStock.defaultWarehouseId(db);
    return warehouseId == null
        ? currentStock(productId)
        : WarehouseStock.quantityInWarehouse(db, productId, warehouseId);
  }

  InvoiceProduct _rowToProduct(Map<String, dynamic> r) {
    final id = r['id'] as int;
    return InvoiceProduct(
      id: id,
      name: (r['name'] as String?) ?? '',
      code: (r['product_code'] as String?) ?? '',
      barcode: r['barcode'] as String?,
      unitName: (r['unit_name'] as String?) ?? '',
      available: kind == InvoiceOpKind.sale
          ? currentStockInDefaultWarehouse(id)
          : (r['current_stock'] as int?) ?? 0,
      purchasePrice: (r['purchase_price'] as int?) ?? 0,
      sellingPrice: (r['selling_price'] as int?) ?? 0,
      sellingPrice2: (r['selling_price_2'] as int?) ?? 0,
      sellingPrice3: (r['selling_price_3'] as int?) ?? 0,
      sellingPrice4: (r['selling_price_4'] as int?) ?? 0,
    );
  }

  static String _escapeLike(String value) {
    return value
        .replaceAll('\\', '\\\\')
        .replaceAll('%', '\\%')
        .replaceAll('_', '\\_');
  }
}

/// Combine duplicate invoice rows by product before enforcing document-level
/// limits such as original quantity or available stock.
Map<int, int> aggregateInvoiceQuantities(List<InvoiceLine> lines) {
  final quantities = <int, int>{};
  for (final line in lines) {
    final productId = line.productId;
    if (productId == null) {
      throw InvoiceValidationException(
        'الصنف «${line.name}» غير مرتبط بمنتج مسجل.',
      );
    }
    quantities.update(
      productId,
      (quantity) => quantity + line.qty,
      ifAbsent: () => line.qty,
    );
  }
  return quantities;
}
