import 'package:safwa/core/database/sqlite_database.dart';
import 'package:safwa/core/services/document_custom_fields.dart';
import 'package:safwa/core/services/warehouse_stock.dart';
import 'package:safwa/features/purchases/domain/purchase_models.dart';

/// Data access for the شراء (purchase invoice) screen.
///
/// All writes go through [SqliteDatabase.transaction] so a validation or SQL
/// error never leaves a half saved invoice behind.
class PurchaseRepository {
  PurchaseRepository._internal();
  static final PurchaseRepository _instance = PurchaseRepository._internal();
  factory PurchaseRepository() => _instance;

  final _db = SqliteDatabase();

  static final RegExp _digits = RegExp(r'\d+');

  // ---------------------------------------------------------------------------
  // Lookups.
  // ---------------------------------------------------------------------------

  /// Search active products by name / code / barcode / secondary codes.
  Future<List<PurchaseProduct>> searchProducts(
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

  /// Exact barcode / code lookup used when the cashier types a code.
  Future<PurchaseProduct?> findByBarcode(String code) async {
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

  /// All active products (used by the quick list / category picker).
  Future<List<PurchaseProduct>> listProducts({int? categoryId}) async {
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

  /// All active accounts (supplier names live in this table in the reference).
  Future<List<PurchaseAccount>> getAccounts() async {
    final rows = _db.query(
      'SELECT id, name, balance, account_type FROM accounts '
      'WHERE is_active = 1 ORDER BY name COLLATE NOCASE',
    );
    return rows
        .map(
          (r) => PurchaseAccount(
            id: r['id'] as int,
            name: (r['name'] as String?) ?? '',
            balance: (r['balance'] as int?) ?? 0,
            type: (r['account_type'] as String?) ?? '',
          ),
        )
        .toList();
  }

  /// Next invoice number, continuing the numeric sequence of saved invoices.
  String nextInvoiceNumber() {
    final rows = _db.query(
      'SELECT invoice_number FROM purchase_invoices ORDER BY id DESC LIMIT 1',
    );
    if (rows.isEmpty) return '1';
    final raw = '${rows.first['invoice_number'] ?? ''}';
    final match = _digits.firstMatch(raw);
    final next = match == null ? 1 : (int.tryParse(match.group(0)!) ?? 0) + 1;
    return '$next';
  }

  // ---------------------------------------------------------------------------
  // Save.
  // ---------------------------------------------------------------------------

  /// Shared line/header validation used by save and in-place update.
  ({int subtotal, int discount, int addition, int total}) _purchaseTotals({
    required List<PurchaseLine> lines,
    required int discount,
    required int addition,
  }) {
    if (lines.isEmpty) {
      throw PurchaseValidationException(
        'أضف صنفاً واحداً على الأقل قبل الحفظ.',
      );
    }
    for (final line in lines) {
      if (line.qty <= 0) {
        throw PurchaseValidationException(
          'الكمية يجب أن تكون أكبر من صفر في السطر «${line.name}».',
        );
      }
      if (line.price < 0) {
        throw PurchaseValidationException(
          'سعر الشراء لا يمكن أن يكون سالباً في السطر «${line.name}».',
        );
      }
      if (line.discount < 0 || line.discount > line.gross) {
        throw PurchaseValidationException(
          'خصم السطر «${line.name}» أكبر من إجمالي السطر.',
        );
      }
    }

    final subtotal = lines.fold<int>(0, (sum, line) => sum + line.net);
    final safeDiscount = discount < 0 ? 0 : discount;
    final safeAddition = addition < 0 ? 0 : addition;
    final total = subtotal - safeDiscount + safeAddition;
    if (total < 0) {
      throw PurchaseValidationException(
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

  /// Persist the invoice, its lines, stock movements and optional payment in a
  /// single transaction.
  Future<PurchaseSaveResult> savePurchase({
    required int? accountId,
    required String invoiceNumber,
    required List<PurchaseLine> lines,
    required int discount,
    required int addition,
    required String notes,
    required String paymentMethod,
    PurchasePaymentInput? payment,
    Map<int, String> customFields = const {},
  }) async {
    final totals = _purchaseTotals(
      lines: lines,
      discount: discount,
      addition: addition,
    );
    final total = totals.total;
    final paid = payment?.amount ?? 0;
    if (paid < 0) {
      throw PurchaseValidationException('قيمة السداد غير صحيحة.');
    }
    if (paid > total) {
      throw PurchaseValidationException('قيمة السداد أكبر من إجمالي الفاتورة.');
    }
    if (paid > 0) {
      if (accountId == null) {
        throw PurchaseValidationException('اختر حساب المورد قبل تسجيل السداد.');
      }
      _requireAccount(accountId);
    }

    final remaining = total - paid;
    final status = remaining <= 0 ? 'paid' : (paid > 0 ? 'partial' : 'unpaid');

    return _db.transaction<PurchaseSaveResult>(() async {
      final now = DateTime.now().toIso8601String();
      final invoiceId = _db.insert(
        '''
        INSERT INTO purchase_invoices
          (invoice_number, supplier_id, account_id, invoice_date, subtotal,
           discount, tax, total, paid_amount, remaining_amount, payment_status,
           notes, created_at, updated_at)
        VALUES (?, NULL, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          invoiceNumber,
          accountId,
          now,
          totals.subtotal,
          totals.discount,
          totals.addition,
          total,
          paid,
          remaining,
          status,
          notes.isEmpty ? null : notes,
          now,
          now,
        ],
      );

      for (final line in lines) {
        final lineId = _db.insert(
          '''
          INSERT INTO purchase_items
            (invoice_id, product_id, product_name, product_code, quantity,
             unit_price, discount, total)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            invoiceId,
            line.productId,
            line.name,
            line.code,
            line.qty,
            line.price,
            line.discount,
            line.net,
          ],
        );
        DocumentCustomFields.saveLineValues(
          DocumentTypes.purchase,
          invoiceId,
          lineId,
          line.customFields,
        );

        if (line.productId != null) {
          _db.execute(
            'UPDATE products SET '
            'current_stock = current_stock + ?, '
            'purchase_price = ?, updated_at = ? '
            'WHERE id = ?',
            [line.qty, line.price, now, line.productId],
          );
          _db.insert(
            '''
            INSERT INTO stock_movements
              (product_id, quantity, movement_type, reference_id,
               reference_type, to_warehouse_id, movement_date, notes)
            VALUES (?, ?, 'purchase', ?, 'purchase_invoice', ?, ?, ?)
            ''',
            [
              line.productId,
              line.qty,
              invoiceId,
              WarehouseStock.defaultWarehouseId(_db),
              now,
              'شراء - فاتورة $invoiceNumber',
            ],
          );
        }
      }

      if (paid > 0 && accountId != null) {
        _recordPaymentRows(
          invoiceId: invoiceId,
          invoiceNumber: invoiceNumber,
          accountId: accountId,
          amount: paid,
          method: payment?.method ?? paymentMethod,
          description: 'سداد فاتورة شراء رقم $invoiceNumber',
          now: now,
        );
      }

      DocumentCustomFields.saveValues(
        DocumentTypes.purchase,
        invoiceId,
        customFields,
      );

      return PurchaseSaveResult(
        invoiceId: invoiceId,
        invoiceNumber: invoiceNumber,
        total: total,
        paid: paid,
        remaining: remaining,
      );
    });
  }

  /// Update a saved purchase invoice in place, preserving its id and any
  /// payments already recorded against it.
  Future<PurchaseSaveResult> updatePurchase({
    required int invoiceId,
    required int? accountId,
    required String invoiceNumber,
    required List<PurchaseLine> lines,
    required int discount,
    required int addition,
    required String notes,
    required String paymentMethod,
    Map<int, String> customFields = const {},
  }) async {
    final totals = _purchaseTotals(
      lines: lines,
      discount: discount,
      addition: addition,
    );
    return _db.transaction<PurchaseSaveResult>(() async {
      final rows = _db.query(
        'SELECT account_id, paid_amount FROM purchase_invoices '
        'WHERE id = ? AND is_return = 0',
        [invoiceId],
      );
      if (rows.isEmpty) {
        throw PurchaseValidationException('فاتورة الشراء غير موجودة.');
      }
      final oldPaid = (rows.first['paid_amount'] as int?) ?? 0;
      final oldAccount = rows.first['account_id'] as int?;
      if (oldPaid > 0 && accountId != oldAccount) {
        throw PurchaseValidationException(
          'لا يمكن تغيير الحساب بعد تسجيل مدفوعات على الفاتورة.',
        );
      }
      if (totals.total < oldPaid) {
        throw PurchaseValidationException(
          'إجمالي الفاتورة لا يمكن أن يكون أقل من المبلغ المسدد ($oldPaid).',
        );
      }
      final returns = _db.query(
        'SELECT COUNT(*) AS c FROM purchase_return_invoices '
        'WHERE original_invoice_id = ?',
        [invoiceId],
      );
      if (((returns.first['c'] as num?)?.toInt() ?? 0) > 0) {
        throw PurchaseValidationException(
          'لا يمكن تعديل الفاتورة لأن عليها مرتجع شراء مسجل.',
        );
      }
      final oldItems = _db.query(
        'SELECT product_id, quantity FROM purchase_items WHERE invoice_id = ?',
        [invoiceId],
      );
      final now = DateTime.now().toIso8601String();
      for (final item in oldItems) {
        final productId = (item['product_id'] as num?)?.toInt();
        final qty = (item['quantity'] as int?) ?? 0;
        if (productId == null) continue;
        final stockRows = _db.query(
          'SELECT current_stock FROM products WHERE id = ?',
          [productId],
        );
        final stock = stockRows.isEmpty
            ? 0
            : (stockRows.first['current_stock'] as int? ?? 0);
        if (stock < qty) {
          throw PurchaseValidationException(
            'لا يمكن تعديل فاتورة الشراء لأن بعض الكميات تم بيعها. '
            'المخزون الحالي غير كافٍ للتراجع.',
          );
        }
        _db.execute(
          'UPDATE products SET current_stock = current_stock - ?, '
          'updated_at = ? WHERE id = ?',
          [qty, now, productId],
        );
      }
      _db.execute(
        "DELETE FROM stock_movements WHERE reference_type='purchase_invoice' "
        'AND reference_id = ?',
        [invoiceId],
      );
      _db.execute(
        "DELETE FROM document_custom_line_values WHERE document_type='purchase' AND document_id=?",
        [invoiceId],
      );
      _db.execute('DELETE FROM purchase_items WHERE invoice_id = ?', [
        invoiceId,
      ]);
      for (final line in lines) {
        if (line.productId == null) {
          throw PurchaseValidationException(
            'الصنف «${line.name}» غير مرتبط بمنتج مسجل.',
          );
        }
        final lineId = _db.insert(
          '''
          INSERT INTO purchase_items
            (invoice_id, product_id, product_name, product_code, quantity,
             unit_price, discount, total)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            invoiceId,
            line.productId,
            line.name,
            line.code,
            line.qty,
            line.price,
            line.discount,
            line.net,
          ],
        );
        DocumentCustomFields.saveLineValues(
          DocumentTypes.purchase,
          invoiceId,
          lineId,
          line.customFields,
        );
        _db.execute(
          'UPDATE products SET current_stock = current_stock + ?, '
          'purchase_price = ?, updated_at = ? WHERE id = ?',
          [line.qty, line.price, now, line.productId],
        );
        _db.insert(
          '''
          INSERT INTO stock_movements
            (product_id, quantity, movement_type, reference_id,
             reference_type, to_warehouse_id, movement_date, notes)
          VALUES (?, ?, 'purchase', ?, 'purchase_invoice', ?, ?, ?)
          ''',
          [
            line.productId,
            line.qty,
            invoiceId,
            WarehouseStock.defaultWarehouseId(_db),
            now,
            'شراء - فاتورة $invoiceNumber',
          ],
        );
      }
      final remaining = totals.total - oldPaid;
      final status = remaining <= 0
          ? 'paid'
          : (oldPaid > 0 ? 'partial' : 'unpaid');
      _db.execute(
        '''
        UPDATE purchase_invoices
        SET invoice_number = ?, account_id = ?, subtotal = ?, discount = ?,
            tax = ?, total = ?, paid_amount = ?, remaining_amount = ?,
            payment_status = ?, notes = ?, updated_at = ?
        WHERE id = ?
        ''',
        [
          invoiceNumber,
          accountId,
          totals.subtotal,
          totals.discount,
          totals.addition,
          totals.total,
          oldPaid,
          remaining,
          status,
          notes.isEmpty ? null : notes,
          now,
          invoiceId,
        ],
      );
      _db.execute(
        "DELETE FROM document_custom_values WHERE document_type='purchase' "
        'AND document_id = ?',
        [invoiceId],
      );
      DocumentCustomFields.saveValues(
        DocumentTypes.purchase,
        invoiceId,
        customFields,
      );
      return PurchaseSaveResult(
        invoiceId: invoiceId,
        invoiceNumber: invoiceNumber,
        total: totals.total,
        paid: oldPaid,
        remaining: remaining,
      );
    });
  }

  /// Record an extra payment against an already saved invoice.
  Future<({int paid, int remaining})> recordPayment({
    required int invoiceId,
    required int accountId,
    required int amount,
    required String method,
  }) async {
    if (amount <= 0) {
      throw PurchaseValidationException('أدخل مبلغ سداد أكبر من صفر.');
    }
    _requireAccount(accountId);
    final rows = _db.query(
      'SELECT total, paid_amount, invoice_number FROM purchase_invoices '
      'WHERE id = ?',
      [invoiceId],
    );
    if (rows.isEmpty) {
      throw PurchaseValidationException('الفاتورة غير موجودة.');
    }
    final total = (rows.first['total'] as int?) ?? 0;
    final alreadyPaid = (rows.first['paid_amount'] as int?) ?? 0;
    final invoiceNumber = '${rows.first['invoice_number'] ?? ''}';
    final remaining = total - alreadyPaid;
    if (remaining <= 0) {
      throw PurchaseValidationException('الفاتورة مسددة بالكامل.');
    }
    if (amount > remaining) {
      throw PurchaseValidationException(
        'المبلغ أكبر من المتبقي على الفاتورة ($remaining).',
      );
    }

    return _db.transaction(() async {
      final now = DateTime.now().toIso8601String();
      _recordPaymentRows(
        invoiceId: invoiceId,
        invoiceNumber: invoiceNumber,
        accountId: accountId,
        amount: amount,
        method: method,
        description: 'سداد إضافي لفاتورة شراء رقم $invoiceNumber',
        now: now,
      );
      final newPaid = alreadyPaid + amount;
      final newRemaining = total - newPaid;
      final status = newRemaining <= 0
          ? 'paid'
          : (newPaid > 0 ? 'partial' : 'unpaid');
      _db.execute(
        'UPDATE purchase_invoices SET paid_amount = ?, remaining_amount = ?, '
        'payment_status = ?, updated_at = ? WHERE id = ?',
        [newPaid, newRemaining, status, now, invoiceId],
      );
      return (paid: newPaid, remaining: newRemaining);
    });
  }

  // ---------------------------------------------------------------------------
  // Print / export.
  // ---------------------------------------------------------------------------

  Future<Map<String, Object?>?> getInvoice(int invoiceId) async {
    final rows = _db.query(
      '''
      SELECT pi.*, a.name AS account_name
      FROM purchase_invoices pi
      LEFT JOIN accounts a ON a.id = pi.account_id
      WHERE pi.id = ?
      ''',
      [invoiceId],
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, Object?>>> getInvoiceItems(int invoiceId) async {
    return _db.query(
      'SELECT * FROM purchase_items WHERE invoice_id = ? ORDER BY id',
      [invoiceId],
    );
  }

  /// Load a saved purchase invoice for the edit screen. The id is preserved.
  Future<PurchaseEditData?> loadPurchaseForEdit(int invoiceId) async {
    final header = await getInvoice(invoiceId);
    if (header == null) return null;
    final items = await getInvoiceItems(invoiceId);
    final lines = <PurchaseEditLine>[];
    for (final item in items) {
      final productId = (item['product_id'] as num?)?.toInt();
      var available = 0;
      var unit = '';
      if (productId != null) {
        final products = _db.query(
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
        PurchaseEditLine(
          productId: productId,
          name: '${item['product_name'] ?? ''}',
          code: '${item['product_code'] ?? ''}',
          unit: unit.trim().isEmpty ? 'حبة' : unit,
          available: available + qty,
          qty: qty,
          price: (item['unit_price'] as num?)?.toInt() ?? 0,
          discount: (item['discount'] as num?)?.toInt() ?? 0,
          customFields: lineId == null
              ? const {}
              : DocumentCustomFields.lineValues(
                  DocumentTypes.purchase,
                  invoiceId,
                  lineId,
                ),
        ),
      );
    }
    final parsed = DateTime.tryParse('${header['invoice_date'] ?? ''}');
    final hour = parsed == null
        ? ''
        : '${(parsed.hour % 12 == 0 ? 12 : parsed.hour % 12).toString().padLeft(2, '0')}:'
              '${parsed.minute.toString().padLeft(2, '0')} '
              '${parsed.hour < 12 ? 'AM' : 'PM'}';
    return PurchaseEditData(
      id: invoiceId,
      number: '${header['invoice_number'] ?? ''}',
      accountId: (header['account_id'] as num?)?.toInt(),
      accountName: header['account_name'] as String?,
      date: parsed,
      time: hour,
      discount: (header['discount'] as num?)?.toInt() ?? 0,
      tax: (header['tax'] as num?)?.toInt() ?? 0,
      paid: (header['paid_amount'] as num?)?.toInt() ?? 0,
      notes: '${header['notes'] ?? ''}',
      lines: lines,
      customFields: DocumentCustomFields.values(
        DocumentTypes.purchase,
        invoiceId,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Internals.
  // ---------------------------------------------------------------------------

  void _recordPaymentRows({
    required int invoiceId,
    required String invoiceNumber,
    required int accountId,
    required int amount,
    required String method,
    required String description,
    required String now,
  }) {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    _db.insert(
      '''
      INSERT INTO payments
        (payment_number, account_id, payment_date, amount, payment_type,
         payment_method, description, reference_id, reference_type, created_at)
      VALUES (?, ?, ?, ?, 'payment', ?, ?, ?, 'purchase_invoice', ?)
      ''',
      [
        'PAY-$stamp',
        accountId,
        now,
        amount,
        method,
        description,
        invoiceId,
        now,
      ],
    );
    // Same sign convention as the accounts module: paying a supplier adds to
    // the account balance.
    _db.execute(
      'UPDATE accounts SET balance = balance + ?, updated_at = ? WHERE id = ?',
      [amount, now, accountId],
    );

    // Credit purchases move no cash, so they must not touch the treasury.
    if (method != 'credit') {
      final treasuryRows = _db.query(
        'SELECT id FROM treasuries WHERE is_active = 1 ORDER BY id LIMIT 1',
      );
      final treasuryId = treasuryRows.isEmpty
          ? null
          : (treasuryRows.first['id'] as num).toInt();
      int balance;
      if (treasuryId == null) {
        final balanceRows = _db.query(
          'SELECT balance_after FROM treasury_transactions '
          'ORDER BY id DESC LIMIT 1',
        );
        balance = balanceRows.isEmpty
            ? 0
            : (balanceRows.first['balance_after'] as int? ?? 0);
      } else {
        final balanceRows = _db.query(
          'SELECT (SELECT opening_balance FROM treasuries WHERE id = ?) + '
          'COALESCE(SUM(CASE WHEN transaction_type = \'receive\' '
          'THEN amount ELSE -amount END), 0) AS balance '
          'FROM treasury_transactions WHERE treasury_id = ?',
          [treasuryId, treasuryId],
        );
        balance = (balanceRows.first['balance'] as num?)?.toInt() ?? 0;
      }
      final time = now.length >= 16 ? now.substring(11, 16) : '00:00';
      _db.insert(
        '''
        INSERT INTO treasury_transactions
          (transaction_number, transaction_date, transaction_time, amount,
           transaction_type, description, reference_id, reference_type,
           balance_after, created_at, treasury_id)
        VALUES (?, ?, ?, ?, 'expense', ?, ?, 'purchase_invoice', ?, ?, ?)
        ''',
        [
          'TRE-$stamp',
          now,
          time,
          amount,
          'سداد فاتورة شراء رقم $invoiceNumber',
          invoiceId,
          balance - amount,
          now,
          treasuryId,
        ],
      );
    }
  }

  void _requireAccount(int accountId) {
    final rows = _db.query(
      'SELECT id FROM accounts WHERE id = ? AND is_active = 1',
      [accountId],
    );
    if (rows.isEmpty) {
      throw PurchaseValidationException('الحساب المحدد غير موجود أو غير نشط.');
    }
  }

  PurchaseProduct _rowToProduct(Map<String, dynamic> r) {
    return PurchaseProduct(
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

  static String _escapeLike(String value) {
    return value
        .replaceAll('\\', '\\\\')
        .replaceAll('%', '\\%')
        .replaceAll('_', '\\_');
  }
}
